if exists('g:loaded_clighter8')
    finish
endif

let s:script_folder_path = escape( expand( '<sfile>:p:h' ), '\'   )
execute('source '. s:script_folder_path . '/../syntax/clighter8.vim')

fun! s:engine_init(channel, libclang_path, compile_args, hlt_whitelist, hlt_blacklist)
    let l:expr = {'cmd' : 'init', 'params' : {'libclang' : a:libclang_path, 'cwd' : getcwd(), 'global_compile_args' : a:compile_args, 'whitelist' : a:hlt_whitelist, 'blacklist' : a:hlt_blacklist}}
    return ch_evalexpr(a:channel, l:expr)
endf

fun! s:engine_get_hlt_async(channel, bufname, callback)
    if index(['c', 'cpp', 'objc', 'objcpp'], &filetype) == -1
        return
    endif

    let l:pos = getpos('.')
    let l:expr = {'cmd' : 'get_hlt', 'params' : {'bufname' : a:bufname, 'begin_line' : line('w0'), 'end_line' : line('w$'), 'row' : l:pos[1], 'col': l:pos[2]}}
    call ch_sendexpr(a:channel, l:expr, {'callback': a:callback})
endf

func s:engine_cursor_info(channel, bufname, row, col)
    if index(['c', 'cpp', 'objc', 'objcpp'], &filetype) == -1
        return
    endif

    let l:expr = {'cmd' : 'cursor_info', 'params' : {'bufname' : a:bufname, 'row' : a:row, 'col': a:col}}
    let l:result = ch_evalexpr(a:channel, l:expr)
    echo l:result
endf

func s:engine_compile_info(channel, bufname)
    if index(['c', 'cpp', 'objc', 'objcpp'], &filetype) == -1
        return
    endif

    let l:expr = {'cmd' : 'compile_info', 'params' : {'bufname' : a:bufname}}
    let l:result = ch_evalexpr(a:channel, l:expr)
    echo l:result
endf


func s:engine_req_parse_async(channel, bufname, callback)
    if index(['c', 'cpp', 'objc', 'objcpp'], &filetype) == -1
        return
    endif

    let l:expr = {'cmd' : 'req_parse', 'params' : {'bufname' : a:bufname}}
    call ch_sendexpr(a:channel, l:expr, {'callback': a:callback})
endf

func s:engine_req_get_hlt_async(channel, bufname, callback)
    call s:clear_match_by_priorities([g:clighter8_usage_priority])

    if index(['c', 'cpp', 'objc', 'objcpp'], &filetype) == -1
        return
    endif

    let l:expr = {'cmd' : 'req_get_hlt', 'params' : {'bufname' : a:bufname}}
    call ch_sendexpr(a:channel, l:expr, {'callback': a:callback})
endf


func s:engine_parse_async(channel, bufname, callback)
    if index(['c', 'cpp', 'objc', 'objcpp'], &filetype) == -1
        return
    endif

    let l:expr = {'cmd' : 'parse', 'params' : {'bufname' : a:bufname, 'content' : join(getline(1,'$'), "\n")}}
    call ch_sendexpr(a:channel, l:expr, {'callback': a:callback})
endf

func s:engine_parse(channel, bufname)
    if index(['c', 'cpp', 'objc', 'objcpp'], &filetype) == -1
        return
    endif

    let l:expr = {'cmd' : 'parse', 'params' : {'bufname' : a:bufname, 'content' : join(getline(1,'$'), "\n")}}
    return ch_evalexpr(a:channel, l:expr)
endf

fun! s:engine_delete_buffer_async(channel, bufname, callback)
    let l:expr = {'cmd' : 'delete_buffer', 'params' : {'bufname' : a:bufname}}
    call ch_sendexpr(a:channel, l:expr, {'callback': a:callback})
endf

fun! s:engine_enable_log(channel, en)
    let l:expr = {'cmd' : 'enable_log', 'params' : {'enable' : a:en}}
    call ch_sendexpr(a:channel, l:expr)
endf

fun! s:engine_get_usr_info(channel, bufname, pos)
    let l:expr = {'cmd' : 'get_usr_info', 'params' : {'bufname' : a:bufname, 'row' : a:pos[1], 'col': a:pos[2]}}
    let l:result = ch_evalexpr(a:channel, l:expr)
    return l:result
endf

fun! s:engine_rename(channel, bufname, usr)
    let l:expr = {'cmd' : 'rename', 'params' : {'bufname' : a:bufname, 'usr' : a:usr}}
    return ch_evalexpr(a:channel, l:expr, {'timeout' : 10000})
endf

func HandleParse(channel, msg)
    let b:last_changedtick = b:changedtick

    if !empty(a:msg)
        call s:engine_req_get_hlt_async(a:channel, a:msg, 'HandleReqGetHlt')
    endif
endfunc

func HandleReqParse(channel, msg)
    if !empty(a:msg)
        call s:engine_parse_async(a:channel, a:msg, 'HandleParse')
    endif
endfunc

func HandleReqGetHlt(channel, msg)
    if !empty(a:msg)
        call s:engine_get_hlt_async(a:channel, a:msg, 'HandleHlt')
    endif
endfunc

func HandleHlt(channel, msg)
    if a:msg['bufname'] != expand('%:p')
        return
    endif

    call s:clear_match_by_priorities([g:clighter8_syntax_priority, g:clighter8_usage_priority])
    call s:do_hlt(a:msg['hlt'])
endfunc

func s:do_hlt(matches)
    for [l:group, l:all_pos] in items(a:matches)
        let l:count = 0
        let l:match8 = []
        let l:priority = (l:group ==# 'clighter8Usage') ? g:clighter8_usage_priority : g:clighter8_syntax_priority 

        for l:pos in l:all_pos
            call add(l:match8, l:pos)
            let l:count += 1
            if l:count == 8
                call matchaddpos(l:group, l:match8, l:priority)

                let l:count = 0
                let l:match8 = []
            endif
        endfor

        call matchaddpos(l:group, l:match8, l:priority)
    endfor
endf

fun! s:do_replace(usage, old, new, qflist)
    let l:pattern = ''
    for [l:row, l:col] in a:usage
        if (!empty(l:pattern))
            let l:pattern = l:pattern . '\|'
        endif

        let l:pattern = l:pattern . '\%' . l:row . 'l' . '\%>' . (l:col - 1) . 'c\%<' . (l:col + strlen(a:old)) . 'c' . a:old
        call add(a:qflist, {'filename':bufname(''), 'bufnr':bufnr(''), 'lnum':l:row, 'col':l:col, 'type' : 'I', 'text':"'".a:old."' was renamed to '".a:new."'"})
    endfor

    let l:cmd = '%s/' . l:pattern . '/' . a:new . '/gI'

    execute(l:cmd)
endf

fun! s:clear_match_by_priorities(priorities)
    for l:m in getmatches()
        if index(a:priorities, l:m['priority']) >= 0
            call matchdelete(l:m['id'])
        endif
    endfor
endf

fun! s:is_header(bufname)
    if empty(a:bufname)
        return ''
    endif

    let l:dot = -1
    let l:pos = 0
    let len = len(a:bufname)

    while l:pos < len
        if a:bufname[l:pos] ==# '.'
            let l:dot = l:pos
        endif

        let l:pos += 1
    endwhile

    if l:dot == -1 || l:dot == len(a:bufname) - 1
        return 0
    endif

    return a:bufname[l:dot + 1] ==? 'h'
endf

fun! ClFormat()
    let l:lines=printf('%s:%s', v:lnum, v:lnum+v:count-1)
    execute('pyf '.s:script_folder_path.'/../python/clang-format.py')
endf

fun ClRename()
    if !exists('s:channel')
        return
    endif

    let l:bufname = expand('%:p')
    call s:engine_parse(s:channel, l:bufname)
    let l:usr_info = s:engine_get_usr_info(s:channel, l:bufname, getpos('.'))
    
    if empty(l:usr_info)
        echohl WarningMsg
        echo '[clighter8] unable to rename'
        echohl None
        return
    endif

    let [l:old, l:usr] = l:usr_info
    echohl Question
    let l:new = input('Rename ' . l:old . ' to : ', l:old)
    echohl None
    if (empty(l:new) || l:old == l:new)
        return
    endif

    let l:qflist = []
    let l:wnr = winnr()
    let l:bufnr = bufnr('%')
    let l:pos = getpos('.')

    let l:prompt = confirm("rename '". l:old ."' to '" .l:new.'?', "&Yes\n&All\n&No", 1)
    if (l:prompt == 3 || l:prompt == 0)
        return
    endif

    let start = reltime()

    let l:buffers = getbufinfo()
    let l:all = len(l:buffers)

    let l:count = 0
    let l:chk = 10
    echohl MoreMsg
    echo 'process... 0%'

    " to sort the buffers
    let l:sources = []
    let l:headers = []
    for info in l:buffers
        if s:is_header(info.name) == 1
            call add(l:headers, info)
        else
            call add(l:sources, info)
        endif
    endfor

    let l:buffers = l:sources + l:headers

    for info in l:buffers
        execute('silent! buffer! '. info.bufnr)

        if index(['c', 'cpp', 'objc', 'objcpp'], &filetype) == -1
            continue
        endif

        let l:count +=  1
        let l:percent = 100.0 * l:count / l:all

        if l:percent >= l:chk
            echo 'process... ' . float2nr(l:percent) . '%'
            let l:chk += 10
        endif

        call s:engine_parse(s:channel, info.name)
        let l:usage = s:engine_rename(s:channel, info.name, l:usr)

        if empty(l:usage) 
            continue
        endif

        if (l:prompt == 1)
            let l:yn = confirm("rename '". l:old ."' to '" .l:new. "' in " .info.name. '?', "&Yes\n&No", 1)
            if (l:yn == 2)
                continue
            endif
        endif

        silent! call s:do_replace(l:usage, l:old, l:new, l:qflist)

        call s:engine_parse(s:channel, info.name)
    endfor

    echohl None

    call setqflist(l:qflist)
    exe 'buffer! '.l:bufnr
    call setpos('.', l:pos)
    copen
    exe l:wnr.'wincmd w'
    
    if l:prompt == 2
        let l:seconds = reltimefloat(reltime(start))
        echo printf('time usage: %f seconds', l:seconds)
    endif
endf

fun! OnTimer(timer)
    call s:engine_req_parse_async(s:channel, expand('%:p'), 'HandleReqParse')
endf

func! s:on_text_changed()
    if exists('s:timer')
        call timer_stop(s:timer)
    endif

    let s:timer = timer_start(800, 'OnTimer')
endf

fun! s:start_clighter8()
    if exists('s:channel')
        return
    endif

    let s:channel = ch_open('localhost:8787')
    if ch_status(s:channel) ==# 'fail'
        let l:cmd = 'python '. s:script_folder_path.'/../python/engine.py '. g:clighter8_logfile
        let s:job = job_start(l:cmd, {'stoponexit': ''})
        let s:channel = ch_open('localhost:8787', {'waittime': 1000})
        if ch_status(s:channel) ==# 'fail'
            echohl ErrorMsg
            echo '[clighter8] failed start engine'
            echohl None
            return
        endif
    endif

    let l:succ = s:engine_init(s:channel, g:clighter8_libclang_path, g:clighter8_global_compile_args, g:clighter8_highlight_whitelist, g:clighter8_highlight_blacklist)

    if l:succ == v:false
        echohl ErrorMsg
        echo '[clighter8] failed to init client'
        echohl None
        call ch_close(s:channel)
        unlet s:channel
        return
    endif

    call s:engine_req_parse_async(s:channel, expand('%:p'), 'HandleReqParse')

    augroup Clighter8
        autocmd!

        au TextChanged,TextChangedI,BufEnter * call s:on_text_changed()
        au BufEnter * call s:clear_match_by_priorities([g:clighter8_usage_priority, g:clighter8_syntax_priority])
        au CursorMoved,CursorMovedI * call s:engine_req_get_hlt_async(s:channel, expand('%:p'), 'HandleReqGetHlt')
        au BufDelete * call s:engine_delete_buffer_async(s:channel, expand('%:p'), '')
        au VimLeave * call s:stop_clighter8()
    augroup END
endf

fun! s:stop_clighter8()
    augroup Clighter8
        autocmd!
    augroup END

    if exists('s:channel')
        call ch_close(s:channel)
        unlet s:channel
    endif

    let a:wnr = winnr()
    windo call s:clear_match_by_priorities([g:clighter8_usage_priority, g:clighter8_syntax_priority])
    exe a:wnr.'wincmd w'
endf

command! ClStart call s:start_clighter8()
command! ClStop call s:stop_clighter8()
command! ClRestart call s:stop_clighter8() | call s:start_clighter8()
command! ClShowCursorInfo if exists ('s:channel') | call s:engine_cursor_info(s:channel, expand('%:p'), getpos('.')[1], getpos('.')[2]) | endif
command! ClShowCompileInfo if exists ('s:channel') | call s:engine_compile_info(s:channel, expand('%:p')) | endif
command! ClEnableLog if exists ('s:channel') | call s:engine_enable_log(s:channel, v:true) | endif
command! ClDisableLog if exists ('s:channel') | call s:engine_enable_log(s:channel, v:false) | endif

let g:clighter8_autostart = get(g:, 'clighter8_autostart', 1)
let g:clighter8_libclang_path = get(g:, 'clighter8_libclang_path', '')
let g:clighter8_usage_priority = get(g:, 'clighter8_usage_priority', 12)
let g:clighter8_syntax_priority = get(g:, 'clighter8_syntax_priority', 11)
let g:clighter8_highlight_blacklist = get(g:, 'clighter8_highlight_blacklist', [])
let g:clighter8_highlight_whitelist = get(g:, 'clighter8_highlight_whitelist', [])
let g:clighter8_global_compile_args = get(g:, 'clighter8_global_compile_args', ['-x', 'c++'])
let g:clighter8_logfile = get(g:, 'clighter8_logfile', '/tmp/clighter8.log')

if g:clighter8_autostart
    au Filetype c,cpp call s:start_clighter8()
endif

let g:loaded_clighter8=1
