#!/bin/sh
# author: dengyu
# 2019.8.9
# 操作平台控制的入口脚本

TEMP=`getopt -o h --long a-long,b-long:,c-long::, --help -- "$@"`

if [ $? != 0 ] ; then 
    echo "sth error..." >&2 
    exit 1 
fi

eval set -- "$TEMP"

parm=""
while true ; do
    case "$1" in
        -h|--help)
            ;;
        --publish)
            codetype=$2
            shift 1;
        --updateme)
            ssh pugu@
            ;;
        --) shift ; break ;;
        *) echo "unsupport parm!" ; exit 1 ;;
    esac
shift
done

echo "Remaining arguments:"
for arg do
   echo '--> '"\`$arg'" ;
done

# 变量位置暂定这里
PUBDEFINES=/home/pugu/pubdefines.sh
if [ -f "${PUBDEFINES}" ];then
    . ${PUBDEFINES}
fi

while read line;do
    exectype=`echo $line|awk '{print $1}'`
    arg=`echo $line|awk '{for(i=2;i<=NF;i++){printf($i" ")}}'`
    case "${exectype}" in

        "publish")
            #代码发布,由jenkins触发执行到生产服上
                ssh root@${dest} "publish@${arg:-stable}"
                ;;

        "updateme")
            #更新执行脚本的通道
                # 默认all全部更新
                # 只更新某一个脚本: 打脚本路径
                ssh root@${dest} "updateme@${arg:-all}"
                ;;
            "exec")
            #服务器上执行某个脚本
            #只允许执行某个目录下的脚本: shellpublic/example.sh-> exec@example
                ssh root@${dest} "exec@${arg:-example}"
                ;;
            *)
                echo "unsupport type:${exectype}"
                exit 1
                ;;
    esac


done << EOF
${parm}
EOF
