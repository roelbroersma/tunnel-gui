#!/usr/bin/bash
#THIS SCRIPT WILL CHANGE VPN SETTINGS

# USAGE FUNCTION
usage() {
        echo "Usage: change_vpn -t [client|server]
                                -b [on|off]
                                -h [public ip address or DDNS hostname]
                                -p [udp|tcp]
                                -n [port number, e.g. 443]
                                -s [network,subnet. can be multiple lines, e.g. 192.168.5.0-255.255.255.0]
                                -c [client_id;network-subnet, can be multiple lines, e.g. AB75DfdDF6;192.168.4.0-255.255.255.0]
                                -d [currently supported daemons: mdns|pimd, can be multiple lines]
" 1>&2
}

# EXIT ERROR FUNCTION
exit_abnormal() {
        usage
        exit 1
}

# CHECK THE -b ARGUMENT, SEE IF WE NEED TO SET TO SET THE BRIDGE ON OR OFF
while getopts ":t:" options; do
        case "${options}" in
                t)
                  TYPE=${OPTARG}
                  ;;
                :)
                echo "ERROR: Argument -t can not be empty. It should contain one of the following options: client or server."
                echo ""
                exit_abnormal
        esac
done


# ERROR HANDLING FOR -t ARGUMENT
if [ -z "$TYPE" ]; then
        echo "ERROR: Use of argument -t is required!"
        echo ""
        exit_abnormal
fi
if [ "$TYPE" != "server" ] && [ "$TYPE" != "client" ]; then
        echo "ERROR: Invalid option for -t specified. Argument -t should contain one of the following options: client or server."
        echo ""
        exit_abnormal
fi

#DO THIS WHEN THE SCRIPT IS CALLED WITH SERVER MODE
if [ "$TYPE" == "server" ]; then

        unset OPTIND    #RESET GETOPTS
        re_ip="^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$" #REGEX PATTERN TO CHECK FOR VALID IP (NOT TO TIGHT, MAKE 0.0.0.0 OR 255.255.255.255 STILL POSSIBLE)

        # GET -h, -p, -n, -s and -c  ARGUMENTS
        while getopts ":t:b:h:p:n:s:c:d:" options; do
                case "${options}" in
                b)
                        BRIDGE=${OPTARG}
                        if ! [ $BRIDGE == "on" -o $BRIDGE == "off" ]; then
                                echo "Bridge should be set to on or off."
                                exit_abnormal
                                exit 1
                        fi
                ;;
                h)
                        HOST=${OPTARG}
                        if [ -z "$HOST" ]; then
                                echo "A public IP or Hostname should be given."
                                exit_abnormal
                                exit 1
                        fi
                ;;
                p)
                        PROTOCOL=${OPTARG}
                        if [ $PROTOCOL != "udp" -a $PROTOCOL != "tcp" ]; then
                                echo "Invalid Protocol. No changes will be made."
                                exit_abnormal
                                exit 1
                        fi
                ;;
                n)
                        PORT_NUMBER=${OPTARG}
                        if ! [[ $PORT_NUMBER>0 && $PORT_NUMBER<65536 ]]; then
                                echo "Invalid Port Number. No changes will be made."
                                exit_abnormal
                                exit 1
                        fi
                ;;
                s)
                        SUBNETS+=${OPTARG}
                        if ! [ $SUBNETS =~ $re_ip -o $SUBNETS == ":" ]; then
                                echo "Invalid Subnets. No changes will be made."
                                exit_abnormal
                                exit 1
                        fi
                ;;
                c)
                        CLIENTS+=${OPTARG}
                        if ! [ $CLIENT =~ $re_ip -o $CLIENT == ":" ]; then
                                echo "Invalid Client ID with subnet and IPSubnets. No changes will be made."
                                exit_abnormal
                                exit 1
                        fi
                ;;
                d)
                        DAEMONS+=${OPTARG}
                        #echo "waarde:${DAEMONS[-1]}"
                        if ! [ $DAEMONS == "mdns" -o $DAEMONS == "pimd" -o $DAEMONS == ":" ]; then
                                echo "Invalid Daemons specified. Currently only supporting mdns and pimd as options."
                                exit_abnormal
                                exit 1
                        fi
                ;;
                esac
        done


        if [ -z "$BRIDGE" ] || [ -z "$HOST" ] || [ -z "$PROTOCOL" ] || [ -z "$PORT_NUMBER" ] ; then
                echo "ERROR: When setting -t to server, -b, -h, -p, -n and -s are all required!"
                echo ""
                exit_abnormal
        fi


        # DO EXTRA CHECKS FOR OPTIONS/ARGUMENTS


        # CHANGE THE PORT NUMBER
#       sed -i 's/^port .*/port $PORT_NUMBER/g' /etc/openvpn/server/server.conf

        # CHANGE THE PROTOCOL
#       sed -i 's/^proto .*/proto $PROTOCOL/g' /etc/openvpn/server/server.conf

        #REMOVE THE PUSH ROUTES
#       sed -i '/^push "route *"$/d' /etc/openvpn/server/server.conf


        #ADD THE PUSH ROUTES (IF NOT EMPTY)
        for SUBNET in "${SUBNETS[@]}"; do
                echo "subnet: $SUBNET"
        done

        if [ ! -z "$SUBNETS" ]; then
#               sed -i '/^;push "route.*/$SUBNETS' /etc/openvpn/server/server.conf
                echo "test"
        fi


        # SAVE THE CLIENT CONFIG FILES AND ZIP IT

elif [ "$TYPE" == "client" ]; then
        #PROCES THE ZIPFILE  (UNZIP IT, PARSE SOME THINGS IN THE CLIENT CONFIG AND COPY IT)
        echo "dummy"

fi

