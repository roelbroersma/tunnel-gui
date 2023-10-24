#!/usr/bin/bash
#THIS SCRIPT IS WILL UPDATE THE DIETPI IMAGE AND THE TUNNEL GUI OR CHANGE THE UPDATE MODE TO AUTO OR MANUAL

# USAGE FUNCTION
usage() {
    echo "Usage: do_upgrade -u [manual|auto|now]

" 1>&2
}

# EXIT ERROR FUNCTION
exit_abnormal() {
    usage
    exit 1
}

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
    /usr/bin/sed -i 's/^CONFIG_CHECK_APT_UPDATES\=.*/CONFIG_CHECK_APT_UPDATES\=1/' /boot/dietpi.txt
    /usr/bin/sed -i 's/^CONFIG_CHECK_DIETPI_UPDATES\=.*/CONFIG_CHECK_DIETPI_UPDATES\=0/' /boot/dietpi.txt

    echo "Changing Tunnel GUI Update mode to Manual"
    #TODO: REMOVE CRON JOB TO GET TUNNEL GUI FILES FROM GITHUB

#SET UPDATE TO AUTO
elif [ "$UPDATE" == "auto" ]; then

    echo "Changing DietPi Update mode to Auto (once every day, check via dietpi-cron when exactly)"
    /usr/bin/sed -i 's/^CONFIG_CHECK_APT_UPDATES\=.*/CONFIG_CHECK_APT_UPDATES\=2/' /boot/dietpi.txt
    /usr/bin/sed -i 's/^CONFIG_CHECK_DIETPI_UPDATES\=.*/CONFIG_CHECK_DIETPI_UPDATES\=1/' /boot/dietpi.txt

    echo "Changing Tunnel GUI Update mode to Auto"
    #TODO: ADD CRON JOB TO GET TUNNEL GUI FILES FROM GITHUB

#UPDATE NOW
elif [ "$UPDATE" == "now" ]; then
    mkdir -p ${LOG_DIR}
    if [ -f /boot/dietpi/.version ]; then
	echo "Update DietPi Now (non-interactive)"
	export G_INTERACTIVE=0
	/boot/dietpi/dietpi-update 1 > ${LOG_DIR}update.log 2>&1
	export G_INTERACTIVE=1
	apt-get update -y && apt-get full-upgrade -y > ${LOG_DIR}update.log 2>&1
    elif command -v apt-get > /dev/null; then
	echo "Update OS with APT (non-interactive)"
	apt-get update -y && apt-get full-upgrade -y > ${LOG_DIR}update.log 2>&1
    elif command -v yum > /dev/null; then
	echo "Update OS with YUM (non-interactive)"
        yum -y update > ${LOG_DIR}update.log 2>&1
    elif command -v dnf > /dev/null; then
	echo "Update OS with DNF (non-interactive)"
	dnf -y update > ${LOG_DIR}update.log 2>&1
    fi
    #CLEAR LOG AND WRITE TO FILE
    echo "<h4><b>UPDATE FINISHED, PLEASE REBOOT DEVICE!</b></h4>" > ${LOG_DIR}update.log
fi
