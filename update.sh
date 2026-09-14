#! /bin/bash

#  Variables

tmux_session_name="update_debian"
tmux_session_timeout=10
ask_attach_tmux_timeout=5





#in development
payload="apt update && apt full-upgrade -y && apt autoclean -y && apt autoremove -y"
$tmux_session_timeout="30"
run_tmux_detached=true
ntfy_link="https://ntfy.sh/your_topic"



#TODO support other package managers
#TODO systlink to script
#TODO script over gh | bash
#TODO configure auto updates



#TODO argument handeling
#-dry


#-debug
#DEBUG = true
#TODO IMPLEMENT DEBUG Mode
#Define awnser into run_tmux_detached invert cause where 

#-logfile



# Debug statement for testing how to implement argument handeling
if [ debug == true ]; then
    echo $#
fi


#Check awnser from user
function check_awnser {
    #Convert awnser to lower case
    awnser=${awnser,,}
    if [[ "$awnser" == "y" || "$awnser" == "yes" || "$awnser" == "yeah" ]]; then
        return true
    elif [[ "$awnser" == "n" || "$awnser" == "no" || "$awnser" == "nah" || "$awnser" == "" ]]; then
        return false
    else
        read -p "Invalid awnser please enter y/n: " awnser
        check_awnser
    fi
}

#Check if OS is Debian
if [ ! -f /etc/debian_version ] || [ ! -f /bin/apt ] ; then
    echo "Please run this script on a Debian bases system"
    exit
fi

#Check if user is root
if [ "$EUID" -ne 0 ]; then
    echo "please run this script as root or with sudo"
    exit
fi

#Create new tmux session and run payload
tmux new-session -d -s "$tmux_session_name" "$payload && exit"

#Check dependencies
if command -v tmux &> /dev/null;
then
    echo "tmux is required to run this script, please install it and try again"
    exit
fi
    check_awnser
    if [ $answer == "true"]; then
        run_tmux_detached=false
    else
        run_tmux_detached=true
    fi


#Fuction for checking for allrady running tmux sessions by name
function check_tmux_session {
    if tmux has-session -t $tmux_session_name 2>/dev/null; then
        return true
    else
        return false
    fi
}

if [ check_tmux_session = true ]; then
    echo "tmux session $tmux_session_name already exists"
    read -p "Attach to tmux session? (y/n) " answer
    check_awnser
    if [[ "$answer" == "true" ]]; then
        tmux attach-session -t $tmux_session_name
        exit
    else
        echo "Exiting script"
        exit
    fi
fi
#Ask whether to attach to tmux session skip when allrady set
if [ run_tmux_detached == "" ]; then
    read -t $ask_attach_tmux_timeout -n 'Attach to tmux session? (y/n) ' answer
    check_awnser
    if [ "$answer" == true ]; then
        run_tmux_detached=false
    else
        run_tmux_detached=true
    fi
fi



if [ run_tmux_detached == false ]; then
    show_output =" && read -t $tmux_session_timeout -n 'Press any key to continue...' answer" && ""
fi

#Create tmux session
tmux new-session -d -s "$tmux_session_name" "$payload $show_outputo && exit"

#Attach to tmux session
check_awnser
if awnser == "true"; then
    if [ check_tmux_session = true ]; then
            tmux attach-session -t $tmux_session_name
    else
        echo "fatal error: tmux session $tmux_session_name does not exist"
        exit
    fi
fi
