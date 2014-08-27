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



command! MopbufOpen call mopbuf#open()


let g:mopbuf_enable_startup = get(g:, 'mopbuf_enable_startup', 0)
if g:mopbuf_enable_startup != 0
endif



let &cpo = s:save_cpo
unlet s:save_cpo
