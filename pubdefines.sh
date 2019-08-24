#!/bin/sh
# for:    公共定义函数,变量
# author: dengyu
# email:  yudengc@outlook.com

# tips:
# 为防止参数污染,请遵守:
#   1.函数内变量用local声明
#   2.全局变量用readonly声明


ErrEcho(){
    local shellver
    shellver=`cat /proc/$$/stat|grep -oE "bash|dash"`
    if [ "${shellver}" = "bash" ];then
        echo -e "\033[31m$*\033[0m" >&2
    else
        echo "\033[31m$*\033[0m" >&2
    fi
}

StepExec(){
    #流程函数
    
    local StepStr
    local rc
    local step
    StepStr="$1"
    while read step;do

        echo "${step}"|grep -E '^[\t ]*$' >/dev/null
        if [ $? -eq 0 ];then
            continue
        fi
        echo "Doing ${step}"
        ${step} </dev/null
        rc=$?
        if [ $rc -ne 0 ];then
            ErrEcho "err in doing: ${step} | rc=${rc}"
            return $rc
        fi
    done << EOF
${StepStr}
EOF
}


SendMsg(){
    
}
