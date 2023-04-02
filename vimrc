set clipboard=unnamedplus
set cursorline  " 高亮当前行
set autowriteall  " 切换界面自动保存
set autoread  " 自动加载
set guicursor+=a:blinkon0  " 停止光标闪烁
if &term =~ "xterm"  " 设置光标在不同模式下的形状
    " INSERT mode
    let &t_SI = "\<Esc>[6 q" . "\<Esc>]12"
    " REPLACE mode
    let &t_SR = "\<Esc>[3 q" . "\<Esc>]12"
    " NORMAL mode
    let &t_EI = "\<Esc>[2 q" . "\<Esc>]12"
endif
" set guicursor+=a:block
set ts=4  " 将tab转为4个空格
set expandtab
" colorscheme molokai " 设置vim配色
colorscheme gruvbox
set background=dark

" Comments in Vimscript start with a `"`.

" If you open this file in Vim, it'll be syntax highlighted for you.

" Vim is based on Vi. Setting `nocompatible` switches from the default
" Vi-compatibility mode and enables useful Vim functionality. This
" configuration option turns out not to be necessary for the file named
" '~/.vimrc', because Vim automatically enters nocompatible mode if that file
" is present. But we're including it here just in case this config file is
" loaded some other way (e.g. saved as `foo`, and then Vim started with
" `vim -u foo`).
" set nocompatible

" Turn on syntax highlighting.
" syntax on

" Disable the default Vim startup message.
set shortmess+=I

" Show line numbers.
set number

" This enables relative line numbering mode. With both number and
" relativenumber enabled, the current line shows the true line number, while
" all other lines (above and below) are numbered relative to the current line.
" This is useful because you can tell, at a glance, what count is needed to
" jump up or down to a particular line, by {count}k to go up or {count}j to go
" down.
set relativenumber

" Always show the status line at the bottom, even if you only have one window open.
"set laststatus=2

" The backspace key has slightly unintuitive behavior by default. For example,
" by default, you can't backspace before the insertion point set with 'i'.
" This configuration makes backspace behave more reasonably, in that you can
" backspace over anything.
set backspace=indent,eol,start

" By default, Vim doesn't let you hide a buffer (i.e. have a buffer that isn't
" shown in any window) that has unsaved changes. This is to prevent you from "
" forgetting about unsaved changes and then quitting e.g. via `:qa!`. We find
" hidden buffers helpful enough to disable this protection. See `:help hidden`
" for more information on this.
set hidden

" This setting makes search case-insensitive when all characters in the string
" being searched are lowercase. However, the search becomes case-sensitive if
" it contains any capital letters. This makes searching more convenient.
set ignorecase
set smartcase

" Enable searching as you type, rather than waiting till you press enter.
set incsearch

" Unbind some useless/annoying default key bindings.
nmap Q <Nop> " 'Q' in normal mode enters Ex mode. You almost never want this.

" Disable audible bell because it's annoying.
set noerrorbells visualbell t_vb=

" Enable mouse support. You should avoid relying on this too much, but it can
" sometimes be convenient.
set mouse+=a

" 设置剪贴命令
map ;y :!/mnt/c/Windows/System32/clip.exe <cr>u
map ;p :read !/mnt/c/Windows/System32/paste.exe <cr>i<bs><esc>l
map! ;p <esc>:read !/mnt/c/Windows/System32/paste.exe <cr>i<bs><esc>l

" 插件配置
call plug#begin('~/.vim/plugged')
" Plug 'neoclide/coc.nvim', {'branch': 'release'}
" Plug 'jiangmiao/auto-pairs'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
" Plug 'godlygeek/tabular'  " markdown Plug
Plug 'preservim/vim-markdown'  " markdown Plug
call plug#end()

" 禁用markdown折叠功能
set nofoldenable

" 配置airline
set laststatus=2  "永远显示状态栏
let g:airline_powerline_fonts = 1  " 支持 powerline 字体
let g:airline#extensions#tabline#enabled = 1 " 显示窗口tab和buffer
let g:airline_theme='gruvbox'

if !exists('g:airline_symbols')
let g:airline_symbols = {}
endif
let g:airline_left_sep = '▶'
let g:airline_left_alt_sep = '❯'
let g:airline_right_sep = '◀'
let g:airline_right_alt_sep = '❮'
let g:airline_symbols.linenr = '¶'
let g:airline_symbols.branch = '⎇'

set smarttab
set tabstop=4
set shiftwidth=4

" Quickly Run
map <F5> :call CompileRunGcc()<CR>
func! CompileRunGcc()
    exec "w"
    if &filetype == 'c'
        exec '!g++ -D _DEBUG % -o ./bin/%<'
        exec '!time ./bin/%<'
    elseif &filetype == 'cpp'
		#exec '!g++ -D _DEBUG -O2 -Wno-unused-result % -o ./bin/%<'
		#exec '!g++ -D _DEBUG -O2 -Wl,-z,stack-size=536870912 -mcmodel=large -Wno-unused-result % -o ./bin/%<'
		exec '!g++ -D _DEBUG -pthread -O2 -Wl,-z,stack-size=536870912 -mcmodel=large -Wno-unused-result % -o ./bin/%<'
        exec '!time ./bin/%<'
    elseif &filetype == 'python'
        exec '!time python3 %'
    elseif &filetype == 'sh'
        :!time bash %
    endif
endfunc
