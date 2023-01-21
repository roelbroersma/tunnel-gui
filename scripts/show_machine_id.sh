#!/usr/bin/bash

#THIS SCRIPT SHOWS THE MACHINE ID IN JSON

#INITIALISE AND EMPTY VARIABLES
json_output=""
MACHINE_ID=""

#START JSON OUTPUT
json_output="{";

#GET MACHINE ID
MACHINE_ID="$(cat /etc/machine-id  || echo n/a)"
json_output="$json_output \"machine_id\" : \"$MACHINE_ID\""

#END JSON OUTPUT
json_output="$json_output }";

#RETURN JSON OUTPUT
echo $json_output
