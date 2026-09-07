#!/usr/bin/env bash
# remote-cli bash completion
# 用法: source completions/remote.bash

_remote_completions() {
    local cur prev commands
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    commands="connect status fix forward files desktop code runner config update uninstall setup"

    # 一级命令补全
    if [[ ${COMP_CWORD} -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
        return 0
    fi

    # 二级子命令补全
    local cmd="${COMP_WORDS[1]}"
    case "$cmd" in
        connect)
            COMPREPLY=( $(compgen -W "--mosh --ssh --dry-run" -- "$cur") )
            ;;
        status)
            COMPREPLY=( $(compgen -W "--json --deps" -- "$cur") )
            ;;
        fix)
            COMPREPLY=( $(compgen -W "--dry-run --auto --backup" -- "$cur") )
            ;;
        forward)
            COMPREPLY=( $(compgen -W "list kill" -- "$cur") )
            ;;
        files)
            COMPREPLY=( $(compgen -W "push pull list help" -- "$cur") )
            ;;
        runner)
            COMPREPLY=( $(compgen -W "status logs restart ssh" -- "$cur") )
            ;;
        config)
            COMPREPLY=( $(compgen -W "show" -- "$cur") )
            ;;
    esac

    return 0
}

complete -F _remote_completions remote
