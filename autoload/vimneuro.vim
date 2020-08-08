function! vimneuro#GoZettel()
	let l:word = expand("<cWORD>")
	
	" check if this is a valid Neuron link
	if match(l:word, '\v\<[A-Za-z0-9-_]+(\?cf)?\>') == -1
		echom "nomatch"
		return
	endif
	
	let l:filename = substitute(l:word, '\v\<([A-Za-z0-9-_]+)(\?cf)?\>', '\1', "") . ".md"
	
	" check for existing Zettel with supplied name
	let l:fullname = g:vimneuro_path_zettelkasten."/".l:filename
	if filereadable(l:fullname) == v:false
		echom "ERROR: Zettel with name '".l:fullname."' does not exist!"
		return
	endif
	
	execute "edit! ".l:filename
endfunction

function! vimneuro#NewZettel()
	let l:name  = input("Enter name for new Zettel: ")
	let l:title = input("Enter title for new Zettel: ")
	redraw
	call vimneuro#CreateZettel(l:name, l:title)
endfunction

function! vimneuro#CreateZettel(name, title)

	if a:name != ""

		" check for valid name
		if match(a:name, '[^A-Za-z0-9-_]') != -1
			echom "ERROR: '".a:name."' is not a valid Zettel name. Allowed Characters: [A-Za-z0-9-_]"
			return
		endif

		" check for existing Zettel with supplied name
		let l:fullname = g:vimneuro_path_zettelkasten."/".a:name.".md"
		if filereadable(l:fullname) == v:true
			echom "ERROR: Zettel with name '".a:name."' already exists!"
			return
		endif
	endif

	" create Zettel
	if a:title == ""
		" let l:res = trim(system("neuron new"))
		let l:cmd = "neuron new"
	else
		" let l:res = trim(system("neuron new ".shellescape(a:title)))
		let l:cmd = "neuron new ".shellescape(a:title)
	endif

	let s:name = a:name
	let s:stdout = []

	function! s:OnEvent(job_id, data, event) dict

		if a:event == 'stdout'
			call add(s:stdout, join(a:data))
			let str = self.shell.' stdout: '.join(a:data)
		elseif a:event == 'stderr'
			let str = self.shell.' stderr: '.join(a:data)
		else
			let str = self.shell.' exited'

			if s:name != ""
				let l:fullname = g:vimneuro_path_zettelkasten."/".s:name.".md"
				call vimneuro#RenameZettel(trim(s:stdout[0]), l:fullname)
				execute "edit! ".l:fullname
			else
				execute "edit! ".trim(s:stdout[0])
			endif
		endif

		echom str
	endfunction

	let s:callbacks = {
				\ 'on_stdout': function('s:OnEvent'),
				\ 'on_stderr': function('s:OnEvent'),
				\ 'on_exit': function('s:OnEvent')
				\ }

	let job1 = jobstart(['bash', '-c', l:cmd], extend({'shell': 'shell 1'}, s:callbacks))
endfunction

function! vimneuro#RenameZettel(oldname, newname)

	" check if Zettel to rename really exists
	if filereadable(a:oldname) == v:false
		echom "ERROR: Zettel with name '".a:oldname."' does not exists!"
		return v:false
	endif

	" check for existing Zettel with supplied name
	if filereadable(a:newname) == v:true
		echom "ERROR: Zettel with name '".a:newname."' already exists!"
		return v:false
	endif

	" rename Zettel
	if rename(a:oldname, a:newname) == 0
		return v:true
	else
		return v:false
	endif

endfunction

function! vimneuro#RenameCurrentZettel()

	let l:oldname = bufname()
	let l:newname = input("Enter new name: ")
	redraw
	echom ""

	if l:newname == ""
		echom "ERROR: No name supplied."
		return
	endif

	" check for valid name
	if match(l:newname, '[^A-Za-z0-9-_]') != -1
		echom "ERROR: '".l:newname."' is not a valid Zettel name. Allowed Characters: [A-Za-z0-9-_]"
		return
	endif

	let l:fullname = l:newname.".md"
	if vimneuro#RenameZettel(l:oldname, l:fullname) != v:false
		execute "file! ".l:fullname
		silent write!
		
		" update all links
		let l:oldlink = substitute(l:oldname, '\v\.md', '', "")
		call vimneuro#RelinkZettel(l:oldlink, l:newname)
	endif
	
endfunction

" replaces links to Zettel 'oldname' with 'newname' in every Zettel
function! vimneuro#RelinkZettel(oldname, newname)
	let l:curbuf    = bufnr()
	let linkpattern = '<'.a:oldname.'(\?cf)?>'
	
	silent execute "grep! '".linkpattern."'" 
	" copen
	execute 'cfdo %substitute/\v\<'.a:oldname.'(\?cf)?\>/\<'.a:newname.'\1\>/g'
	cfdo update
	
	" switch back to original buffer
	execute "buffer ".l:curbuf	
	return v:true
endfunction

function! vimneuro#CreateLinkOfFilename(filename)
	return "<" . substitute(a:filename, '\.md', '', "") .">"
endfunction

function! vimneuro#PasteLinkAsUlItem()
	execute "normal! o\<esc>\"_d0i- \<c-r>+\<esc>"
endfunction

function! vimneuro#GetLinkToAlternateBuffer()
	let l:filename = bufname(0)
	
	if l:filename ==# ""
		echom "ERROR: No alternative buffer"
		return v:false
	endif
	
	return vimneuro#CreateLinkOfFilename(l:filename)
endfunction

function! vimneuro#InsertLinkToAlternateBuffer()
	let l:link = vimneuro#GetLinkToAlternateBuffer()
	if l:link != v:false
		call nvim_paste(l:link, v:true, -1)
	endif
endfunction

function! vimneuro#InsertLinkToAlternateBufferAsUlItem()
	let l:link = vimneuro#GetLinkToAlternateBuffer()
	if l:link != v:false
		let @+ = l:link
		call vimneuro#PasteLinkAsUlItem()
	endif
endfunction

" create a neuron link to the zettel matching the text
function! vimneuro#LinkingOperator(type)
	let sel_save = &selection
	let &selection = "inclusive"
	let reg_save_1 = @@
	let reg_save_2 = @k

	if a:type ==# 'v'
		normal! `<v`>y
	elseif a:type ==# 'char'
		normal! `[v`]y
	else
		return
	endif

	let l:title = trim(@@)
	silent execute "grep! '^\\# ".l:title."$'" 
	let l:results = getqflist()

	if len(l:results) == 0
		let l:i = input("ERROR: No Zettel with title ".shellescape(l:title)." found. Create new Zettel? (y/n) ")
		if l:i ==# "y"
			let l:name = input("Enter name for new Zettel: ")
			call vimneuro#CreateZettel(l:name, l:title)
		else
			echom ""
		endif
	elseif len(l:results) > 1
		echoe "ERROR: Multiple Zettels with title (".shellescape(l:title).") found."
	else
		let d = l:results[0]
		let @k = vimneuro#CreateLinkOfFilename(bufname(d.bufnr))
		normal! `[v`]"kp
	endif
	
	let &selection = sel_save
	let @@ = reg_save_1
	let @k = reg_save_2
endfunction

function! vimneuro#CopyLinkOfCurrentBuffer()
	let l:filename = substitute(expand('%'), '\v\.md', '', "")
	let @+ = "<".l:filename.">"
	echom "'<".l:filename.">' copied to + register"
endfunction

function! vimneuro#CopyLinkOfCurrentLine(linenum)
	let l:link = vimneuro#GetLinkOfCurrentLine(a:linenum)	
	let @+ = l:link
	echom "'".l:link."' copied to + register"
endfunction

" searches for `FOOBAR.md` in the current line,
" creates and returns a Neuron link
function! vimneuro#GetLinkOfCurrentLine(linenum)
	let l:line     = getline(a:linenum)
	let l:filename = []
	call substitute(l:line, '\v(^|\s)\zs[a-z0-9]+\ze\.md', '\=add(l:filename, submatch(0))', 'g')
	
	if len(l:filename) == 0
		return
	endif
	
	let l:links = map(l:filename, '"<".v:val.">"')
	return l:links[0]
endfunction

function! vimneuro#CopyLinkOfSelection()
	let l:start = getpos("'<")
	let l:stop  = getpos("'>")
	let l:lines = range(l:start[1], l:stop[1])
	let l:links = map(l:lines, 'vimneuro#GetLinkOfCurrentLine(v:val)')
	let str = ""
	for i in l:links
		if i == v:false
			continue
		endif
		let str = str.i."\n"	
	endfor
	let @+ = str
	echom "Copied links to + register"
endfunction