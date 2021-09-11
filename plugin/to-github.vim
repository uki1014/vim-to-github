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
  if exists('g:to_github_clip_command')
    call system(g:to_github_clip_command, a:url)
  elseif has('unix') && !has('xterm_clipboard')
    let @" = a:url
  else
    let @+ = a:url
  endif
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
  if develop_or_commithash == 'develop'
    let s:commit = 'develop'
  else
    let s:commit = s:run('git rev-parse HEAD')
  endif

  let repo_root = s:run('git rev-parse --show-toplevel')
  let file_path = expand('%:p')
  let file_path = substitute(file_path, repo_root . '/', '', 'e')
  let url = join([github_url, username, repo, a:blob_or_blame, commit, file_path], '/')

  " Finally set the line numbers if necessary.
  if a:count == -1
    let line = '#L' . line('.')
  else
    let line = '#L' . a:line1 . '-L' . a:line2
  endif

  if get(g:, 'to_github_clipboard', 0)
    return s:copy_to_clipboard(url . line)
  else
    return s:open_browser(url . line)
  endif
endfunction

command! -nargs=* -range ToGithubBlobDevelopBranch :call ToGithub('blob', 'develop', <count>, <line1>, <line2>, <f-args>)
command! -nargs=* -range ToGithubBlameDevelopBranch :call ToGithub('blame', 'develop', <count>, <line1>, <line2>, <f-args>)
command! -nargs=* -range ToGithubBlobCommitHash :call ToGithub('blob', 'commit', <count>, <line1>, <line2>, <f-args>)
command! -nargs=* -range ToGithubBlameCommitHash :call ToGithub('blame', 'commit', <count>, <line1>, <line2>, <f-args>)
