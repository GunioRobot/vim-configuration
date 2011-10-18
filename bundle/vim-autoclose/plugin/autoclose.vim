" Automatically close pairs.
" Maintainer: INAJIMA Daisuke <inajima@sopht.jp>
" Version: 0.1
" License: MIT License

if exists("g:loaded_autoclose")
    finish
endif
let g:loaded_autoclose = 1

let s:cpo_save = &cpo
set cpo&vim

augroup autoclose
    autocmd!
    autocmd VimEnter * call <SID>autoclose_fixup()
augroup END

command! -nargs=? AutoClose :call <SID>autoclose(<f-args>)

let s:autoclose_enabled = 0

function! s:autoclose(...)
    if a:0 == 0
	let enable = !s:autoclose_enabled
    else
	let enable = !(a:1 == '0' || a:1 =~ 'off')
    endif

    if enable == s:autoclose_enabled
	return
    endif

    if enable
	for key in keys(g:autoclose_pairs)
	    let val = g:autoclose_pairs[key]

	    if key == val
		let kv = (key == '"' ? '\"' : key)
		execute 'inoremap <silent>' key
		\       '<C-r>=autoclose#quote("' . kv . '")<CR>'
	    else
		if index(g:autoclose_expand_chars, key) >= 0
		    execute 'inoremap <silent>' key
		    \	    '<C-r>=autoclose#expand("' . key . '")<CR>'
		    execute 'inoremap <silent>' val
		    \	    '<C-r>=autoclose#shrink("' . val . '")<CR>'
		else
		    execute 'inoremap <silent>' key
		    \	    '<C-r>=autoclose#open("' . key . '")<CR>'
		    execute 'inoremap <silent>' val
		    \	    '<C-r>=autoclose#close("' . val . '")<CR>'
		endif
	    endif
	endfor
	if g:autoclose_tag
	    inoremap <silent> > <C-r>=autoclose#open_tag('>')<CR>
	    inoremap <silent> < <C-r>=autoclose#close_tag('<')<CR>
	endif
	inoremap <silent> <BS>  <C-r>=autoclose#delete()<CR>
	inoremap <silent> <C-h> <C-r>=autoclose#delete()<CR>
	inoremap <silent> <C-g><C-i> <C-r>=autoclose#exit_forward()<CR>
	inoremap <silent> <C-g><C-o> <C-r>=autoclose#exit_backward()<CR>

	let s:autoclose_enabled = 1
        echo "AutoClose ON"
    else
	for key in keys(g:autoclose_pairs)
	    let val = g:autoclose_pairs[key]

	    if key == val
		execute 'iunmap' key
	    else
		execute 'iunmap' key
		execute 'iunmap' val
	    endif
	endfor
	if g:autoclose_tag
	    iunmap >
	    iunmap <
	endif
	iunmap <BS>
	iunmap <C-h>
	iunmap <C-g><C-i>
	iunmap <C-g><C-o>

	let s:autoclose_enabled = 0
        echo "AutoClose OFF"
    endif
endfunction

function! s:autoclose_fixup()
    let syns = get(g:autoclose_quoted_regions, &filetype, [])
    let syns = extend(copy(syns), g:autoclose_quoted_regions['_'])

    for syn in syns
	let id = hlID(syn)
	let tid = synIDtrans(id)

	if id == tid
	    continue
	endif

	let args = []

	for mode in ['gui', 'cterm', 'term']
	    let attrs = ['bold', 'underline', 'undercurl', 'reverse',
	    \		 'italic', 'standout']
	    call filter(attrs, 'synIDattr(' . tid . ', v:val, "' . mode . '")')

	    if !empty(attrs)
		call add(args, mode . '=' . join(attrs, ','))
	    endif

	    if mode == 'gui' || mode == 'cterm'
		for fgbg in ['fg', 'bg']
		    let color = synIDattr(tid, fgbg, mode)
		    if color != -1
			call add(args, mode . fgbg . '=' . color)
		    endif
		endfor
	    endif
	endfor

	let argstr = empty(args) ? 'NONE' : join(args, ' ')
	execute 'highlight' syn argstr
    endfor
endfunction

if !exists("g:autoclose_pairs")
    let g:autoclose_pairs = {'(': ')', '{': '}', '[': ']',
    \			     '"': '"', "'": "'", "`": "`"}
endif

if !exists("g:autoclose_expand_chars")
    let g:autoclose_expand_chars = ['{']
endif

if !exists("g:autoclose_tag")
    let g:autoclose_tag = 1
endif

if !exists("g:autoclose_rules")
    let g:autoclose_rules = {"_": function("autoclose#default_rule")}
endif

if !exists("g:autoclose_quoted_regions")
    let g:autoclose_quoted_regions = {}
endif
if !has_key(g:autoclose_quoted_regions, "_")
    let g:autoclose_quoted_regions['_'] = ["Character", "SpecialChar", "String"]
endif

silent call s:autoclose(1)

let &cpo = s:cpo_save
