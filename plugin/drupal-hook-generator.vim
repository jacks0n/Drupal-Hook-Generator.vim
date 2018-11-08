" drupal-hook-generator.vim - A Drupal hook generator.
" Maintainer: Jackson Cooper <jackson@jacksonc.com>
" Version:    1.0.0

if exists('g:loaded_drupal_hook_generator') || &compatible
  finish
endif
if !has('python')
  echoerr 'Error: Drupal Hook Generator requires Python support.'
  finish
endif
let g:loaded_drupal_hook_generator = 1
let s:plugin_path = expand('<sfile>:p:h:h')


function! s:SelectDrupalHook_FZF_Callback(hook)
  let l:hook_name = substitute(a:hook, '(.*)', '', '')
  let l:hook_tag = get(taglist('^' . l:hook_name . '$'), 0, {})
  if !empty(l:hook_tag)
    call s:GenerateDrupalHook(l:hook_tag)
  else
    echoerr 'Error: Cannot find tag for hook `' . l:hook_name . '()`'
  endif
endfunction


function! s:SelectDrupalHook()
  " Use FZF, if available.
  if exists('*fzf#run')
    let l:hooks_tags = sort(map(taglist('^hook_'),
          \ "substitute(v:val['name'], 'HOOK', 'hook', 'g') . substitute(v:val['signature'], '&\\s', '\\&', 'g')"))
    let l:hooks_tags_unique = filter(copy(l:hooks_tags), 'index(l:hooks_tags, v:val, v:key+1) == -1')
    call fzf#run({
      \ 'source': l:hooks_tags_unique,
      \ 'down':   '40%',
      \ 'sink':   function('s:SelectDrupalHook_FZF_Callback')
      \ })
  else
    let l:hook_name = input('Drupal Hook Name: ', 'hook_')
    redraw!
    let l:hook_tag = get(taglist('^' . l:hook_name . '$'), 0, {})
    if !empty(l:hook_tag)
      call s:GenerateDrupalHook(l:hook_tag)
    else
      echoerr 'Error: Cannot find tag for hook `' . l:hook_name . '()`'
    endif
  endif
endfunction


function! s:GenerateDrupalHook(hook_tag)
  " Fetch the current file's template name.
  let l:template_name = s:GetDrupalTemplate(expand('%:p:h'))

  " Render the hook.
  let l:hook_signature = substitute(a:hook_tag['signature'], '&\s', '\&', 'g')
  let l:hook_signature = substitute(l:hook_signature, '&', '\\&', 'g')
  let l:hook_base_name = substitute(a:hook_tag['name'], '^hook_', '', '')
  let l:hook_str = join(readfile(fnameescape(s:plugin_path . '/templates/hook')), "\n")
  let l:hook_str = substitute(l:hook_str, '<hook_name>', l:hook_base_name, 'g')
  let l:hook_str = substitute(l:hook_str, '<hook_signature>', l:hook_signature, 'g')
  let l:hook_str = substitute(l:hook_str, '<hook_template>', l:template_name, 'g')

  " Append the hook into the current buffer.
  let l:current_line_num = line('.')
  for l:hook_str_line in split(l:hook_str, "\n")
    call append(l:current_line_num, l:hook_str_line)
    let l:current_line_num += 1
  endfor

  " Move the cursor inside the function, add an indent and enter insert mode.
  call append(l:current_line_num - 1, repeat(' ', &tabstop))
  call cursor(l:current_line_num, 2)
  startinsert!
endfunction


function! s:GetDrupalTemplate(dirpath)
  let l:dirpath = a:dirpath
  while 1
    " Search (and return the basename if found) for an info file.
    let l:info_file = globpath(l:dirpath, '*.info.yml')
    if l:info_file == ''
      let l:info_file = globpath(l:dirpath, '*.info')
    endif
    if l:info_file != ''
      return fnamemodify(l:dirpath, ':t:r')
    endif

    " Move a directory upward.
    let l:dirpath = fnamemodify(l:dirpath, ':h')

    " Reached the Drupal or file-system root directory.
    if filereadable(l:dirpath . '/index.php') || l:dirpath == '/'
      return ''
    endif
  endwhile
endfunction


command! GenerateDrupalHook call s:SelectDrupalHook()
