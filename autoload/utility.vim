let g:vimneuro_save_options = {}
let g:vimneuro_save_registers = {}

function! utility#PrintOptions()
	echom &grepprg
	echom &grepformat
	echom &cpo
	echom &selection
	pwd
endfunction

function! utility#SaveOptions()
	let g:vimneuro_save_options["grepprg"]    = &grepprg
	let g:vimneuro_save_options["grepformat"] = &grepformat
	let g:vimneuro_save_options["cpo"]        = &cpo
	let g:vimneuro_save_options["selection"]  = &selection
	let g:vimneuro_save_options["cwd"]				= getcwd()
endfunction

function! utility#SetOptions()
	set grepprg=rg\ --vimgrep\ --smart-case
	set grepformat^=%f:%l:%c:%m
	set cpo&vim
	set selection=inclusive
endfunction

function! utility#RestoreOptions()
	let &grepprg    = g:vimneuro_save_options["grepprg"]
	let &grepformat = g:vimneuro_save_options["grepformat"]
	let &cpo        = g:vimneuro_save_options["cpo"]
	let &selection  = g:vimneuro_save_options["selection"]
	execute "cd ".g:vimneuro_save_options["cwd"]
endfunction

function! utility#PrintRegisters()
	echom g:vimneuro_save_registers
	for key in keys(g:vimneuro_save_registers)
		echom getreg(key)
	endfor
endfunction

function! utility#SaveRegisters(regs)
	for i in a:regs
		let g:vimneuro_save_registers[i] = getreg(i)
	endfor
endfunction

function! utility#RestoreRegisters()
	for key in keys(g:vimneuro_save_registers)
		call setreg(key, g:vimneuro_save_registers[key])
	endfor
	let g:vimneuro_save_registers = {}
endfunction