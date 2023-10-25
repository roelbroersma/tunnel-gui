#!/usr/bin/bash
#THIS SCRIPT IS WILL UPDATE THE DIETPI IMAGE OR CHANGE THE UPDATE MODE TO AUTO OR MANUAL

# USAGE FUNCTION
usage() {
    echo "Usage: dietpi_upgrade -u [manual|auto|now]

" 1>&2
}

# EXIT ERROR FUNCTION
exit_abnormal() {
    usage
    exit 1
}

# DIETPI CHECK
if [ ! -f /boot/dietpi/.version ]; then
	echo "ERROR: This script can only run on a DietPi"
	exit_abnormal
fi

# CHECK THE -u ARGUMENT, WHAT DO WE NEED TO DO?
while getopts ":u:" options; do
    case "${options}" in
        u)
            UPDATE=${OPTARG}
            ;;
        :)
        echo "ERROR: Argument -u can not be empty. It should contain one of the following options: manual, auto or now."
        echo ""
        exit_abnormal
    esac
done

# ERROR HANDLING FOR -u ARGUMENT
if [ -z "$UPDATE" ]; then
    echo "ERROR: Use of argument -u is required!"
    echo ""
    exit_abnormal
fi
if [ "$UPDATE" != "manual" ] && [ "$UPDATE" != "auto" ] && [ "$UPDATE" != "now" ] ; then
    echo "ERROR: Invalid option for -u specified. Argument -u should contain one of the following options: manual, auto or now."
    echo ""
    exit_abnormal
fi



# INITIALIZE VARIABLES AND MAKE SURE THEY ARE EMTPY
SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")/"
LOG_DIR="${SCRIPT_DIR}../logs/"
#JUST IN CASE THE UPDATE DID HANG IN A PREVIOUS SESSION AND G_INTERACTIVE WAS NOT SET TO 1 AGAIN
export G_INTERACTIVE=1


#SET UPDATE TO MANUAL
if [ "$UPDATE" == "manual" ]; then

    echo "Changing DietPi Update mode to Manual"
    /usr/bin/sed -i 's/^CONFIG_CHECK_DIETPI_UPDATES\=.*/CONFIG_CHECK_DIETPI_UPDATES\=0/' /boot/dietpi.txt

#SET UPDATE TO AUTO
elif [ "$UPDATE" == "auto" ]; then

    echo "Changing DietPi Update mode to Auto (once every day, check via dietpi-cron when exactly)"
    /usr/bin/sed -i 's/^CONFIG_CHECK_DIETPI_UPDATES\=.*/CONFIG_CHECK_DIETPI_UPDATES\=1/' /boot/dietpi.txt

#UPDATE NOW
elif [ "$UPDATE" == "now" ]; then
    mkdir -p ${LOG_DIR}
    echo "Update DietPi Now (non-interactive)"
    export G_INTERACTIVE=0
    /boot/dietpi/dietpi-update 1 > ${LOG_DIR}update.log 2>&1
    export G_INTERACTIVE=1
    #CLEAR LOG AND WRITE TO FILE
    echo "<h4><b>UPDATE FINISHED, PLEASE REBOOT DEVICE!</b></h4>" > ${LOG_DIR}update.log
fi
