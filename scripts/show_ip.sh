#!/usr/bin/bash

#THIS SCRIPT SHOWS IP ADDRESS INFORMATION IN JSON FORMAT, INCLUDING INFORMATION ABOUT BRIDGE MODE AND DHCP/STATIC MODE.


# VERY SIMPLE AND DUMB FUNCTION TO CONVERT A CIDR IN A SUBNET MASK
function cidr_to_subnet {
        if [ "$1" == "/32" ]; then
                echo "255.255.255.255"
        elif [ "$1" == "/31" ]; then
                echo "255.255.255.254"
        elif [ "$1" == "/30" ]; then
                echo "255.255.255.252"
        elif [ "$1" == "/29" ]; then
                echo "255.255.255.248"
        elif [ "$1" == "/28" ]; then
                echo "255.255.255.240"
        elif [ "$1" == "/27" ]; then
                echo "255.255.255.224"
        elif [ "$1" == "/26" ]; then
                echo "255.255.255.192"
        elif [ "$1" == "/25" ]; then
                echo "255.255.255.128"
        elif [ "$1" == "/24" ]; then
                echo "255.255.255.0"
        elif [ "$1" == "/23" ]; then
                echo "255.255.254.0"
        elif [ "$1" == "/22" ]; then
                echo "255.255.252.0"
        elif [ "$1" == "/21" ]; then
                echo "255.255.248.0"
        elif [ "$1" == "/20" ]; then
                echo "255.255.240.0"
        elif [ "$1" == "/19" ]; then
                echo "255.255.224.0"
        elif [ "$1" == "/18" ]; then
                echo "255.255.192.0"
        elif [ "$1" == "/17" ]; then
                echo "255.255.128.0"
        elif [ "$1" == "/16" ]; then
                echo "255.255.0.0"
        elif [ "$1" == "/15" ]; then
                echo "255.254.0.0"
        elif [ "$1" == "/14" ]; then
                echo "255.252.0.0"
        elif [ "$1" == "/13" ]; then
                echo "255.248.0.0"
        elif [ "$1" == "/12" ]; then
                echo "255.240.0.0"
        elif [ "$1" == "/11" ]; then
                echo "255.224.0.0"
        elif [ "$1" == "/10" ]; then
                echo "255.192.0.0"
        elif [ "$1" == "/9" ]; then
                echo "255.128.0.0"
        elif [ "$1" == "/8" ]; then
                echo "255.0.0.0"
        elif [ "$1" == "/7" ]; then
                echo "254.0.0.0"
        elif [ "$1" == "/6" ]; then
                echo "252.0.0.0"
        elif [ "$1" == "/5" ]; then
                echo "248.0.0.0"
        elif [ "$1" == "/4" ]; then
                echo "240.0.0.0"
        elif [ "$1" == "/3" ]; then
                echo "224.0.0.0"
        elif [ "$1" == "/2" ]; then
                echo "192.0.0.0"
        elif [ "$1" == "/1" ]; then
                echo "128.0.0.0"
        elif [ "$1" == "/0" ]; then
                echo "0.0.0.0"
        fi
}

#START JSON OUTPUT
json_output="{ ";


#CHECK IF WE ARE USING A BRIDGE INTERFACE
if [[ $(ip addr | grep br0) ]]; then
        json_output="$json_output \"mode\" : \"bridge\"";
        interface=br0
else
        json_output="$json_output \"mode\" : \"normal\""
        interface=eth0;
fi


#CHECK IF STATIC OR DYNAMIC (DHCP)
if [[ $(ip -f inet addr show $interface | grep dynamic) ]]; then
        json_output="$json_output, \"type\" : \"dhcp\"";
        type=dhcp
else
        json_output="$json_output, \"type\" : \"static\""
        type=static;
fi


#GET IP ADDRESS
ip="$(ip address show $interface | awk '/inet / {print $2}' | sed -e 's/\/..//g')"
json_output="$json_output, \"ip_address\" : \"$ip\""


#GET SUBNET MASK
cidr="$(ip address show $interface | awk '/inet / {print $2}' | sed -e 's/^[0-9\.\:]*//g')"
subnet=$(cidr_to_subnet $cidr)
json_output="$json_output, \"subnet\" :\"$subnet\""


#GET GATEWAY ADDRESS
gateway="$(ip -f inet route | grep default | awk '{print $3}')"
json_output="$json_output, \"gateway\" :\"$gateway\""

#GET DNS ADDRESSES FROM /etc/resolv.conf, PUT THEM IN A LIST AND LOOP THROUGH THEM
dns_list="$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}')"
IFS=$'\n'       #SET THE FIELD OPERATOR TO A NEW LINE
json_output="$json_output, \"dns_servers\" : ["
for dns_server in $dns_list
do
        json_output="$json_output \"$dns_server\", "
done
# REMOVE TRAILING SPACE AND COMMA
json_output="$(echo $json_output | sed 's/,\s$//g')"
json_output="$json_output ]"


#END JSON OUTPUT
json_output="$json_output }"


#SHOW JSON OUTPUT
echo $json_output
