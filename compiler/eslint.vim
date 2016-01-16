"compiler to call eslint on javascript file

if exists('current_compiler')
  finish
endif
let current_compiler = 'eslint'

if exists(":CompilerSet") != 2
	command -nargs=* CompilerSet setlocal <args>
endif

"allow overriding lint on save (default is true)
if !exists('g:eslint_onwrite')
    let g:eslint_onwrite = 1
endif

"allow overriding default jump to first error (default is false)
if !exists('g:eslint_goto_error')
    let g:eslint_goto_error = 0
endif

if !exists('g:eslint_autofix')
    let g:eslint_autofix = 0
endif

"suppress warnings
if !exists('g:eslint_quiet')
    let g:eslint_quiet = 0
endif

if exists(':ESLint') != 2
    command ESLint :call ESLint(0)
endif

if exists(':ESLintFix') != 2
    command ESLintFix :call ESLintFix()
endif
"eslint:  npm install -g eslint
if executable('eslint')
  
  execute 'setlocal efm=%f:\ line\ %l\\,\ col\ %c\\,\ %m'

if g:eslint_autofix
    if g:eslint_quiet
      execute 'setlocal makeprg=eslint\ --fix\ --quiet\ -f\ compact\ %' 
    else
      execute 'setlocal makeprg=eslint\ --fix\ -f\ compact\ %' 
    endif
else
    if g:eslint_quiet
      execute 'setlocal makeprg=eslint\ --quiet\ -f\ compact\ %' 
    else
      execute 'setlocal makeprg=eslint\ -f\ compact\ %' 
    endif
endif

endif

if g:eslint_onwrite
    augroup javascript
        au!
        au BufWritePost *.js call ESLint(1)
    augroup end
endif

function! ESLint(saved)

    if !a:saved && &modified
        " Save before running
        write
    endif	

	"shellpipe
    if has('win32') || has('win16') || has('win95') || has('win64')
        setlocal sp=>%s
    else
        setlocal sp=>%s\ 2>&1
    endif

    if g:eslint_goto_error
	silent lmake
    else
	silent lmake!
    endif

    "open local window with errors
    :lwindow
	
endfunction

"*nix only, also a bit slow
"eslint doesn't allow piping input and fixing it
function! ESLintFix()
    let tmpfile = expand('%') . '_fixlint'
    exe ':noautocmd w! ' . tmpfile
    exe ':silent !eslint --fix ' . tmpfile . ' &> /dev/null'
    exe ':silent %!cat ' . tmpfile
    exe ':silent !rm ' . tmpfile
endfunction



