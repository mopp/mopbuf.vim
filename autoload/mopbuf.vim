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
let g:mopbuf_tabpage_mode      = get(g:, 'mopbuf_tabpage_mode', 0)
let g:mopbuf_vsplit_mode       = get(g:, 'mopbuf_vsplit_mode', 0)
let g:mopbuf_display_buf_width = get(g:, 'mopbuf_display_buf_width', 35)
let g:mopbuf_sort_order        = get(g:, 'mopbuf_sort_order', 'bufnr')


" Script local variables.
let s:DISPLAY_BUFFER_NAME = '--MopBuf--'
let s:V                   = vital#of('mopbuf')
let s:B                   = s:V.import('Vim.Buffer')
let s:BM                  = s:V.import('Vim.BufferManager')
let s:P                   = s:V.import('Prelude')
let s:S                   = s:V.import("Data.String")
let s:L                   = s:V.import('Data.List')
let s:is_initialize       = 0
let s:buf_manager         = s:BM.new()
let s:buf_info = {
            \   'uniq_names': {},
            \   'names': {},
            \   'paths': {},
            \   }

" all design setting in display buffer.
"   [1]:mopbuf.vim+ | [2]:hoge- |
let g:mopbuf_display_design_funcs = get(g:, 'mopbuf_display_design_funcs',
            \   {
            \       'buffer_str'    : 's:default_buffer_str',
            \       'set_syntax'    : 's:defallt_set_syntax',
            \       'set_highlight' : 's:defallt_set_highlight',
            \   })

lockvar s:DISPLAY_BUFFER_NAME



" It is used for debug.
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


" Return list of sorted managed buffer numbers
function! s:get_sorted_bufnr_list()
    " TODO:
    return sort(copy(s:buf_manager.list()), 'n')
endfunction


" Initialize
function! s:initialize()
    if s:is_initialize == 1
        return
    endif

    " set auto commands
    augroup mopbuf
        autocmd!
        "     autocmd VimEnter                            * nested call <SID>VimEnterHandler()
        "     autocmd TabEnter                            * nested call <SID>TabEnterHandler()
        autocmd BufAdd * call s:add_buffer(expand('<abuf>'))
        autocmd BufEnter * call s:confirm_buffers_validate()
        "     autocmd BufDelete                           *        call <SID>BufDeleteHandler()
        "     autocmd CursorHold,CursorHoldI,BufWritePost * call <SID>UpdateBufferStateDict(bufnr("%"),0)
        "     autocmd QuitPre                             * if <SID>NextNormalWindow() == -1 | call <SID>StopExplorer(0) | endif
        "     autocmd FileType                            minibufexpl call <SID>RenderSyntax()
    augroup END

    " Add already existing buffer to manager.
    for i in s:get_bufnr_list()
        call s:add_buffer(i)
    endfor

    let s:is_initialize = 1
endfunction


" Remove buffer in buffer manager and buffer info
function! s:buffer_manager_remove_buffer(bufman, bufnr)
    if a:bufman.is_managed(a:bufnr)
        call remove(a:bufman._bufnrs, a:bufnr)
        if has_key(s:buf_info.names, a:bufnr)
            call remove(s:buf_info.names, a:bufnr)
            call remove(s:buf_info.uniq_names, a:bufnr)
            call remove(s:buf_info.paths, a:bufnr)
        endif
    endif
endfunction


" Add buffer to buffer manager and set it info.
function! s:add_buffer(bufnr)
    call s:buf_manager.add(a:bufnr)

    let bufname = expand('#' . a:bufnr . ':t')
    let s:buf_info.paths[a:bufnr] = expand('#' . a:bufnr . ':p:h')
    for [k, v] in items(s:buf_info.names)
        if bufname == v
            let s:buf_info.uniq_names[a:bufnr] = fnamemodify(s:buf_info.paths[a:bufnr], ':t') . '/' . bufname
            let s:buf_info.uniq_names[k]       = fnamemodify(s:buf_info.paths[k], ':t') . '/' . bufname
            break
        endif
    endfor

    if !has_key(s:buf_info.uniq_names, a:bufnr)
        " buffer name is already unique.
        let s:buf_info.uniq_names[a:bufnr] = bufname
    endif

    let s:buf_info.names[a:bufnr] = bufname
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


" Return 1 if display buffer exists, otherwise 0.
function! s:is_exist_display_budder()
    return bufwinnr(s:DISPLAY_BUFFER_NAME) != -1
endfunction


" Return display buffer number
function! s:get_display_bufnr()
    return bufnr(s:DISPLAY_BUFFER_NAME)
endfunction


" Setting local mapping in display buffer
function! s:set_local_mapping()
endfunction


" Wrapper silent execute noautocmd hogehoge
" First argument is cmd
" Second argument is noautocmd flag
function! s:exec_quietly(cmd, ...)
    if (a:0 == 1) && (a:000[0] != 0)
        silent execute a:cmd
    else
        silent execute 'noautocmd' a:cmd
    endif
endfunction


" Resize window of display buffer
function s:display_buffer_resize(win_size)
    call s:exec_quietly((g:mopbuf_vsplit_mode != 0 ? 'vertical' : '' ) . 'resize ' . a:win_size)
endfunction


" default function for s:mopbuf_display_design_funcs
function! s:default_buffer_str(buf_info)
    let str = ''

    let win_width = winwidth(winnr())

    let last = a:buf_info.numbers[a:buf_info.size - 1]
    let len = 0
    for i in a:buf_info.numbers
        let mod = (getbufvar(i, '&modified') == 1) ? '+' : '-'
        let sep = (i != last) ? ' | ' : ''
        let t = printf('[%d]:%s%s%s', i, a:buf_info.uniq_names[i], mod, sep)

        let len = len + len(t)
        if win_width < len
            " delete sep and add newline
            let str = substitute(str, '\s|\s$', '', '') . "\n"
            let len = 0
        endif

        let str = str . t
    endfor

    return str
endfunction


" default function for s:mopbuf_display_design_funcs
function! s:default_set_syntax()
endfunction


" default function for s:mopbuf_display_design_funcs
function! s:default_set_highlight()
endfunction


" This works display buffer open and close
" Argument is funcref only
function! s:display_buffer_worker(...)
    " Store
    let stored_splitbelow = &splitbelow
    let stored_splitright = &splitright

    " Save window moving history
    let stored_current_winnr = winnr()
    call s:exec_quietly('wincmd p')
    let stored_prev_winnr = winnr()

    if s:is_exist_display_budder() == 0
        " Open new buffer
        call s:exec_quietly((g:mopbuf_vsplit_mode != 0 ? 'vertical topleft' : 'botright') . ' split ' . s:DISPLAY_BUFFER_NAME)
        setlocal noswapfile
        setlocal nobuflisted
        setlocal buftype=nofile
        setlocal bufhidden=delete
        setlocal undolevels=-1
        call s:display_buffer_resize((g:mopbuf_vsplit_mode != 0) ? g:mopbuf_display_buf_width : 1)
    else
        " Move already exists buffer
        let stored_switchbuf = &switchbuf
        setlocal switchbuf=useopen
        call s:exec_quietly('sbuffer ' . s:DISPLAY_BUFFER_NAME)
        let &switchbuf = stored_switchbuf
    endif

    " Window local option.
    setlocal nonumber
    setlocal norelativenumber
    setlocal foldcolumn=0
    setlocal nomodifiable
    setlocal nocursorline

    " Cursor focus is display buffer in this.
    if a:0 == 1
        if s:P.is_funcref(a:1) == 1
            call a:1()
        elseif s:P.is_string(a:1) == 1
            let F = function(a:1)
            call F()
        else
            echoerr 'ERROR: Argument is invalidate in s:display_buffer_worker()'
        endif
    endif

    " Restore window moving history
    if g:mopbuf_vsplit_mode == 0
        call s:exec_quietly(stored_prev_winnr    . ' wincmd w', 1)
        call s:exec_quietly(stored_current_winnr . ' wincmd w', 1)
    else
        call s:exec_quietly(1 + stored_prev_winnr    . ' wincmd w', 1)
        call s:exec_quietly(1 + stored_current_winnr . ' wincmd w', 1)
    endif

    " Restore
    let &splitbelow = stored_splitbelow
    let &splitright = stored_splitright
endfunction


" This update display buffer.
function! s:updator()
    " Set argument variable for handler function.
    let arg_buf_info               = {}
    let arg_buf_info['numbers']    = s:get_sorted_bufnr_list()
    let arg_buf_info['size']       = len(arg_buf_info.numbers)
    let arg_buf_info['paths']      = deepcopy(s:buf_info.paths)
    let arg_buf_info['names']      = deepcopy(s:buf_info.names)
    let arg_buf_info['uniq_names'] = deepcopy(s:buf_info.uniq_names)

    let Buffer_str_func = function(g:mopbuf_display_design_funcs.buffer_str)
    let bstr = Buffer_str_func(arg_buf_info)

    " Count newline num
    let next_win_height = len(bstr) - len(substitute(bstr, "\n", '', 'g')) + 1

    " Only resize display buffer at bottom
    if g:mopbuf_vsplit_mode == 0
        call s:display_buffer_resize(next_win_height)
    endif

    " Write into display buffer
    setlocal modifiable
    call s:exec_quietly('normal "_1,$dd')
    put! =bstr
    call s:exec_quietly('normal G"_ddgg')
    setlocal nomodifiable
endfunction


" Wrapper of update display buffer.
function! s:display_buffer_update()
    call s:display_buffer_worker('s:updator')
endfunction


" Open display window
function! mopbuf#open()
    call s:initialize()

    call s:display_buffer_update()
endfunction


" Close display window
function! mopbuf#close()
    if s:is_exist_display_budder() == 1
        silent execute 'noautocmd bdelete' s:get_display_bufnr()
    endif
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo
