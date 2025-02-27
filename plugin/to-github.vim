" The get_browser_command and open_browser functions belong to
" https://github.com/mattn/gist-vim
" Big thank you. Open source ftw
"

function! s:get_browser_command()
  let to_github_browser_command = get(g:, 'to_github_browser_command', '')
  if to_github_browser_command == ''
    if has('win32') || has('win64')
      let to_github_browser_command = '!start rundll32 url.dll,FileProtocolHandler %URL%'
    elseif has('mac') || has('macunix') || has('gui_macvim') || system('uname') =~? '^darwin'
      let to_github_browser_command = 'open %URL%'
    elseif executable('xdg-open')
      let to_github_browser_command = 'xdg-open %URL%'
    elseif executable('firefox')
      let to_github_browser_command = 'firefox %URL% &'
    else
      let to_github_browser_command = ''
    endif
  endif
  return to_github_browser_command
endfunction

function! s:open_browser(url)
  let cmd = s:get_browser_command()
  if len(cmd) == 0
    redraw
    echohl WarningMsg
    echo "It seems that you don't have general web browser. Open URL below."
    echohl None
    echo a:url
    return
  endif
  if cmd =~ '^!'
    let cmd = substitute(cmd, '%URL%', '\=shellescape(a:url)', 'g')
    silent! exec cmd
  elseif cmd =~ '^:[A-Z]'
    let cmd = substitute(cmd, '%URL%', '\=a:url', 'g')
    exec cmd
  else
    let cmd = substitute(cmd, '%URL%', '\=shellescape(a:url)', 'g')
    call system(cmd)
  endif
endfunction

function! s:run(...)
  let command = join(a:000, ' | ')
  return substitute(system(command), "\n", '', '')
endfunction

function! s:copy_to_clipboard(url)
  " if exists('g:to_github_clip_command')
  "   call system(g:to_github_clip_command, a:url)
  " elseif has('unix') && !has('xterm_clipboard')
  "   let @" = a:url
  " else
  echo a:url
  let @+ = a:url
  " endif
endfunction

function! ToGithub(blob_or_blame, develop_or_commithash, count, line1, line2, ...)
  let github_url = 'https://github.com'
  let get_remote = 'git remote -v | grep -E "github\.com.*\(fetch\)" | tail -n 1'
  let get_username = 'sed -E "s/.*com[:\/](.*)\/.*/\\1/"'
  let get_repo = 'sed -E "s/.*com[:\/].*\/(.*).*/\\1/" | cut -d " " -f 1'
  let optional_ext = 'sed -E "s/\.git//"'

  " Get the username and repo.
  if len(a:000) == 0
    let username = s:run(get_remote, get_username)
    let repo = s:run(get_remote, get_repo, optional_ext)
  elseif len(a:000) == 1
    let username = a:000[0]
    let repo = s:run(get_remote, get_repo, optional_ext)
  elseif len(a:000) == 2
    let username = a:000[0]
    let repo = a:000[1]
  else
    return 'Too many arguments'
  endif

  " Get the commit and path, and form the complete url.
  if a:develop_or_commithash == 'develop'
    let l:commit = s:run("git branch -r --points-at refs/remotes/origin/HEAD | grep '\-' | cut -d' ' -f5 | cut -d/ -f2")
  else
    let l:commit = s:run('git rev-parse HEAD')
  endif

  let repo_root = s:run('git rev-parse --show-toplevel')
  let file_path = expand('%:p')
  let file_path = substitute(file_path, repo_root . '/', '', 'e')
  let url = join([github_url, username, repo, a:blob_or_blame, l:commit, file_path], '/')

  " Finally set the line numbers if necessary.
  if a:count == -1
    let line = '#L' . line('.')
  else
    let line = '#L' . a:line1 . '-L' . a:line2
  endif

  if g:to_github_clipboard == 1
    return s:copy_to_clipboard(url . line)
  else
    return s:open_browser(url . line)
  endif
endfunction

function! ToGithubTargetPullRequest()
  let current_path = expand("%")
  let current_line = '-L' . line('.') . ',' . line('.')
  let command = join(['git blame', current_line, current_path], ' ')
  let current_line_blame_info = s:run(command)
  let current_line_commit_hash = split(l:current_line_blame_info, ' ')[0]
  let pr_url = s:run('getpr ' . l:current_line_commit_hash)
  echo l:pr_url
  let @+ = l:pr_url
endfunction

function! ToGithubTargetPullRequestFromCommitHash()
  let github_url = 'https://github.com'
  let get_remote = 'git remote -v | grep -E "github\.com.*\(fetch\)" | tail -n 1'
  let get_username = 'sed -E "s/.*com[:\/](.*)\/.*/\\1/"'
  let get_repo = 'sed -E "s/.*com[:\/].*\/(.*).*/\\1/" | cut -d " " -f 1'
  let optional_ext = 'sed -E "s/\.git//"'
  let username = s:run(get_remote, get_username)
  let repo = s:run(get_remote, get_repo, optional_ext)

  let current_path = expand("%")
  let current_line = '-L' . line('.') . ',' . line('.')
  let command = join(['git blame', current_line, current_path], ' ')
  let current_line_blame_info = s:run(command)
  let current_line_commit_hash = split(l:current_line_blame_info, ' ')[0]
  let command_to_get_pr_number = join(['git log --merges --oneline --reverse --ancestry-path', l:current_line_commit_hash . '...develop'])
  let pr_number = s:run(command_to_get_pr_number, 'grep -o "#[0-9]*" -m 1', 'sed s/#//g')
  let pr_url = join([l:github_url, l:username, l:repo, 'pull', l:pr_number], '/')
  echo l:pr_url
  let @+ = l:pr_url
endfunction

command! -nargs=* -range ToGithubTargetPullRequest :call ToGithubTargetPullRequest()
command! -nargs=* -range ToGithubTargetPullRequestFromCommitHash :call ToGithubTargetPullRequestFromCommitHash()
command! -nargs=* -range ToGithubBlobDevelopBranch :call ToGithub('blob', 'develop', <count>, <line1>, <line2>, <f-args>)
command! -nargs=* -range ToGithubBlameDevelopBranch :call ToGithub('blame', 'develop', <count>, <line1>, <line2>, <f-args>)
command! -nargs=* -range ToGithubBlobCommitHash :call ToGithub('blob', 'commit', <count>, <line1>, <line2>, <f-args>)
command! -nargs=* -range ToGithubBlameCommitHash :call ToGithub('blame', 'commit', <count>, <line1>, <line2>, <f-args>)
