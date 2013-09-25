" Simple tags automatic updater
" Author:   fanhe <fanhed@163.com>
" License:  GPLv2
" Create:   2013-09-25
" Change:   2013-09-25

" DEPENDING:
"   * ctags
"   * sed
"   * grep
"
" INSTALLATION:
"   put this file to ~/.vim/plugin
"
" USAGE:
"   $ ctags -R
"   $ vim <file> # now tags will update automatically
"
" OPTIONS:
"   g:tags_updater_update_exist     integer (default 0)
"       If not 0, Tags Updater only updates tags of file which the file is
"       already in tags file
"
"   g:tags_updater_ctags_program    string (default 'ctags')
"       The ctags program.
"
" LIMITATION:
"   If g:tags_updater_update_exist is 0, the file under directory of tags will
"   be updated. For example, case 1 will not be updated and case 2 will be.
"
"   case 1:
"       dir
"       |-- a
"       |   `-- tags
"       `-- file
"
"   case 2:
"       dir
"       |-- a
"       |   `-- file
"       `-- tags
"

if exists("g:loaded_tags_updater")
    finish
endif
let g:loaded_tags_updater = 1

" 完全根据 tags 文件决定是否更新文件的 tags
if !exists('g:tags_updater_update_exist')
    let g:tags_updater_update_exist = 0
endif
if !exists('g:tags_updater_ctags_program')
    let g:tags_updater_ctags_program = 'ctags'
endif

if !executable('grep')
    echomsg '[tags_updater] grep: command not found'
    finish
endif

if !executable('sed')
    echomsg '[tags_updater] sed: command not found'
    finish
endif

if !executable(g:tags_updater_ctags_program)
    echomsg printf('[tags_updater] %s: command not found',
            \       g:tags_updater_ctags_program)
    finish
endif

autocmd! BufWritePost * call s:AutoUpdateTags(expand("%"))

" ============================================================================

function s:IsWindowsOS() "{{{2
    return has("win32") || has("win64")
endfunction
"}}}
" 错误返回空字符串
function s:relpath(path, ...) "{{{2
    let path = a:path
    let start = get(a:000, 0, '.')

    if empty(start)
        return ''
    endif

    exec 'silent cd' start
    let result = fnamemodify(path, ':.')
    exec 'silent cd -'

    return result
endfunction
"}}}

" ============================================================================

" filename 直接使用，是否正确使用是调用者的责任
function s:UpdateTags(tagfile, filename, ...) "{{{2
    let workdir = get(a:000, 0, '.')
    let tagfile = a:tagfile
    let filename = a:filename
    let ctagsprog = g:tags_updater_ctags_program
    let cmd = printf('cd %s; sed -i ''/^[^\t]\+\t%s\t/d'' %s && %s -a -f %s %s &',
            \        shellescape(workdir),
            \        escape(filename, '/\[]'), shellescape(tagfile),
            \        shellescape(ctagsprog),
            \        shellescape(tagfile), shellescape(filename))
    let output = system(cmd)
    " NOTE: 由于使用了后台进程，所以 v:shell_error 会恒为 0
    if v:shell_error != 0
        echomsg printf('command run failed: %s', cmd)
        echomsg printf('command output: %s', output)
    endif
endfunction
"}}}
function s:AutoUpdateTags(filename) "{{{2
    let filename = a:filename
    let result = 0

    "let filepath = resolve(fnamemodify(filename, ':p'))
    let filepath = fnamemodify(filename, ':p')
    let filedir = fnamemodify(filename, ':p:h')

    for tagfile in tagfiles()
        " 貌似 tagfiles() 返回的结果是可信的
        if !filereadable(tagfile)
            continue
        endif

        "let tagfile = resolve(fnamemodify(tagfile, ':p'))
        let tagfile = fnamemodify(tagfile, ':p')
        let workdir = fnamemodify(tagfile, ':h')
        " 求出相对路径
        let tags_filename = s:relpath(filepath, workdir)

        if g:tags_updater_update_exist
            " 从 tags 文件搜索
            let cmd = printf('grep -q -P ''^[^\t]+\t%s\t'' %s',
                    \         escape(tags_filename, '\[]()'),
                    \         shellescape(tagfile))
            call system(cmd)
            if v:shell_error != 0
                continue
            endif
        else
            " filename 必须在 tagfile 所在目录或之下
            let tagdir = fnamemodify(tagfile, ':p:h')
            if s:IsWindowsOS()
                let tagdir .= '\'
            else
                let tagdir .= '/'
            endif
            if stridx(filepath, tagdir) != 0
                " filename 不在 tags 的根目录下，不处理
                continue
            endif
        endif

        call s:UpdateTags(tagfile, tags_filename, workdir)
        let result = 1
        break
    endfor

    return result
endfunction
"}}}

" vim: fdm=marker fen et sw=4 sts=4 fdl=1
