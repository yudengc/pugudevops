#!/bin/sh

Err(){
    echo "\033[31m$*\033[0m" >&2
}

readonly CTRL_KEY=/home/pugu/.pugu_cmd.key
if [ ! -f ${CTRL_KEY} ];then
    Err "key not found!" 
fi

alias ssh="ssh -i ${CTRL_KEY}"
