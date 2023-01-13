#!/usr/bin/bash

#THIS SCRIPT SHOWS THE PUBLIC IP, HOW THIS DEVICE IS CONNECTED TO THE INTERNET

#INITIALISE AND EMPTY VARIABLES
json_output=""
PUBLIC_IP4=""
PUBLIC_IP6=""

#START JSON OUTPUT
json_output="{";

#GET PUBLIC IP (IPv4 and IPv6)
PUBLIC_IP4="$(curl -sf v4.ident.me)"
PUBLIC_IP6="$(curl -sf v6.ident.me)"

json_output="$json_output \"public_ipv4\" : \"$PUBLIC_IP4\", "
json_output="$json_output \"public_ipv6\" : \"$PUBLIC_IP6\""

#END JSON OUTPUT
json_output="$json_output }";

#RETURN JSON OUTPUT
echo $json_output
