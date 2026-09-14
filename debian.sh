#! /bin/bash
#TODO IMPLEMENT DEBUG Mode
#DEBUG = true

tmux_session_name="update_debian"
tmux_session_timeout=10
echo $# 



#Check if OS = Debian
if [ ! -f /etc/debian_version ] || [ ! -f /bin/apt ] ; then
    echo "Please run this script on a Debian bases system"
    exit 1

fi

#Check if user is root
if [ "$EUID" -ne 0 ]; then
    echo "Insuficient rights please run this script as root"
    exit 1
fi

#Check dependencies
if ! command -v tmux &> /dev/null
then
    read -p "tmux is not installed, do you want to install it? (y/n) " answer
    if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
        apt install tmux -y
    else
        echo "tmux is required to run this script, please install it and try again"
        exit 1
    fi
fi

#Check for allrady running tmux session


function check_tmux_session {
    if tmux has-session -t $tmux_session_name 2>/dev/null; then
        echo "tmux session $tmux_session_name already exists"
        read -p "Attach to tmux session? (y/n) " answer
        if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
            tmux attach-session -t $tmux_session_name
        else
            echo "Exiting script"
            exit 1
        fi
    fi
}


check_tmux_session



#Update apt in tmux

tmux new-session -d -s "update_debian" "apt update && apt full-upgrade -y && apt autoclean -y && apt autoremove -y; read -t $tmux_session_timeout -n 'Press any key to exit...' && exit"
check_tmux_session

tmux kill-session -t $tmux_session_name

fun/hmm/update 
❯ cat update_debian.sh
#! /bin/bash
#TODO IMPLEMENT DEBUG Mode
#DEBUG = true

tmux_session_name="update_debian"
tmux_session_timeout=10
echo $# 



#Check if OS = Debian
if [ ! -f /etc/debian_version ] || [ ! -f /bin/apt ] ; then
    echo "Please run this script on a Debian bases system"
    exit 1

fi

#Check if user is root
if [ "$EUID" -ne 0 ]; then
    echo "Insuficient rights please run this script as root"
    exit 1
fi

#Check dependencies
if ! command -v tmux &> /dev/null
then
    read -p "tmux is not installed, do you want to install it? (y/n) " answer
    if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
        apt install tmux -y
    else
        echo "tmux is required to run this script, please install it and try again"
        exit 1
    fi
fi

#Check for allrady running tmux session


function check_tmux_session {
    if tmux has-session -t $tmux_session_name 2>/dev/null; then
        echo "tmux session $tmux_session_name already exists"
        read -p "Attach to tmux session? (y/n) " answer
        if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
            tmux attach-session -t $tmux_session_name
        else
            echo "Exiting script"
            exit 1
        fi
    fi
}


check_tmux_session



#Update apt in tmux

tmux new-session -d -s "update_debian" "apt update && apt full-upgrade -y && apt autoclean -y && apt autoremove -y; read -t $tmux_session_timeout -n 'Press any key to exit...' && exit"
check_tmux_session

tmux kill-session -t $tmux_session_name
