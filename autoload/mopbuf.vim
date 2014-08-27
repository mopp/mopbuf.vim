"=============================================================================
" File: mopbuf.vim
" Author: mopp
" Created: 2014-08-24
"=============================================================================

scriptencoding utf-8

if !exists('g:loaded_mopbuf')
    finish
endif

let s:save_cpo = &cpo
set cpo&vim


" Global variables.
let g:mopbuf_is_tabpage_mode = get(g:, 'mopbuf_is_tabpage_mode', 0)
let g:mopbuf_is_vsplit = get(g:, 'mopbuf_is_vsplit', 0)


" Script local variables.
let s:DISPLAY_BUFFER_NAME = '==MopBuf=='
lockvar s:DISPLAY_BUFFER_NAME
let s:V             = vital#of('mopbuf')
let s:B             = s:V.import('Vim.Buffer')
let s:BM            = s:V.import('Vim.BufferManager')
let s:P             = s:V.import('Prelude')
let s:S             = s:V.import("Data.String")
let s:buf_manager   = s:BM.new()
let s:is_initialize = 0


function! s:DEBUG_ECHO(...)
    if a:0 == 0
        return
    endif

    let str = s:P.is_string(a:000[0]) ? (a:000[0]) : (string(a:000[0]))

    if 1 < a:0
        for i in range(1, a:0 - 1)
            let t = a:000[i]
            let str = str . ' ' . (s:P.is_string(t) ? (t) : (string(t)))
        endfor
    endif

    echomsg str
endfunction


" Check buffer is managed buffer.
function! s:is_managed_buffer(bufnr)
    return (buflisted(a:bufnr) != 0) && (s:is_normel_buffer(a:bufnr) == 1)
endfunction


" Check buffer is normal type.
function! s:is_normel_buffer(bufnr)
    return getbufvar(a:bufnr, "&buftype") == ''
endfunction


" Return NOT ignored buffer number list.
function! s:get_bufnr_list()
    let bufnrs = []
    for i in range(1, bufnr('$'))
        if s:is_managed_buffer(i) == 1
            call add(bufnrs, i)
        endif
    endfor

    return bufnrs
endfunction


function! s:initialize()
    if s:is_initialize == 1
        return
    endif

    " set auto commands
    augroup mopbuf
        autocmd!
    "     autocmd VimEnter                            * nested call <SID>VimEnterHandler()
    "     autocmd TabEnter                            * nested call <SID>TabEnterHandler()
    autocmd BufAdd * call s:buf_manager.add(expand('<abuf>'))
    autocmd BufEnter * call s:confirm_buffers_validate()
    "     autocmd BufEnter                            * nested call <SID>BufEnterHandler()
    "     autocmd BufDelete                           *        call <SID>BufDeleteHandler()
    "     autocmd CursorHold,CursorHoldI,BufWritePost * call <SID>UpdateBufferStateDict(bufnr("%"),0)
    "     autocmd QuitPre                             * if <SID>NextNormalWindow() == -1 | call <SID>StopExplorer(0) | endif
    "     autocmd FileType                            minibufexpl call <SID>RenderSyntax()
    augroup END

    " Add already existing buffer to manager.
    for i in s:get_bufnr_list()
        call s:buf_manager.add(i)
    endfor

    let s:is_initialize = 1
endfunction


" Remove buffer in buffer manager
function! s:buffer_manager_remove_buffer(bufman, bufnr)
    if a:bufman.is_managed(a:bufnr) == 1
        call remove(a:bufman._bufnrs, a:bufnr)
    endif
endfunction


" Confirm buffer in manager is listed.
" buflisted() returns 0 on BufAdd and BufEnter when buffer is firstly opened.
function! s:confirm_buffers_validate()
    for i in s:buf_manager.list()
        if s:is_managed_buffer(i) == 0
            call s:buffer_manager_remove_buffer(s:buf_manager, i)
        endif
    endfor
endfunction


" Open mopbuf window
function! mopbuf#open()
    call s:initialize()
    call s:DEBUG_ECHO("managerd buffer", s:buf_manager.list())

    " store
    let stored_splitbelow = &splitbelow
    let stored_splitright = &splitright

    if bufnr(s:DISPLAY_BUFFER_NAME) == -1
        silent exec 'noautocmd' (g:mopbuf_is_vsplit != 0 ? 'vertical topleft' : 'botright') ' split' s:DISPLAY_BUFFER_NAME
        setlocal noswapfile
        setlocal nobuflisted
        setlocal buftype=nofile
        setlocal bufhidden=delete
        setlocal nonumber
        setlocal norelativenumber
        resize 1
    else
        silent exec 'noautocmd sbuffer' s:DISPLAY_BUFFER_NAME
    endif

    " restore
    let &splitbelow = stored_splitbelow
    let &splitright = stored_splitright
endfunction



let &cpo = s:save_cpo
unlet s:save_cpo
