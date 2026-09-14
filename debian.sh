#! /bin/bash

#Disclaimer:

# This whole thing is pretty much just a script for udpating my server stuff especialy inside containericed envierments like proxmox lxes or systems running inside docker or podman its fully writen by me with a little help of stack overflow and t#hat github thing what im saying is that i wouldnt except it to work reliably and uhm yeah as you might guess from the code its not really on any standard to if any random stranger is reading that thing please man how the fuck do i stop that github thing in vim and is there a way to set that on a keybind or sth? 
#


#  Variables

tmux_session_name="update_debian"
tmux_session_timeout=10
ask_attach_tmux_timeout=5





#in development
payload="update_debian" "apt update && apt full-upgrade -y && apt autoclean -y && apt autoremove -y; read -t $tmux_session_timeout -n 'Press any key to exit'"
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



#Check awnser from user
function check_awnser {
    "${awnser,,}"=awnser
    if [ "$awnser    else" == "y" || "$awnser" == "yes" ]; then
        return true
    elif [ "$awnser" == "n" || "$awnser" == "no" || "$awnser" == "nah" || "$awnser" == "" ]; then
        return false
    else
        read -p "Invalid awnser please enter y/n: " awnser
        check_awnser
fi


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

#TODO check if tmux version is over 4 cause lower case thing



if ! command -v tmux &> /dev/null
then
    echo "tmux is required to run this script, please install it and try again"
    exit
fi
    if [ "$answer" == "y" || "$answer" == "Y"]; then
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

#Use check_tmux_session to chec
if [ check_tmux_session = true ]; then
    echo "tmux session $tmux_session_name already exists"
    read -p "Attach to tmux session? (y/n) " answer
    check_awnser
    if [[ "$answer" == "true" ]]; then
        tmux attach-session -t $tmux_session_name
        #TODO check if its needet to exit the script from here to dont let it create another tmux session after atttaching to the existing one
    else
        echo "Exiting script"
        exit
    fi

#Ask whether to attach to tmux session skip when allrady set
if [ run_tmux_detached != ]; then
    read -t $ask_attach_tmux_timeout -n 'Attach to tmux session? (y/n) ' answer
fi



check_awnser
if [ "$answer" == true ]; then
    run_tmux_detached=false
else
    run_tmux_detached=true
fi


#Create tmux session
tmux new-session -d -s "$tmux_session_name" "$payload && exit"

#Attach to tmux session
check awnser
if awnser == "true"; then
    if [ check_tmux_session = true ]; then
            tmux attach-session -t $tmux_session_name
    else
        echo "fatal error: tmux session $tmux_session_name does not exist"
        exit
    fi
fi




#Cleanup tmux sessions after timeout (Still in testing)
#sleep $tmux_session_timeout + 30
#if [ check_tmux_session = true ]; then
#    tmux kill-session -t $tmux_session_name
#fi
