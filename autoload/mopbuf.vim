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
" FIXME: check each key has value.
let g:mopbuf_settings = get(g:, 'mopbuf_settings', {
            \       'tabpage_mode' : 0,
            \       'vsplit_mode' : 0,
            \       'vsplit_width' : 35,
            \       'sort_order' : 'bufnr',
            \       'separator' : ' | ',
            \       'auto_open_each_tab' : 0,
            \       'functions' : {
            \           'buffer_str' : 's:default_buffer_str',
            \           'set_syntax' : 's:default_set_syntax',
            \           'set_highlight' : 's:default_set_highlight',
            \       },
            \   })


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
            \       'uniq_names': {},
            \       'names': {},
            \       'paths': {},
            \       'strs': {},
            \       'user_bufnr': -1,
            \   }
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


" Remove n character from tail of str.
function! s:string_remove_tail(str, n)
    return strpart(a:str, 0, len(a:str) - a:n)
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
function! s:get_all_bufnr_list()
    let bufnrs = []

    for i in range(1, bufnr('$'))
        if s:is_managed_buffer(i) == 1
            call add(bufnrs, i)
        endif
    endfor

    return bufnrs
endfunction


" Return NOT ignored buffer
" This return value depends g:mopbuf_settings.tabpage_mode
function! s:get_bufnr_list()
    if g:mopbuf_settings.tabpage_mode == 0
        return s:get_all_bufnr_list()
    endif

    let bufnrs = []
    for i in range(1, tabpagebuflist(tabpagenr()))
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


" Remove buffer in buffer manager and buffer info
function! s:remove_buffer(bufman, bufnr)
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
    if !empty(bufname)
        let s:buf_info.paths[a:bufnr] = expand('#' . a:bufnr . ':p:h')
        for [k, v] in items(s:buf_info.names)
            if bufname == v
                let s:buf_info.uniq_names[a:bufnr] = fnamemodify(s:buf_info.paths[a:bufnr], ':t') . '/' . bufname
                let s:buf_info.uniq_names[k]       = fnamemodify(s:buf_info.paths[k], ':t') . '/' . bufname
                break
            endif
        endfor
    else
        " No name buffer
        let bufname = '--NO NAME--'
        let s:buf_info.paths[a:bufnr] = ''
        " FIXME: Make No name buffer unique.
    endif

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
            call s:remove_buffer(s:buf_manager, i)
        endif
    endfor
endfunction


" Return 1 if display buffer exists, otherwise 0.
function! s:is_exist_display_buffer()
    return bufwinnr(s:DISPLAY_BUFFER_NAME) != -1
endfunction


" Return display buffer number
function! s:get_display_bufnr()
    return bufnr(s:DISPLAY_BUFFER_NAME)
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
    call s:exec_quietly((g:mopbuf_settings.vsplit_mode != 0 ? 'vertical ' : '' ) . 'resize ' . a:win_size)
endfunction


" Default function
" [1:hoge.txt] | *[2:huga.txt+]* |
function! s:default_buffer_str(buf_info)
    let mod = (getbufvar(a:buf_info.number, '&modified') == 1) ? '+' : '-'
    let cur = (a:buf_info.number == a:buf_info.user_bufnr) ? '*' : ''
    return printf('%s[%d:%s%s]%s', cur, a:buf_info.number, a:buf_info.uniq_name, mod, cur)
endfunction


" Default function
function! s:default_set_syntax()
    syntax clear
    syntax match MopbufActiveNormal    /\*\[.*-\]\*/
    syntax match MopbufActiveChanged   /\*\[.*+\]\*/
    syntax match MopbufInactiveNormal  /\%(^\|\s\)\[[^\]]*-\]/
    syntax match MopbufInactiveChanged /\%(^\|\s\)\[[^\]]*+\]/
    syntax match MopbufSeparator       /\s|/
endfunction


" Default function
function! s:default_set_highlight()
    hi MopbufActiveNormal    term=none ctermfg=81  gui=none guifg=#5f00ff
    hi MopbufActiveChanged   term=bold ctermfg=69  gui=bold guifg=#5f87ff
    hi MopbufInactiveNormal  term=none ctermfg=146 gui=none guifg=#afafd7
    hi MopbufInactiveChanged term=bold ctermfg=147 gui=bold guifg=#afafff
    hi MopbufSeparator       term=bold ctermfg=241 gui=bold guifg=#606060
endfunction


" Setting buffer local mapping in display buffer
function! s:set_buffer_mapping()
endfunction


" Initialize tab local variables.
function! s:init_tab_variable()
    " If "is_open" is 1, display buffer shown in tabpage.
    " If "is_user_closed" is 1, User did close display buffer using command.
    " Tab local variable
    let t:tab_info = get(t:, 'tab_info', {
                \   'is_open' : 0,
                \   'is_user_closed' : 0,
                \ })
endfunction


" Close display buffer
function! s:display_buffer_close()
    if s:is_exist_display_buffer() == 1
        call s:display_buffer_focus()
        close
    endif
endfunction


" Focus display buffer
function! s:display_buffer_focus()
    " Move already exists buffer
    let stored_switchbuf = &switchbuf
    setlocal switchbuf=useopen
    call s:exec_quietly('sbuffer ' . s:DISPLAY_BUFFER_NAME)
    let &switchbuf = stored_switchbuf
endfunction


" This works in display buffer
" And opens display buffer automatically.
" Argument is reference to function or string of function name.
function! s:display_buffer_worker(...)
    " Store
    let stored_splitbelow = &splitbelow
    let stored_splitright = &splitright

    " Save window moving history
    let stored_current_winnr = winnr()
    call s:exec_quietly('wincmd p')
    let stored_prev_winnr = winnr()

    if t:tab_info.is_open == 1 || (g:mopbuf_settings.auto_open_each_tab != 0 && t:tab_info.is_user_closed == 0)
        if s:is_exist_display_buffer() == 0
            " Open new buffer
            call s:exec_quietly((g:mopbuf_settings.vsplit_mode != 0 ? 'vertical topleft' : 'botright') . ' split ' . s:DISPLAY_BUFFER_NAME)
            setlocal noswapfile
            setlocal nobuflisted
            setlocal buftype=nofile
            setlocal bufhidden=delete
            setlocal undolevels=-1
            call s:display_buffer_resize((g:mopbuf_settings.vsplit_mode != 0) ? g:mopbuf_settings.vsplit_width : 1)

            let Set_syntax_func    = function(g:mopbuf_settings.functions.set_syntax)
            call Set_syntax_func()
            call s:set_buffer_mapping()
        else
            call s:display_buffer_focus()
        endif

        let t:tab_info.is_open = 1
    else
        call s:display_buffer_close()
        return
    endif

    " Window local option.
    setlocal nonumber
    setlocal norelativenumber
    setlocal foldcolumn=0
    setlocal nomodifiable
    setlocal nocursorline

    " Cursor focus is display buffer in this.
    if a:0 == 1
        " Set user buffer number.
        let usr_bufnr = winbufnr(stored_current_winnr)
        if !s:buf_manager.is_managed(usr_bufnr)
            let usr_bufnr = -1
        endif
        let s:buf_info.user_bufnr = usr_bufnr

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
    if g:mopbuf_settings.vsplit_mode == 0
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
    let str = mopbuf#get_buffers_str()

    " Only resize display buffer at bottom
    if g:mopbuf_settings.vsplit_mode == 0
        call s:display_buffer_resize(len(str) - len(substitute(str, "\n", '', 'g')) + 1)
    endif

    " Write into display buffer
    setlocal modifiable
    call s:exec_quietly('normal! ggVG"_dd')
    put! =str
    call s:exec_quietly('normal! G"_ddgg')
    setlocal nomodifiable
endfunction


" Wrapper of update display buffer.
function! s:display_buffer_update()
    call s:display_buffer_worker('s:updator')
endfunction


" Initialize
function! mopbuf#initialize()
    if s:is_initialize == 1
        return
    endif

    call s:init_tab_variable()

    " set auto commands
    augroup mopbuf
        autocmd!
        autocmd TabEnter    * call s:init_tab_variable() | call s:display_buffer_update()
        autocmd BufAdd      * call s:add_buffer(expand('<abuf>'))
        autocmd BufEnter    * call s:confirm_buffers_validate() | call s:display_buffer_update()
        autocmd BufDelete   * call s:remove_buffer(s:buf_manager, expand('<abuf>'))
        autocmd QuitPre     * call s:display_buffer_close()
        autocmd BufWritePost,TextChanged * call s:display_buffer_update()
    augroup END

    " Add already existing buffer to manager.
    for i in s:get_all_bufnr_list()
        call s:add_buffer(i)
    endfor

    " Set highlight
    let Set_highlight_func = function(g:mopbuf_settings.functions.set_highlight)
    call Set_highlight_func()

    let s:is_initialize = 1
endfunction


" Return string that will be show in display buffer.
function! mopbuf#get_buffers_str()
    let Buffer_str_func = function(g:mopbuf_settings.functions.buffer_str)
    let str             = ''
    let win_width       = winwidth(winnr())
    let len_str         = 0
    let sep             = g:mopbuf_settings.separator
    let len_sep         = len(sep)
    let lst             = s:get_bufnr_list()
    let last            = lst[len(lst) - 1]
    for i in lst
        " Set argument variable for handler function.
        let arg_buf_info               = {}
        let arg_buf_info['number']     = i
        let arg_buf_info['path']       = s:buf_info.paths[i]
        let arg_buf_info['name']       = s:buf_info.names[i]
        let arg_buf_info['uniq_name']  = s:buf_info.uniq_names[i]
        let arg_buf_info['user_bufnr'] = s:buf_info.user_bufnr
        let t                          = Buffer_str_func(arg_buf_info)
        let s:buf_info.strs[i]         = t

        let len_t = len(t)
        if win_width < (len_str + len_t + len_sep)
            " Delete previous separator and add newline
            let str     = s:string_remove_tail(str, len_sep) . "\n"
            let len_str = len_t
        else
            let len_str = len_str + len_t + len_sep
        endif

        let str = str . t . sep
    endfor
    return s:string_remove_tail(str, len_sep)
endfunction


" Return the number of managed buffer.
function! mopbuf#managed_buffer_num()
    return len(s:buf_manager.list())
endfunction


" Open display window
function! mopbuf#open()
    call mopbuf#initialize()

    let t:tab_info.is_open = 1
    call s:display_buffer_update()
endfunction


" Open display window in all tabpage.
function! mopbuf#open_all_tabpage()
    call mopbuf#initialize()

    for i in range(1, tabpagenr('$'))
        call settabvar(i, 'tab_info', {'is_open' : 1, 'is_user_closed' : 0})
    endfor
    call s:display_buffer_update()
endfunction


" Close display window
function! mopbuf#close()
    if s:is_initialize == 0
        return
    endif

    if s:is_exist_display_buffer() == 1
        let t:tab_info.is_open = 0
        let t:tab_info.is_user_closed = 1
        call s:display_buffer_close()
    endif
endfunction


" Close display window in all tabpage.
function! mopbuf#close_all_tabpage()
    if s:is_initialize == 0
        return
    endif

    for i in range(1, tabpagenr('$'))
        call settabvar(i, 'tab_info', {'is_open' : 0, 'is_user_closed' : 1})
    endfor
    call s:display_buffer_close()
endfunction



let &cpo = s:save_cpo
unlet s:save_cpo
