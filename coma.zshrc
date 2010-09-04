# Ideas how to use coma with zsh.
# -*- shell-script -*-

# Needed for scan line width.
export LINES COLUMNS

coma() {
    # This is a lot faster than rubygems.
    ruby \
        -I${${(n)$(echo /opt/ruby1.8/lib/ruby/gems/1.8/gems/json-*/lib)}[-1]} \
        -I${${(n)$(echo /opt/ruby1.8/lib/ruby/gems/1.8/gems/tmail-*/lib)}[-1]} \
        ~/prj/coma/coma "$@"
}
alias ,="coma"
alias s="coma show"
alias n="coma next"
alias p="coma prev"

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
  cmd_list=(folders fwd inc mail next prev read repl scan show)
  _describe -t commands 'coma command' cmd_list
}

_coma_cmd_folders(){
    _arguments : '-list' '*:folder:_coma_folder'
}

_coma_cmd_fwd(){
    _arguments : '-subject:' \
        '*-cc:' '*-bcc:' \
        '-from:' \
        '*-att:attachment:_files' \
        '*:reference:_coma_ref'
}

_coma_cmd_inc(){
    _arguments : '-q[quiet]' \
        '*:folders:_coma_folder_or_dir'
}

_coma_cmd_mail(){
    _arguments : '-subject:' \
        '*-cc:' '*-bcc:' \
        '-from:' \
        '*-att:attachment:_files' \
        '-repl:_coma_ref' '-fwd:_coma_ref' \
        '*:mail addesses:_coma_aliases'
}

_coma_cmd_next(){}
_coma_cmd_prev(){}

_coma_cmd_read(){
    _arguments : -seq -q \
        -{,un}flagged -{,un}seen -{,un}replied \
        -subject -date -from -thread -all \
        -last: -reverse \
        '*:folder:_coma_folder'
}

_coma_cmd_repl(){
   _arguments : '-subject:' \
        '*-cc:' '*-bcc:' \
        '-from:' \
        '*-att:attachment:_files' \
        '-noreplyto' '-noreplyall'
        '*:reference:_coma_ref'
}

_coma_cmd_scan(){
    _arguments : -seq -q \
        -{,un}flagged -{,un}seen -{,un}replied \
        -subject -date -from -thread -all \
        -width: -last: -reverse \
        '*:referece:_coma_ref'
}

_coma_cmd_show(){
    _arguments : -nopager -path -raw -idx -select \
        '*:referece:_coma_ref'
}

_coma_aliases(){
    compadd $(< ~/.config/coma/mail-addresses)
}

_coma_ref(){
    expl=(${(f)"$(coma scan)"})
    compadd - thread next prev last first
    compadd -d expl $(coma show all -idx)
}

_coma_folder(){
    compadd - $(coma folders -list)
}

_coma_folder_or_dir(){
    _alternative 'folders:folder:_coma_folder' \
        'directories:directory:_directories'
}

compdef _coma coma
