" Author: Yining <zhang.yining@gmail.com>
" Description: ruff as ALE fixer for python files

call ale#Set('python_ruff_executable', 'ruff')
call ale#Set('python_ruff_options', '')
call ale#Set('python_ruff_use_global', get(g:, 'ale_use_global_executables', 0))
call ale#Set('python_ruff_change_directory', 1)
call ale#Set('python_ruff_auto_pipenv', 0)
call ale#Set('python_ruff_auto_poetry', 0)
call ale#Set('python_ruff_auto_uv', 0)
call ale#Set('python_ruff_auto_pixi', 0)

function! ale#fixers#ruff#GetCwd(buffer) abort
    if ale#Var(a:buffer, 'python_ruff_change_directory')
        " Run from project root if found, else from buffer dir.
        let l:project_root = ale#python#FindProjectRoot(a:buffer)

        return !empty(l:project_root) ? l:project_root : '%s:h'
    endif

    return '%s:h'
endfunction

function! ale#fixers#ruff#GetExecutable(buffer) abort
    if (ale#Var(a:buffer, 'python_auto_pipenv') || ale#Var(a:buffer, 'python_ruff_auto_pipenv'))
    \ && ale#python#PipenvPresent(a:buffer)
        return 'pipenv'
    endif

    if (ale#Var(a:buffer, 'python_auto_poetry') || ale#Var(a:buffer, 'python_ruff_auto_poetry'))
    \ && ale#python#PoetryPresent(a:buffer)
        return 'poetry'
    endif

    if (ale#Var(a:buffer, 'python_auto_uv') || ale#Var(a:buffer, 'python_ruff_auto_uv'))
    \ && ale#python#UvPresent(a:buffer)
        return 'uv'
    endif

    if (ale#Var(a:buffer, 'python_auto_pixi') || ale#Var(a:buffer, 'python_ruff_auto_pixi'))
    \ && ale#python#PixiPresent(a:buffer)
        return 'pixi'
    endif

    return ale#python#FindExecutable(a:buffer, 'python_ruff', ['ruff'])
endfunction

function! ale#fixers#ruff#GetCommand(buffer) abort
    let l:executable = ale#fixers#ruff#GetExecutable(a:buffer)
    if (l:executable == "pixi")
	    let l:pixi_env = ale#python#PixiEnv(a:buffer)
	    if l:pixi_env == ''
		let l:exec_args = ' exec ruff'
	    else
	    	let l:exec_args = ' run -e ' . l:pixi_env . ' ruff'
	    endif
    elseif (l:executable =~? '\(pipenv\|poetry\|uv\)$')
	    let l:exec_args = ' run ruff'
    else
	    let l:exec_args = ''
    endif

    return ale#Escape(l:executable) . l:exec_args
endfunction

function! ale#fixers#ruff#FixForVersion(buffer, version) abort
    let l:executable = ale#fixers#ruff#GetExecutable(a:buffer)
    let l:cmd = [ale#Escape(l:executable)]

    if l:executable == 'pixi'
	let l:pixi_env = ale#python#PixiEnv(a:buffer)
	if l:pixi_env == ''
	    call extend(l:cmd, ['exec', 'ruff'])
	else
	    call extend(l:cmd, ['run', '-e', l:pixi_env, 'ruff'])
	endif
    elseif l:executable =~? '\(pipenv\|poetry\|uv\)$'
        call extend(l:cmd, ['run', 'ruff'])
    endif

    " NOTE: ruff 0.5.0 removes `ruff <path>` in favor of `ruff check <path>`
    if ale#semver#GTE(a:version, [0, 5, 0])
        call extend(l:cmd, ['check'])
    endif

    let l:options = ale#Var(a:buffer, 'python_ruff_options')

    if !empty(l:options)
        call add(l:cmd, l:options)
    endif

    " when --stdin-filename present, ruff will use it for proj root resolution
    " https://github.com/charliermarsh/ruff/pull/1281
    let l:fname = expand('#' . a:buffer . '...')
    call add(l:cmd, '--stdin-filename '.ale#Escape(ale#path#Simplify(l:fname)))

    call add(l:cmd, '--fix')

    " NOTE: ruff version `0.0.72` implements `--fix` with stdin
    if ale#semver#GTE(a:version, [0, 0, 72])
        call add(l:cmd, '-')
    else
        call add(l:cmd, '%s')
    endif

    return {
    \   'cwd': ale#fixers#ruff#GetCwd(a:buffer),
    \   'command': join(l:cmd, ' '),
    \}
endfunction

function! ale#fixers#ruff#Fix(buffer) abort
    let l:executable = ale#fixers#ruff#GetExecutable(a:buffer)
    let l:command = ale#fixers#ruff#GetCommand(a:buffer) . ale#Pad('--version')

    return ale#semver#RunWithVersionCheck(
    \     a:buffer,
    \     l:executable,
    \     l:command,
    \     function('ale#fixers#ruff#FixForVersion'),
    \)
endfunction
