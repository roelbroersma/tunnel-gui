#!/usr/bin/bash

#THIS SCRIPT SHOWS THE CURRENT VERSIONS IN JSON

#INITIALISE AND EMPTY VARIABLES
json_output=""
CURRENT_T1_VERSION=""
DIETPI_CORE_VERSION=""
DIETPI_SUB_VERSION=""
DIETPI_RC_VERSION=""

FUTURE_T1_VERSION=""
FUTURE_DIETPI_VERSION=""
FUTURE_DIETPI_CORE_VERSION=""
FUTURE_DIETPI_SUB_VERSION=""
FUTURE_DIETPI_RC_VERSION=""

# INITIALIZE VARIABLES AND MAKE SURE THEY ARE EMTPY
SCRIPT_DIR=$(dirname -- "$0")

#START JSON OUTPUT
json_output="{";

#GET CURRENT DIETPI VERSION
DIETPI_CORE_VERSION=$(/usr/bin/awk -F "=" '/G_DIETPI_VERSION_CORE/ {print $2}' /boot/dietpi/.version)
DIETPI_SUB_VERSION=$(/usr/bin/awk -F "=" '/G_DIETPI_VERSION_SUB/ {print $2}' /boot/dietpi/.version)
DIETPI_RC_VERSION=$(/usr/bin/awk -F "=" '/G_DIETPI_VERSION_RC/ {print $2}' /boot/dietpi/.version)

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
      FUTURE_DIETPI_CORE_VERSION = "Not available"
fi

#GET CURRENT T1 VERSION
CURRENT_T1_VERSION="$(cat $SCRIPT_DIR/../.version)"

#GET FUTURE T1 VERSION (THE VERSION TO WHICH WE CAN UPGRADE)
FUTURE_T1_VERSION="$(curl --silent --fail --location --max-time 8 --connect-timeout 8 https://raw.githubusercontent.com/roelbroersma/tunnel-gui/main/.version)"
FUTURE_T1_VERSION=$(echo "$FUTURE_T1_VERSION" | /usr/bin/awk -F "=" '/T1_VERSION/ {print $2;exit}')

#IF WE DID NOT GET ANY VERSION NUMBER SHOW "Not available.." IN THE OUTPUT.
if [ -z "$FUTURE_T1_VERSION" ]; then
      FUTURE_T1_VERSION = "Not available"
fi

json_output="$json_output \"current_dietpi_version\" : \"$DIETPI_CORE_VERSION.$DIETPI_SUB_VERSION.$DIETPI_RC_VERSION\"";
json_output="$json_output, \"current_t1_version\" : \"$CURRENT_T1_VERSION\"";
json_output="$json_output, \"future_dietpi_version\" : \"$FUTURE_DIETPI_CORE_VERSION.$FUTURE_DIETPI_SUB_VERSION.$FUTURE_DIETPI_RC_VERSION\"";
json_output="$json_output, \"future_t1_version\" : \"$FUTURE_T1_VERSION\"";

#END JSON OUTPUT
json_output="$json_output }";

#RETURN JSON OUTPUT
echo $json_output
~
