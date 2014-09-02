"=============================================================================
" File: mopbuf.vim
" Author: mopp
" Created: 2014-08-24
"=============================================================================

scriptencoding utf-8

if exists('g:loaded_mopbuf')
    finish
endif
let g:loaded_mopbuf = 1

let s:save_cpo = &cpo
set cpo&vim



command! -nargs=0 MopbufOpen     call mopbuf#open()
command! -nargs=0 MopbufOpenAll  call mopbuf#open_all_tabpage()
command! -nargs=0 MopbufClose    call mopbuf#close()
command! -nargs=0 MopbufCloseAll call mopbuf#close_all_tabpage()



" Auto starting.
let g:mopbuf_enable_startup = get(g:, 'mopbuf_enable_startup', 0)
if g:mopbuf_enable_startup != 0
    call mopbuf#open()
endif



let &cpo = s:save_cpo
unlet s:save_cpo
