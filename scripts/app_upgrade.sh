#!/usr/bin/bash
#THIS SCRIPT IS WILL UPDATE THE TUNNEL1

UPDATE_URL="https://github.com/roelbroersma/tunnel-gui/archive/refs/heads/main.zip"
FILENAME="main.zip"
DIRECTORY="tunnel-gui-main"

# USAGE FUNCTION
usage() {
    echo "Usage: ap_upgrade -u now

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
        echo "ERROR: Argument -u can not be empty. It should contain the following option: now."
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
    echo "ERROR: Invalid option for -u specified. Argument -u should contain ithe following option: now."
    echo ""
    exit_abnormal
fi



# INITIALIZE VARIABLES AND MAKE SURE THEY ARE EMTPY
SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")/"
BASE_DIR="${SCRIPT_DIR}../"
LOG_DIR="${BASE_DIR}logs/"

#UPDATE NOW
if [ "$UPDATE" == "now" ]; then

    #CREATE LOG DIR IF IT DOESNT EXIST
    mkdir -p ${LOG_DIR}

    #CREATE TEMP DIR IF IT DOESNT EXIST
    mkdir -p ${BASE_DIR}temp

    #DELETE ANY FILES IN THE TEMP FOLDER
    rm -rf ${BASE_DIR}temp/*

    echo "Downloading latest vesion..." > ${LOG_DIR}update.log
    curl -L -o ${BASE_DIR}temp/${FILENAME} ${UPDATE_URL} >> ${LOG_DIR}update.log 2>&1

    echo "Unzipping files to temporary folder..." >> ${LOG_DIR}update.log
    unzip -q -o ${BASE_DIR}temp/${FILENAME} -d ${BASE_DIR}temp >> ${LOG_DIR}update.log

    echo "Coying files from temporary folder to application path..." >> ${LOG_DIR}update.log 2>&1
    shopt -s dotglob #ADD OPTION TO ALLOW WILDCARD MATCHING OF HIDDEN FILES
    cd ${BASE_DIR}temp/${DIRECTORY}
    cp -R -f ./* ${BASE_DIR} >> ${LOG_DIR}update.log
    shopt -u dotglob #REMOVE OPTION TO ALLOW WILDCARD MATCHING OF HIDDEN FILES

    echo "Running after update scripts..." >> ${LOG_DIR}update.log
    if [ -f ${BASE_DIR}upgrade.txt ]; then
	cat ${BASE_DIR}upgrade.txt | bash  >> ${LOG_DIR}update.log 2>&1
    fi

    echo "Cleaning up files..." >> ${LOG_DIR}update.log
    rm -rf ${SCRIPT_DIR}../temp >> ${LOG_DIR}update.log
    #CLEAR LOG AND WRITE TO FILE
    echo "<h4><b>UPDATE FINISHED, PLEASE REBOOT DEVICE!</b></h4>" > ${LOG_DIR}update.log
fi
