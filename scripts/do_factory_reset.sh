#!/usr/bin/bash
#THIS SCRIPT WILL FACTORY RESET THE T1 SETTINGS (NO BRIDGE, DHCP AND DEFAULT PASSWORD) AND REBOOT

# USAGE FUNCTION
usage() {
    echo "Usage: do_factory_reset -f [now]

" 1>&2
}

# EXIT ERROR FUNCTION
exit_abnormal() {
    usage
    exit 1
}

# CHECK THE -u ARGUMENT, WHAT DO WE NEED TO DO?
while getopts ":f:" options; do
    case "${options}" in
        f)
            FORCE=${OPTARG}
            ;;
        :)
        echo "ERROR: Argument -f can not be empty. It can only contain the value: now."
        echo ""
        exit_abnormal
    esac
done

# ERROR HANDLING FOR -f ARGUMENT
if [ -z "$FORCE" ]; then
    echo "ERROR: Use of argument -f is required!"
    echo ""
    exit_abnormal
fi
if [ "$FORCE" != "now" ] ; then
    echo "ERROR: Invalid option for -f specified. Argument -f can only contain the value: now."
    echo ""
    exit_abnormal
fi


# INITIALIZE VARIABLES AND MAKE SURE THEY ARE EMTPY
SCRIPT_DIR=$(dirname -- "$0")


#DO FACTORY RESET
if [ "$FORCE" == "now" ]; then

    echo "Set mode to NON-bridge"
    $SCRIPT_DIR/change_bridge.sh -b off

    echo "Set the IP address to DHCP"
    $SCRIPT_DIR/change_ip.sh -t dhcp

    echo "Reset password"
    #TODO: Reset Password

    echo "Reset VPN settings"
    #TODO: Reset VPN settings

    echo "Reboot now"
    $SCRIPT_DIR/do_reboot.sh
fi
