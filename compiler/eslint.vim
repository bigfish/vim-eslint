"compiler to call eslint on javascript file

let s:eslint_server = expand('<sfile>:p:h') . '/../bin/eslint-server.js'

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

execute 'setlocal efm=%f:\ line\ %l\\,\ col\ %c\\,\ %m'

if g:eslint_onwrite
    augroup javascript
        au!
        "au BufWritePost *.js call ESLint(1)
        au BufWritePost *.js call ESLint2()
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

function! GetBufferText()
    "obtain contents of buffer
    let buflines = getline(1, '$')

    "replace hashbangs (in node CLI scripts)
    let linenum  = 0
    for bline in buflines
        if match(bline, '#!') == 0
            "replace #! with // to prevent parse errors
            "while not throwing off byte count
            let buflines[linenum] = '//' . strpart(bline, 2)
            break
        endif
        let linenum += 1
    endfor
    "fix offset errors caused by windows line endings
    "since 'buflines' does NOT return the line endings
    "we need to replace them for unix/mac file formats
    "and for windows we replace them with a space and \n
    "since \r does not work in node on linux, just replacing
    "with a space will at least correct the offsets
    if &ff == 'unix' || &ff == 'mac'
        let buftext = join(buflines, "\n")
    elseif &ff == 'dos'
        let buftext = join(buflines, " \n")
    else
        echom 'unknown file format' . &ff
        let buftext = join(buflines, "\n")
    endif

    return buftext

endfunction

function! ESLint_StartServer()
	  let s:eslint_server_job = job_start(["/bin/sh", "-c", "node " . s:eslint_server])
endfunction

function! ESLint_OpenChannel(wait)
    let g:eslint_channel = ch_open('localhost:9696', {'mode': 'json',
                \'waittime': a:wait,
                \'callback': 'ESLint_ChannelResponse' })
    let status = ch_status(g:eslint_channel)
    if status == 'fail' || status == 'closed'
        return 0
    else
        return 1
    endif
endfunction


function! ESLint2()

    if !exists('g:eslint_connected') || !g:eslint_connected
        let g:eslint_connected = ESLint_OpenChannel(0)
        let tries = 1

        "start server job if unable to connect
        if !g:eslint_connected
            call ESLint_StartServer()
            while !g:eslint_connected
                let g:eslint_connected = ESLint_OpenChannel(100)
                let tries += 1
                if tries > 20
                    break
                endif
            endwhile
        endif

        if !g:eslint_connected
            echom 'Failed to connect to eslint server, status: ' .  ch_status(g:eslint_channel)
        else
            "echom 'connected to ESLint server'
        endif
    endif

    let json = json_encode({ 'file': expand('%:p'), 'code': GetBufferText()})

    call ch_sendexpr(g:eslint_channel, json, {'callback': 'ESLint_ChannelResponse'})

endfunction

function! ESLint_ChannelResponse(channel, result)

    "echom 'ESLint_ChannelResponse: ' . string(a:result)
    if has_key(a:result, 'fixed')
        let pos = winsaveview()
        let fixedCode = a:result['fixed']
        "replace code
        let @f = fixedCode
        :%d
        normal "fp
        call winrestview(pos)
    endif

    if has_key(a:result, 'error')
        echoerr a:result['error']
    endif

    if has_key(a:result, 'errorfile') && len(a:result.errorfile)
        "show error messages
        if g:eslint_goto_error
            exe ':lf ' . a:result.errorfile
        else
            exe ':lg ' . a:result.errorfile
        endif

        :lope

        if g:eslint_goto_error
            :lfirst
        else
            "restore cursor position, as :lope always steals focus
            :wincmd p
        endif
    else
        "no errors -- close quickfix window
        :lcl
    endif

endfunction

