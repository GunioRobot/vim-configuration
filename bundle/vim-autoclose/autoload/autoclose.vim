" Automatically close pairs.
" Maintainer: INAJIMA Daisuke <inajima@sopht.jp>
" License: MIT License

let s:cpo_save = &cpo
set cpo&vim

function! s:getlc(off)
    let i = col('.') - 1 + a:off
    return i < 0 ? '' : getline('.')[i]
endfunction

function! s:get_syn_name(off)
    let col = col('.') + a:off
    return synIDattr(synID(line('.'), col, 1), 'name')
endfunction

function! s:get_syngr_name(off)
    let col = col('.') + a:off
    return synIDattr(synIDtrans(synID(line('.'), col, 1)), 'name')
endfunction

function! s:get_syngr_name_after(str, off)
    let line = getline('.')
    let tmp = line[:col('.')-2] . a:str . line[col('.')-1:]
    call setline('.', tmp)
    redraw
    let region = s:get_syngr_name(a:off)
    call setline('.', line)
    redraw
    return region
endfunction

function! s:insert_char()
    if ((col("']") == col("$") && col(".") + 1 == col("$")) ||
    \	(line("']") == line("$") + 1 && line(".") == line("$")))
	return 'a'
    else
	return 'i'
    endif
endfunction

function! autoclose#open(char)
    if autoclose#is_forbidden(a:char)
	return a:char
    endif
    return a:char . g:autoclose_pairs[a:char] . "\<Left>"
endfunction

function! autoclose#close(char)
    if s:getlc(0) == a:char
	return "\<Right>"
    endif
    return a:char
endfunction

function! autoclose#expand(char)
    if s:getlc(-1) == a:char && autoclose#is_empty()
	return "\<CR>\<Esc>O"
    endif

    return autoclose#open(a:char)
endfunction

function! autoclose#shrink(char)
    if s:getlc(-1) == a:char && getline(line('.')) == getline(line('.') + 1)
	delete _
	return "\<Right>"
    endif
    return autoclose#close(a:char)
endfunction

function! autoclose#quote(char)
    let regions = autoclose#quoted_regions()

    if index(regions, s:get_syngr_name(-1)) >= 0 ||
    \  index(regions, s:get_syngr_name_after(' ', 0)) >= 0
	return autoclose#close(a:char)
    endif

    let dummy = a:char . ' ' . a:char
    if index(regions, s:get_syngr_name_after(dummy, 1)) >= 0
	return autoclose#open(a:char)
    endif

    return a:char
endfunction

function! autoclose#open_tag(char)
    let region = synIDattr(synID(line("."), col(".") - 1, 1), "name")
    if match(region, "xmlProcessing") == -1 &&
    \  match(region, 'docbk\|html\|xml') == 0
	if s:getlc(-1) == '>'
	    return "\<CR>\<Esc>O"
	elseif s:getlc(-1) != '/'
	    let pos_save = getpos('.')
	    let reg_save = getreg('"')

	    normal! hv
	    call search('<', 'bW')
	    normal! y
	    let tagname = matchstr(getreg('"'), '^<\s*\zs[[:alnum:]_:.-]\+')
	    if tagname == ''
		call setreg('"', reg_save)
		call setpos('.', pos_save)
		return a:char
	    endif
	    let close_tag = '</' . tagname . '>'

	    call setreg('"', reg_save)
	    call setpos('.', pos_save)

	    return '>' . close_tag . repeat("\<Left>", len(close_tag))
	endif
    endif

    return a:char
endfunction

function! autoclose#close_tag(char)
    if !(s:getlc(-1) == '<' && s:getlc(0) == '<' && s:getlc(1) == '/')
	return a:char
    endif
    normal! "_x
    if search('>', 'W') == 0
	return "<\<Left>" . a:char
    endif
    return "\<Right>"
endfunction

function! autoclose#delete()
    let char = s:getlc(-1)
    if char =~ '\s\?' && autoclose#is_expanded()
	return "\<Esc>ddkJxi"
    elseif char == '>' && autoclose#is_empty_tag()
	normal! hx"_da<
	return s:insert_char() == 'a' ? "\<Right>" : ''
    elseif autoclose#is_empty()
        return "\<BS>\<Del>"
    else
	return "\<BS>"
    endif
endfunction

function! autoclose#is_empty()
    let prev = s:getlc(-1)
    let next = s:getlc(0)

    return !empty(prev) && !empty(next) &&
    \      get(g:autoclose_pairs, prev, "") == next
endfunction

function! autoclose#is_expanded(...)
    let char = a:0 > 1 ? a:1 : ''

    if line('.') == 1 || line('.') == line('$')
	return 0
    endif

    let curline = getline(line('.'))
    if curline !~ '^\s*$'
	return 0
    endif

    let prevline = getline(line('.') - 1)
    let nextline = getline(line('.') + 1)
    if prevline =~ '^\s*$' || nextline =~ '^\s*$'
	return 0
    endif

    let pos_save = getpos('.')

    if search('\S', 'bW', line('.') - 1) == 0
	call setpos('.', pos_save)
	return 0
    endif

    let open = s:getlc(0)
    if open == '>'
	let open = 't'
    elseif index(keys(g:autoclose_pairs), open) == -1
	call setpos('.', pos_save)
	return 0
    endif

    if char != '' && char != open
	call setpos('.', pos_save)
	return 0
    endif

    let reg_save = getreg('"')

    execute 'normal! yi' . open
    let reg = getreg('"')

    call setreg('"', reg_save)
    call setpos('.', pos_save)

    return (reg == '' && getline('.') =~ '^\s*$') || reg =~ '^\_s*$'
endfunction

function! autoclose#exit_forward()
    let regions = autoclose#quoted_regions()
    let synname = s:get_syngr_name(0)

    if index(regions, synname) >= 0
	while s:get_syngr_name(0) ==# synname &&
	\     !(line('.') == line('$') && col('.') == col('$') - 1)
	    call search('\_.', 'W', line('w$'))
	endwhile
	if col('.') == 1
	    call search('\_.', 'bW')
	    return "\<Right>"
	endif
	return ""
    endif

    if searchpair('[[<({]', '', '[\]>)}]', 'W',
       \	  'index(regions, s:get_syngr_name(0)) >= 0', line('w$'))
	return "\<Right>"
    else
	return ""
    endif
endfunction

function! autoclose#exit_backward()
    let regions = autoclose#quoted_regions()
    let synname = s:get_syngr_name(0)

    if index(regions, synname) >= 0
	while s:get_syngr_name(0) ==# synname &&
	\     !(line('.') == 1 && col('.') == 1)
	    call search('\_.', 'bW', line('w0'))
	endwhile
	call search('\_.', 'W')
	return ""
    endif

    if searchpair('[[<({]', '', '[\]>)}]', 'bW',
       \	  'index(regions, s:get_syngr_name(0)) >= 0', line('w0'))
	return ""
    else
	if index(regions, s:get_syngr_name(-1)) >= 0 || s:getlc(-1) =~ '[\]>)}]'
	    normal! h
	    return autoclose#exit_backward()
	endif
	return ""
    endif
endfunction

function! autoclose#is_empty_tag()
    if !(s:getlc(-1) == '>' && s:getlc(0) == '<')
	return 0
    endif

    let pos_save = getpos('.')
    let reg_save = getreg('"')
    call setreg('"', '')

    normal! hyit
    let result = (getreg('"') == '')

    call setreg('"', reg_save)
    call setpos('.', pos_save)
    return result
endfunction

function! autoclose#quoted_regions()
    let type = has_key(g:autoclose_quoted_regions, &ft) ? &ft : "_"
    return g:autoclose_quoted_regions[type]
endfunction

function! autoclose#is_forbidden(char)
    let Func = function("autoclose#no_rule")
    let Func = get(g:autoclose_rules, "_", Func)
    let Func = get(g:autoclose_rules, a:char, Func)

    return call(Func, [a:char])
endfunction

function! autoclose#no_rule(char)
    return 0
endfunction

function! autoclose#default_rule(char)
    let prev = s:getlc(-1)
    let next = s:getlc(0)

    return prev ==# '\' || (next != "" && next =~ '\w') ||
    \	   s:get_syngr_name_after(a:char, 0) ==# "Character"
endfunction

let &cpo = s:cpo_save
