#!/bin/sh
# for:    jenkins
# author: dengyu
# email:  yudengc@outlook.com

# ############ 维护tips ##############
# 目前默认所有项目分支发布流程:
#   `feature' -> develop -> staging -> master
# 新增项目操作：
#   full_name 分支给予对应赋值
#   /etc/ansible/hosts 按需配置分组
# 新增分支操作
#   1.BRANCH_GROUP_MAP 【添加版本分支和对应ansible分组映射】
#       /etc/ansible/hosts 【按需增加分组信息,复用分组则忽略】
#   2.主流程中加对应分支操作
# 脚本参数维护：
#   TEMP中添加参数, while循环中加分支, 参数校验...
# 脚本结构：
#   1.命令参数解析
#   2.参数校验
#   3.赋值
#   4.函数定义
#   5.主流程


HelpTips="
本脚本为webhook触发Jenkins调用的后台脚本.
根据分支版本的不同有不同的处理方法,
目前处理的有:
1.develop<-feature        
2.staging<-develop
3.master<-staging
expect arg: 
    --commit_branch 
    --base_branch
    --author
    --merged
    --full_name
"

TEMP=`getopt -o h --long --help,commit_branch:,base_branch:,author:,merged:,full_name: -- "$@"`

if [ $? != 0 ];then
    echo "Err, Terminating..." >&2
    echo "${HelpTips}"
    exit 1
fi
eval set -- "$TEMP"
while true;do
    case "$1" in
        --base_branch)
            #合并分支
            shift
            base_branch=$1
            ;;
        --commit_branch)
            #目前用来提交的分支
            shift
            commit_branch=$1
            ;;
        --merged)
            # true/false
            shift
            merged=$1
            ;;
        --author)
            shift
            author_name=$1
            ;;
        --full_name)
            shift
            FULL_NAME=$1
            ;;
        -h|--help)
            echo "${HelpTips}"
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "unknow arg!"
            exit 1
            ;;
    esac
shift
done

####### 参数校验 ######
if [ -z "${commit_branch}" -o -z "${base_branch}" -o \
-z "${author_name}" -o -z "${merged}" -o -z "${FULL_NAME}" ];then
    echo "${HelpTips}"
    exit 1
fi

######## 赋值 #######

SRC_PATH="/home/src"  #源码目录
mkdir -p ${SRC_PATH}
FLAG_PATH="${SRC_PATH}/flag/${FULL_NAME}/"
mkdir -p ${FLAG_PATH}
FLAG_TIMEOUT='600' #10分钟过期
THIS_FLAG="${FLAG_PATH}/${commit_branch}_to_${base_branch}.flag"

case "${FULL_NAME}" in
    "proqod/qlassroom")
        # repo分支名|ansible分组|ip(暂时用不到,以后再考虑删不删)
        BRANCH_GROUP_MAP="
        develop|develop|119.23.109.99
        staging|staging|13.229.207.78
        master|stable|
        "
        GIT_SSH_ADDRESS="git@github.com:proqod/qlassroom.git"
        REMOTE_CODE_PATH="/home/ubuntu/qlassroom/"
        REMOTE_CODE_USER="ubuntu"

        RESTART_SERVER_STR="
            cd ${REMOTE_CODE_PATH}/shell &&
            bash setup.sh --start
        "
        ;;
    "yudengc/leetcode_study")
        BRANCH_GROUP_MAP="
        develop|dengyu|47.106.196.155
        staging|dengyu|47.106.196.155
        master|dengyu|
        "
        GIT_SSH_ADDRESS="git@github.com:yudengc/leetcode_study.git"
        REMOTE_CODE_PATH="/home/dengyu/leetcode_study/"
        RESTART_SERVER_STR='echo "OK"'
        ;;
    "proqod/devops")
        BRANCH_GROUP_MAP="
        master|ctrlcenter|
        "
        GIT_SSH_ADDRESS="git@github.com:proqod/devops.git"
        REMOTE_CODE_PATH="/home/devops/"
        REMOTE_CODE_USER="ubuntu"
        RESTART_SERVER_STR='echo "OK"'
        ;;
esac


######## 函数定义 ########
Detect_code(){
    #TODO

    # 检查是否可以merge代码:
    # 1.代码非法
    # 2.当前处于锁定状态
    echo "Check_code:pass"
}

AutoTest(){
    #TODO

    #调用sonquarbe测试
    echo "AutoTest:pass"
}

StepExec(){
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

Check_Flag(){
    if [ -f "${THIS_FLAG}" ];then
        # a=`date +'%F %X'`
        laststatus=`cat "${THIS_FLAG}"|tail -n1|awk -F'|' '{print $1}'`
        lastTime=`cat "${THIS_FLAG}"|tail -n1|awk -F'|' '{print $2}'`
        if [ -z "${lastTime}" ];then
            rm -f ${THIS_FLAG}
            return 0
        fi
        nowTime_sec=`date +%s`
        lastTime_sec=`date -d "${lastTime}" +%s`
        bTimeOut=`echo "${nowTime_sec}-${lastTime_sec}-${FLAG_TIMEOUT}>=0"|bc`
        if [ "${bTimeOut}" = "1" ];then
            echo "timeout.."
            rm -f "${THIS_FLAG}"
        else
            echo "can't build!! now in ${laststatus}, started in :${lastTime}" >&2
            return 1
        fi
    elif [ -e "${THIS_FLAG}" ];then
        rm -rf "${THIS_FLAG}"
        return 0
    else
        return 0
    fi
}

Handle_Flag(){
    local action="$1"
    local status="$2"
    case "${action}" in
        "update")
            echo "${status}|`date +'%F %X'`" >>${THIS_FLAG}
            ;;
        "delete")
            rm -f "${THIS_FLAG}"
            ;;
    esac
}

CheckOutCode(){
    # 不想把私钥放的到处都是, 这里git pull到本地然后传过去
    local branch=$1
    local codepath
    if [ -z "${branch}" ];then
        echo "input branch!"
        return 1
    fi

    echo "正在更新本地代码"
    Handle_Flag "update" "CheckOutCode"
    codepath="${SRC_PATH}/${FULL_NAME}/${branch}/"
    if [ -d "${codepath}" ];then
        remotebranch=`cd ${codepath} && git symbolic-ref --short -q HEAD`
        remoterepo=`cd ${codepath} && git remote -v|head -n1|awk '{print $2}'`
        if [ "${remoterepo}" != "${GIT_SSH_ADDRESS}" -o "${remotebranch}" != "${branch}" ];then
            rm -rf "${codepath}"
            git clone ${GIT_SSH_ADDRESS} -b ${branch} ${codepath}
        else
            cd ${codepath} && git clean -df && git pull
        fi
    elif [ -e "${codepath}" ];then
        rm -rf "${codepath}"
        git clone ${GIT_SSH_ADDRESS} -b ${branch} ${codepath}
    else
        git clone ${GIT_SSH_ADDRESS} -b ${branch} ${codepath}
    fi

    return $?
}


RsyncCode(){
    local Group=$1
    local branch=$2
    local codepath
    local rc
    echo "正在同步代码"
    Handle_Flag "update" "RsyncCode"
    codepath="${SRC_PATH}/${FULL_NAME}/${branch}"
    ansible $Group -m shell -a "mkdir -p ${REMOTE_CODE_PATH}"
    ansible ${Group} -m synchronize -a "src=${codepath}/ dest=${REMOTE_CODE_PATH}/ rsync_opts='--exclude=.git'"
    rc=$?
    if [ "$rc" -eq 0 ];then
        if [ ! -z "${REMOTE_CODE_USER}" ];then
            ansible $Group -m shell -a "chown -R ${REMOTE_CODE_USER}:${REMOTE_CODE_GROUP:-${REMOTE_CODE_USER}} ${REMOTE_CODE_PATH}"
            return $?
        fi
    fi
    return $rc
}

RestartServer(){
    local Group=$1
    if [ "${Group}" = "" ];then
        echo "input ansible group"
        return 1
    fi
    echo "正在重启${Group}"
    Handle_Flag "update" "RestartServer"
    ansible ${Group} -m shell -a "${RESTART_SERVER_STR}"
    return $?
}

Rebuild_server(){
    #1.本地检出
    #2.同步代码
    #3.重启服务器
    local branch=$1
    if [ "${branch}" = "" ];then
        echo "未指定分支."
        return 1
    fi
    local Group
    Group=`echo "${BRANCH_GROUP_MAP}"|grep -wE "^[\t ]*${branch}"|\
    awk -F'|' '{print $2}'`
    if [ "${Group}" = "" ];then
        echo "该分支未指定组." >&2
        return 1
    fi

    shift
    local customStepStr
    customStepStr="$*"
    if [ "${customStepStr}" != "" ];then
        stepstr="${customStepStr}"
    else
        stepstr="
        CheckOutCode ${branch}
        RsyncCode ${Group} ${branch}
        RestartServer ${Group}
        "
    fi

    Check_Flag ${branch}
    if [ $? -ne 0 ];then
        return $?
    fi

    local rc
    Handle_Flag update StartBuild
    StepExec "${stepstr}"
    rc=$?
    Handle_Flag delete
    return $rc
}

Start_script(){

    if [ "${merged}" != "true" ];then
        Detect_code
        exit $?
    fi

    WarnMsg="${FULL_NAME}合并${base_branch}<-${commit_branch}没有设置对应操作,请确认:
            1.是否Jenkins分支捕获设置有误
            2.是否$0中没有设置对应该有分支的处理逻辑
            3.未经过审核的恶意提交操作！(author:${author_name})"

    case "${base_branch}<-${commit_branch}" in
        "develop<-"*)
            # feature合并到develop中可以随意
            customStepStr=""
            ;;
        "staging<-develop")
            customStepStr=""
            ;;
        "master<-staging")
            customStepStr=""
            ;;
        "master<-develop")
            if [ "${FULL_NAME}" = "proqod/devops" ];then
                customStepStr=""
            else
                echo "${WarnMsg}" >&2
                exit 1
            fi
            ;;
        *)
            echo "${WarnMsg}" >&2
            exit 1
            ;;
    esac

    echo "${FULL_NAME}:合并${base_branch}<-${commit_branch}"

    Rebuild_server "${base_branch}" "${customStepStr}" 
    exit $?
}


# __main__
Start_script

