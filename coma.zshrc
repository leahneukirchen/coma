# Ideas how to use coma with zsh.
# -*- shell-script -*-

# Needed for scan line width.
export LINES COLUMNS

coma() {
    ruby -I/opt/ruby1.8/lib/ruby/gems/1.8/gems/sqlite3-1.3.3/lib/ \
         -I~/prj/coma ~/prj/coma/coma "$@"
}
alias ,="coma"
alias s="coma show"
alias n="coma next"
alias p="coma prev"

_coma_n() {
  zle && zle -I                 # force redrawing of prompt
  clear
  coma next
}

zle -N _coma_n
bindkey "^F" _coma_n


# Coma completion.

_coma(){  
    local cmd=$words[2]

    if [[ -z "$cmd" ]]; then
        _arguments : ":coma commands:_coma_commands"
        return
    fi

    (( $+functions[_coma_cmd_${cmd}] )) && _coma_cmd_${cmd}
}

_coma_commands() {
  cmd_list=(att folders fwd inc mail mark next prev read repl scan seqs show usage)
  _describe -t commands 'coma command' cmd_list
}

_coma_cmd_att() {
    _arguments : '-f' '*:attachments:_coma_attachment'
}

_coma_cmd_folders(){
    _arguments : '-list' '-u' '-s' '-inc' '*:folder:_coma_folder'
}

_coma_cmd_fwd(){
    _arguments : '-subject:' '-from:' \
        '*-to:' '*-fwd:' \
        '*-cc:' '*-bcc:' \
        '-noreplyto' '-noreplyall' '-noquote' '-keep' \
        '*-att:attachment:_files' \
        '-repl:_coma_ref' '-fwd:_coma_ref' \
        '*:reference:_coma_ref'
}

_coma_cmd_inc(){
    _arguments : '-q[quiet]' \
        '*:folders:_coma_folder_or_dir'
}

_coma_cmd_mail(){
    _arguments : '-subject:' '-from:' \
        '*-to:mail addesses:_coma_aliases' '*-fwd:mail addesses:_coma_aliases' \
        '*-cc:mail addesses:_coma_aliases' '*-bcc:mail addesses:_coma_aliases' \
        '*-att:attachment:_files' \
        '-repl:_coma_ref' '-fwd:_coma_ref' \
        '-noreplyto' '-noreplyall' '-noquote' '-keep' \
        '*:mail addesses:_coma_aliases'
}

_coma_cmd_mark(){
    _arguments : -{un,}flagged -{un,}seen -{un,}replied \
        '*:reference:_coma_ref'
}

_coma_cmd_next(){}
_coma_cmd_prev(){}

_coma_cmd_read(){
    _arguments : -reverse -last: -limit: -cached -inc -save: -q -fmt: -width: \
        -add:_coma_seq -delete:_coma_seq \
        '*:folder:_coma_folder'
}

_coma_cmd_repl(){
    _arguments : '-subject:' '-from:' \
        '*-to:mail addesses:_coma_aliases' '*-fwd:mail addesses:_coma_aliases' \
        '*-cc:mail addesses:_coma_aliases' '*-bcc:mail addesses:_coma_aliases' \
        '*-att:attachment:_files' \
        '-repl:_coma_ref' '-fwd:_coma_ref' \
        '-noreplyto' '-noreplyall' '-noquote' '-keep' \
        '*:reference:_coma_ref'
}

_coma_cmd_scan(){
    _arguments : -reverse -last: -limit: -cached -inc -save: -q -fmt: -width: \
        -add:_coma_seq -delete:_coma_seq \
        '*:reference:_coma_ref_or_folder_or_dir'
}

_coma_cmd_show(){
    _arguments : -nopager -keep -path -raw -idx -select -wide \
        '*:reference:_coma_ref'
}

_coma_cmd_seqs(){
    _arguments : -clear -list
}

_coma_aliases(){
    compadd $(< ~/.config/coma/mail-addresses)
}

_coma_attachment(){
    expl=(${(r.42.f)"$(coma att)"})
    compadd -d expl $(coma att | cut -d" " -f1)
}

_coma_ref(){
    expl=(${(f)"$(coma scan)"})
    compadd - thread next prev last first
    compadd -d expl $(coma show all -idx)
}

_coma_seq(){
    compadd - $(coma seqs -list)
}

_coma_folder(){
    compadd - $(coma folders -list)
}

_coma_ref_or_folder_or_dir(){
    _alternative 'folders:folder:_coma_folder' \
        'directories:directory:_directories' \
        'references:reference:_coma_ref'
}

_coma_folder_or_dir(){
    _alternative 'folders:folder:_coma_folder' \
        'directories:directory:_directories'
}

compdef _coma coma
