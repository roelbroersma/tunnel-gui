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
DIETPI_VERSION=""
CORE_OS=""
CORE_VERSION_FULL=""
CORE_AUTO_UPDATE=""
DIETPI_AUTO_UPDATE=""
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


# GET OS VERSION
get_os_version() {
	if [[ -f /etc/os-release ]]; then
		# Prefer /etc/os-release as it's a standard file across many distros
		os_type=$(grep ^ID= /etc/os-release | cut -d'=' -f2 | tr -d '"')
		os_version_full=$(grep ^VERSION= /etc/os-release | cut -d'=' -f2 | tr -d '"')
	elif [[ -f /etc/lsb-release ]]; then
		 # Fallback to /etc/lsb-release if available
        	os_type=$(grep ^DISTRIB_ID= /etc/lsb-release | cut -d'=' -f2)
		os_version_full=$(grep ^DISTRIB_DESCRIPTION= /etc/lsb-release | cut -d'=' -f2)
	elif command -v lsb_release >/dev/null 2>&1; then
		# Fallback to lsb_release command if available
		os_type=$(lsb_release -is)
		os_version_full=$(lsb_release -ds)
	elif [[ -f /etc/*release ]]; then
		# As a last resort, use /etc/*release
		os_info=$(head -n1 /etc/*release)
		os_type=$(echo $os_info | awk '{print $1}')
		os_version_full=$(echo $os_info | awk '{print $3}')
	elif command -v uname >/dev/null 2>&1; then
		os_type=$(uname -o)
		os_version_full=$(uname -r)
	else
		os_type="Unknown"
		os_version_full="Unknown"
	fi
}

# GET LATEST AVAILABLE OS VERSION NUMBER
get_os_latest_version() {
	# Enable case-insensitive pattern matching
	shopt -s nocasematch

	local codename=""
	local version=""

	case $os_type in
          Debian)
		codename=$(wget -qO- http://ftp.debian.org/debian/dists/stable/Release | awk '/Codename:/ {print $2}')
		version=$(wget -qO- http://ftp.debian.org/debian/dists/stable/Release | awk '/Version:/ {print $2}')
            ;;
          Ubuntu)
		codename=$(wget -qO- http://changelogs.ubuntu.com/meta-release | grep -oP 'Name: \K[^\n]*' | tail -1)
		version=$(wget -qO- http://changelogs.ubuntu.com/meta-release | grep -oP 'Version: \K[^\n]*' | tail -1)
            ;;
          CentOS|RedHat)
            	codename="Plow"
		version="9"
            ;;
          Raspbian)
		codename=$(wget -qO- http://raspbian.raspberrypi.org/raspbian/dists/stable/InRelease | awk '/Codename:/ {print $2}')
		version=$(wget -qO- http://raspbian.raspberrypi.org/raspbian/dists/stable/InRelease | awk '/Suite:/ {print $2}')
            ;;
          *)
            echo "Unsupported distribution."
            ;;
	esac

	# Check if version is empty, if so set to "Unknown"
	if [[ -z $version ]]; then
        	version="Unknown"
	fi

	# Format the output
	if [[ -z $codename ]]; then
		echo "$version"
	else
        	echo "${version} (${codename})"
	fi

	# Disable case-insensitive pattern matching
	shopt -u nocasematch
}



if [ "$LOCATION" == "local" ] || [ "$LOCATION" == "all" ]; then

	#IF DIETPI:
	if [[ -f /boot/dietpi/.version ]]; then
		source /boot/dietpi/.version
		DIETPI_VERSION="$G_DIETPI_VERSION_CORE.$G_DIETPI_VERSION_SUB.$G_DIETPI_VERSION_RC"

		#GET INFO ABOUT THE AUTO UPDATE FEATURE
		if [[ -f /boot/dietpi.txt ]]; then
			CORE_AUTO_UPDATE=$(/usr/bin/awk -F "=" '/CONFIG_CHECK_APT_UPDATES/ {print $2;exit}' /boot/dietpi.txt)
			if [ "$CORE_AUTO_UPDATE" == "2" ]; then
				CORE_AUTO_UPDATE="auto"
			else
				CORE_AUTO_UPDATE="manual"
			fi
			DIETPI_AUTO_UPDATE=$(/usr/bin/awk -F "=" '/CONFIG_CHECK_DIETPI_UPDATES/ {print $2;exit}' /boot/dietpi.txt)
                        if [ "$DIETPI_AUTO_UPDATE" == "1" ]; then
                                DIETPI_AUTO_UPDATE="auto"
                        else
                                DIETPI_AUTO_UPDATE="manual"
                        fi

		fi
	fi

	#GET OS VERSION
	get_os_version
	CORE_OS="${os_type}"
	CORE_VERSION_FULL="${os_version_full}"

	#GET CURRENT APP VERSION
	APP_VERSION=$(get_app_version)

	#GET CURRENT OPENVPN VERSION
	OPENVPN_VERSION=$(get_openvpn_version)

	json_output="$json_output \"core_auto_update\" : \"$CORE_AUTO_UPDATE\"";
	json_output="$json_output, \"dietpi_auto_update\" : \"$DIETPI_AUTO_UPDATE\"";
	json_output="$json_output, \"dietpi_version\" : \"$DIETPI_VERSION\"";
	json_output="$json_output, \"core_os\" : \"$CORE_OS\"";
	json_output="$json_output, \"core_version_full\" : \"$CORE_VERSION_FULL\"";
	json_output="$json_output, \"app_version\" : \"$APP_VERSION\"";
	json_output="$json_output, \"openvpn_version\" : \"$OPENVPN_VERSION\"";

fi


if [ "$LOCATION" == "remote" ] || [ "$LOCATION" == "all" ]; then

	#IF DIETPI:
	if [[ -f /boot/dietpi/.version ]]; then
		FUTURE_DIETPI_VERSION="$(get_dietpi_latest_version)"
	fi

	#GET LATEST CORE VERSION
	FUTURE_CORE_VERSION="$(get_os_latest_version)"

	#GET LATEST APP VERSION
	FUTURE_APP_VERSION="$(get_app_latest_version)"

	if [ "$LOCATION" == "all" ]; then
		json_output="$json_output,"
	fi

	json_output="$json_output \"future_core_version\" : \"$FUTURE_CORE_VERSION\"";
	json_output="$json_output, \"future_dietpi_version\" : \"$FUTURE_DIETPI_VERSION\"";
	json_output="$json_output, \"future_app_version\" : \"$FUTURE_APP_VERSION\"";
fi

#END JSON OUTPUT
json_output="$json_output }";

#RETURN JSON OUTPUT
echo $json_output
