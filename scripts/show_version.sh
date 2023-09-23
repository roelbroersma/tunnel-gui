#!/usr/bin/bash

#THIS SCRIPT SHOWS THE CURRENT VERSIONS IN JSON

# USAGE FUNCTION
usage() {
    echo "Usage: show_upgrade -l [local|remote|all]

" 1>&2
}

# EXIT ERROR FUNCTION
exit_abnormal() {
    usage
    exit 1
}

# CHECK THE -u ARGUMENT, WHAT DO WE NEED TO DO?
while getopts ":l:" options; do
    case "${options}" in
        l)
            LOCATION=${OPTARG}
            ;;
        :)
        echo "ERROR: Argument -l can not be empty. It should contain one of the following options: local, remote or all."
        echo ""
        exit_abnormal
    esac
done

# ERROR HANDLING FOR -l ARGUMENT
if [ -z "$LOCATION" ]; then
    echo "ERROR: Use of argument -l is required!"
    echo ""
    exit_abnormal
fi
if [ "$LOCATION" != "local" ] && [ "$LOCATION" != "remote" ] && [ "$LOCATION" != "all" ] ; then
    echo "ERROR: Invalid option for -l specified. Argument -l should contain one of the following options: local, remote or all."
    echo ""
    exit_abnormal
fi


#INITIALISE AND EMPTY VARIABLES
json_output=""
AUTO_UPDATE=""
CURRENT_T1_VERSION=""
DIETPI_CORE_VERSION=""
DIETPI_SUB_VERSION=""
DIETPI_RC_VERSION=""

FUTURE_T1_VERSION=""
FUTURE_DIETPI_VERSION=""
FUTURE_DIETPI_CORE_VERSION=""
FUTURE_DIETPI_SUB_VERSION=""
FUTURE_DIETPI_RC_VERSION=""

SCRIPT_DIR=$(dirname -- "$0")

#START JSON OUTPUT
json_output="{";


if [ "$LOCATION" == "local" ] || [ "$LOCATION" == "all" ]; then

    #GET INFO ABOUT THE AUTO UPDATE FEATURE
    AUTO_UPDATE=$(/usr/bin/awk -F "=" '/CONFIG_CHECK_APT_UPDATES/ {print $2;exit}' /boot/dietpi.txt)
    if [ "$AUTO_UPDATE" == "2" ]; then
            AUTO_UPDATE="auto"
    else
            AUTO_UPDATE="manual"
    fi

    #GET CURRENT DIETPI VERSION
    DIETPI_CORE_VERSION=$(/usr/bin/awk -F "=" '/G_DIETPI_VERSION_CORE/ {print $2}' /boot/dietpi/.version)
    DIETPI_SUB_VERSION=$(/usr/bin/awk -F "=" '/G_DIETPI_VERSION_SUB/ {print $2}' /boot/dietpi/.version)
    DIETPI_RC_VERSION=$(/usr/bin/awk -F "=" '/G_DIETPI_VERSION_RC/ {print $2}' /boot/dietpi/.version)

    #GET CURRENT T1 VERSION
    CURRENT_T1_VERSION="$(cat $SCRIPT_DIR/../.version)"

    json_output="$json_output \"auto_update\" : \"$AUTO_UPDATE\"";
    json_output="$json_output, \"current_dietpi_version\" : \"$DIETPI_CORE_VERSION.$DIETPI_SUB_VERSION.$DIETPI_RC_VERSION\"";
    json_output="$json_output, \"current_t1_version\" : \"$CURRENT_T1_VERSION\"";
fi


if [ "$LOCATION" == "remote" ] || [ "$LOCATION" == "all" ]; then

    #GET FUTURE DIETPI VERSION (THE VERSION TO WHICH WE CAN UPGRADE)
    # Git repo to update from
    GITOWNER_TARGET=$(sed -n '/^[[:blank:]]*DEV_GITOWNER=/{s/^[^=]*=//p;q}' /boot/dietpi.txt)
    GITOWNER_TARGET=${GITOWNER_TARGET:-MichaIng}
    GITBRANCH_TARGET=$(sed -n '/^[[:blank:]]*DEV_GITBRANCH=/{s/^[^=]*=//p;q}' /boot/dietpi.txt)
    GITBRANCH_TARGET=${GITBRANCH_TARGET:-master}
    FUTURE_DIETPI_VERSION="$(curl --silent --fail --location --max-time 8 --connect-timeout 8 https://raw.githubusercontent.com/$GITOWNER_TARGET/DietPi/$GITBRANCH_TARGET/.update/version)"
    FUTURE_DIETPI_CORE_VERSION=$(echo "$FUTURE_DIETPI_VERSION" | /usr/bin/awk -F "=" '/G_REMOTE_VERSION_CORE/ {print $2;exit}')
    FUTURE_DIETPI_SUB_VERSION=$(echo "$FUTURE_DIETPI_VERSION"  | /usr/bin/awk -F "=" '/G_REMOTE_VERSION_SUB/ {print $2;exit}')
    FUTURE_DIETPI_RC_VERSION=$(echo "$FUTURE_DIETPI_VERSION"   | /usr/bin/awk -F "=" '/G_REMOTE_VERSION_RC/ {print $2;exit}')

    #IF WE DID NOT GET ANY VERSION NUMBER SHOW "Not available.." IN THE OUTPUT.
    if [ -z "$FUTURE_DIETPI_CORE_VERSION" ]; then
            FUTURE_DIETPI_CORE_VERSION="Not available"
    fi

    #GET FUTURE T1 VERSION (THE VERSION TO WHICH WE CAN UPGRADE)
    FUTURE_T1_VERSION="$(curl --silent --fail --location --max-time 8 --connect-timeout 8 https://raw.githubusercontent.com/roelbroersma/tunnel-gui/main/.version)"
    FUTURE_T1_VERSION=$(echo "$FUTURE_T1_VERSION" | /usr/bin/awk -F "=" '/T1_VERSION/ {print $2;exit}')

    #IF WE DID NOT GET ANY VERSION NUMBER SHOW "Not available.." IN THE OUTPUT.
    if [ -z "$FUTURE_T1_VERSION" ]; then
        FUTURE_T1_VERSION="Not available"
    fi

    if [ "$LOCATION" == "all" ]; then
        json_output="$json_output,"
    fi

    json_output="$json_output \"future_dietpi_version\" : \"$FUTURE_DIETPI_CORE_VERSION.$FUTURE_DIETPI_SUB_VERSION.$FUTURE_DIETPI_RC_VERSION\"";
    json_output="$json_output, \"future_t1_version\" : \"$FUTURE_T1_VERSION\"";
fi

#END JSON OUTPUT
json_output="$json_output }";

#RETURN JSON OUTPUT
echo $json_output
