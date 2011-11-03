set nocompatible

call pathogen#infect()
call pathogen#helptags()
syntax enable
filetype plugin indent on

set autoindent

set showcmd
set showmode

set list&
set number
set ruler

set hidden

set incsearch
set hlsearch

set title
set nowrap

set wildmenu
set wildmode=list:longest

set ignorecase
set smartcase

set directory=$HOME/.vim/tmp//,.
set laststatus=2

set tabstop=2:
set shiftwidth=2
set expandtab
set smarttab
set autoindent
set smartindent

set formatoptions=tq
set wrapmargin=4

"autocmd BufEnter * silent! lcd %:p:h

colorscheme zenburn

au BufNewFile,BufReadPost *.coffee setl shiftwidth=2 expandtab
