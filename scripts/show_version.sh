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
CORE_OS=""
CORE_VERSION_FULL=""
CORE_VERSION=""
CORE_SUB_VERSION=""
CORE_RC_VERSION=""
CORE_AUTO_UPDATE=""
APP_VERSION=""
OPENVPN_VERSION=""

SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")/"

#START JSON OUTPUT
json_output="{";


# GET CURRENT APP VERSION
get_app_version() {
	if [[ -f $SCRIPT_DIR/../.version ]]; then
		source $SCRIPT_DIR/../.version
		echo "$APP_VERSION"
	else
		echo ""
	fi
}

# GET LATEST APP VERSION
get_app_latest_version() {
    #GET FUTURE APP VERSION (THE VERSION TO WHICH WE CAN UPGRADE)
    FUTURE_APP_VERSION="$(curl --silent --fail --location --max-time 8 --connect-timeout 8 https://raw.githubusercontent.com/roelbroersma/tunnel-gui/main/.version)"
    echo "$FUTURE_APP_VERSION" | /usr/bin/awk -F "=" '/APP_VERSION/ {print $2;exit}'
}



# GET OPENVPN VERSION
get_openvpn_version() {
    local openvpn_path=$(which openvpn)
    if [[ -z "$openvpn_path" ]]; then
        echo ""
    else
        local openvpn_version=$($openvpn_path --version | head -n 1 | awk '{print $2}')
        echo "$openvpn_version"
    fi
}


# GET CURRENT DIETPI VERSION
get_diepi_version() {
	local version_file="/boot/dietpi/.version"
	if [[ -f $version_file ]]; then
		local dietpi_version=$(grep 'G_DIETPI_VERSION_CORE' $version_file | cut -d '=' -f2)
		echo "$dietpi_version"
    	else
		echo ""
    	fi
}


# GET LATEST AVAILABLE DIETPI VERSION (WHEN DOING DIETPI-UDATE)
get_dietpi_latest_version() {
	local dietpi_latest=$(/boot/dietpi/dietpi-update 2 2>&1 | awk -F': ' '/Latest version/ {print $2}' | tr -d 'v')
	if [[ $? -eq 0 ]]; then # CHECK EXIT STATUS
		echo "$dietpi_latest"
	else
		echo ""
	fi
}


# GET KERNEL VERSION FOR NON-DIETPI SYSTEMS
get_kernel_version() {
	if command -v lsb_release >/dev/null 2>&1; then
        	os_type=$(lsb_release -is)
		os_version_full=$(lsb_release -rs)
	elif [[ -f /etc/os-release ]]; then
		os_type=$(grep ^ID= /etc/os-release | cut -d'=' -f2 | tr -d '"')
		os_version_full=$(grep ^VERSION_ID= /etc/os-release | cut -d'=' -f2 | tr -d '"')
	elif [[ -f /etc/*release ]]; then
		os_info=$(head -n1 /etc/*release)
		os_type=$(echo $os_info | awk '{print $1}')
		os_version_full=$(echo $os_info | awk '{print $3}')
	else
		os_type=$(uname -o)
		os_version_full=$(uname -r)
	fi
}

# GET LATEST AVAILABLE KERNEL VERSION NUMBER FOR NON-DIETPI SYSTEMS
get_kernel_latest_version() {
	if command -v apt >/dev/null 2>&1; then
		apt update > /dev/null 2>&1
		local latest_kernel=$(apt list --upgradable 2>/dev/null | grep -E 'linux-image|linux-headers' | head -n 1 | awk -F/ '{print $2}')
		echo "$latest_kernel"
	else
		echo ""
	fi
}




if [ "$LOCATION" == "local" ] || [ "$LOCATION" == "all" ]; then

	#IF DIETPI:
	if [[ -f /boot/dietpi/.version ]]; then
		source /boot/dietpi/.version
		CORE_OS="DietPi"
		CORE_VERSION_FULL="$G_DIETPI_VERSION_CORE.$G_DIETPI_VERSION_SUB.$G_DIETPI_VERSION_RC"
		CORE_VERSION=$G_DIETPI_VERSION_CORE
		CORE_SUB_VERSION=$G_DIETPI_VERSION_SUB
		CORE_RC_VERSION=$G_DIETPI_VERSION_RC

		#GET INFO ABOUT THE AUTO UPDATE FEATURE
		if [[ -f /boot/dietpi.txt ]]; then
			CORE_AUTO_UPDATE=$(/usr/bin/awk -F "=" '/CONFIG_CHECK_APT_UPDATES/ {print $2;exit}' /boot/dietpi.txt)
			if [ "$CORE_AUTO_UPDATE" == "2" ]; then
				CORE_AUTO_UPDATE="auto"
			else
				CORE_AUTO_UPDATE="manual"
			fi
		fi
	else
	#FOR ALL OTHER SYSTEMS
		get_kernel_version
		CORE_OS="$(os_type)"
		CORE_VERSION_FULL="$(os_version_full)"
	fi

	#GET CURRENT APP VERSION
	APP_VERSION=$(get_app_version)

	#GET CURRENT OPENVPN VERSION
	OPENVPN_VERSION=$(get_openvpn_version)

	json_output="$json_output \"core_auto_update\" : \"$CORE_AUTO_UPDATE\"";
	json_output="$json_output, \"core_os\" : \"$CORE_OS\"";
	json_output="$json_output, \"core_version_full\" : \"$CORE_VERSION_FULL\"";
	json_output="$json_output, \"core_version\" : \"$CORE_VERSION\"";
	json_output="$json_output, \"core_sub_version\" : \"$CORE_SUB_VERSION\"";
	json_output="$json_output, \"core_rc_version\" : \"$CORE_RC_VERSION\"";
	json_output="$json_output, \"app_version\" : \"$APP_VERSION\"";
	json_output="$json_output, \"openvpn_version\" : \"$OPENVPN_VERSION\"";

fi


if [ "$LOCATION" == "remote" ] || [ "$LOCATION" == "all" ]; then

	#IF DIETPI:
	if [[ -f /boot/dietpi/.version ]]; then
		FUTURE_CORE_VERSION="$(get_dietpi_latest_version)"
	else
		FUTURE_CORE_VERSION="$(get_kernel_latest_version)"
	fi

	#GET LATEST APP VERSION
	FUTURE_APP_VERSION=$(get_app_latest_version)

	if [ "$LOCATION" == "all" ]; then
		json_output="$json_output,"
	fi

	json_output="$json_output \"future_core_version\" : \"$FUTURE_CORE_VERSION\"";
	json_output="$json_output, \"future_app_version\" : \"$FUTURE_APP_VERSION\"";
fi

#END JSON OUTPUT
json_output="$json_output }";

#RETURN JSON OUTPUT
echo $json_output
