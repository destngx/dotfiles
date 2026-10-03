" nmap j gj
nmap k gk
nmap 0 :g0<CR>
nmap [[ :pHead<CR>
nmap ]] :nHead<CR>
" vmap j gj
vmap k gk
nmap H ^
nmap L $
vmap L $
vmap H ^
noremap ; :
" Yank to system clipboard
set clipboard=unnamed
imap jj <Esc>
inoremap jj <Esc>
" Quickly remove search highlights
nmap <CR> :nohl<CR>
" Project Grep
exmap live_grep obcommand global-search:open 
nmap P :live_grep<CR>
" Go back and forward with Ctrl+O and Ctrl+I
" (make sure to remove default Obsidian shortcuts for these to work)
exmap back obcommand app:go-back
nmap gd :back<CR>
nmap <C-o> :back<CR>
exmap forward obcommand app:go-forward
nmap gf :forward<CR>
nmap <C-i> :forward<CR>
" surround text function
exmap surround_wiki surround [[ ]]
exmap surround_double_quotes surround " "
exmap surround_single_quotes surround ' '
exmap surround_backticks surround ` `
exmap surround_brackets surround ( )
exmap surround_square_brackets surround [ ]
exmap surround_curly_brackets surround { }

" NOTE: must use 'map' and not 'nmap'
map s[ :surround_wiki
nunmap s
vunmap s
map s" :surround_double_quotes<CR>
map s' :surround_single_quotes<CR>
map s` :surround_backticks<CR>
map sb :surround_brackets<CR>
map s( :surround_brackets<CR>
map s) :surround_brackets<CR>
map s[ :surround_square_brackets<CR>
map s[ :surround_square_brackets<CR>
map s{ :surround_curly_brackets<CR>
map s} :surround_curly_brackets<CR>
