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
                                -c [client_id-network-subnet, can be multiple lines, e.g. AB75DfdDF6-192.168.4.0-255.255.255.0]
                                -d [currently supported daemons: mdns|pimd, can be multiple lines]
" 1>&2
}

OPEN_VPN_DIR="/etc/openvpn/"
EASY_RSA_DIR=${OPEN_VPN_DIR}"easy-rsa/"
SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")/"

# EXIT ERROR FUNCTION
exit_abnormal() {
	echo ""
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
	re_subnet="^(128|192|224|240|248|252|254|255)\.(0|128|192|224|240|248|252|254|255)\.(0|128|192|224|240|248|252|254|255)\.(0|128|192|224|240|248|252|254|255)$"

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
			IFS='-' read -ra SERVER_ADDR <<< "${OPTARG}"
			NETWORK="${SERVER_ADDR[0]}"
			SUBNET="${SERVER_ADDR[1]}"

			if ! [[ $NETWORK =~ $re_ip ]]; then
                                echo "Invalid Server network: $NETWORK. No changes will be made."
                                exit_abnormal
                                exit 1
                        fi

                        if ! [[ $SUBNET =~ $re_subnet ]]; then
                                echo "Invalid Server subnet: $SUBNET. No changes will be made."
                                exit_abnormal
                                exit 1
                        fi

			SUBNETS+=("${OPTARG}")
		;;
                c)
			IFS='-' read -ra CLIENT_ADDR <<< "${OPTARG}"
                        CLIENTID="${CLIENT_ADDR[0]}"
			CLIENTNETWORK="${CLIENT_ADDR[1]}"
                        CLIENTSUBNET="${CLIENT_ADDR[2]}"

			if ! (( ${#CLIENTID} > 10 && ${#CLIENTID} < 80 )); then
                        	echo "Invalid Client ID. Client ID should be between 10 - 60 characters. No changes will be made."
                                exit_abnormal
                                exit 1
                        fi

                        if ! [[ $CLIENTNETWORK =~ $re_ip ]]; then
                                echo "Invalid Client network: $CLIENTNETWORK. No changes will be made."
                                exit_abnormal
                                exit 1
                        fi

                        if ! [[ $CLIENTSUBNET =~ $re_subnet ]]; then
                                echo "Invalid Client subnet: $CLIENTSUBNET. No changes will be made."
                                exit_abnormal
                                exit 1
                        fi

                        CLIENTS+=("${OPTARG}")
                ;;
                d)
                        DAEMONS+=("${OPTARG}")
                        for DAEMON in "${DAEMONS[@]}"; do
                                if ! [ $DAEMON == "mdns" -o $DAEMON == "pimd" -o $DAEMON == ":" ]; then
                                        echo "Invalid Daemons specified: $DAEMON. Currently only supporting mdns and pimd as options."
                                        exit_abnormal
                                        exit 1
                                fi
                        done
                ;;
                esac
        done


        if [ -z "$BRIDGE" ] || [ -z "$HOST" ] || [ -z "$PROTOCOL" ] || [ -z "$PORT_NUMBER" ] ; then
                echo "ERROR: When setting -t to server, -b, -h, -p, -n and -s are all required!"
                echo ""
                exit_abnormal
        fi


        # DO EXTRA CHECKS FOR OPTIONS/ARGUMENTS



	#ALWAYS SET THESE SETTINGS:

	#SET TO TAP MODE
        sed -i 's#^dev .*#dev tap#g' ${OPEN_VPN_DIR}server/server.conf
	#SET CLIENT CONFIG DIR
	sed -i 's#^;client-config-dir .*#client-config-dir ccd#g' ${OPEN_VPN_DIR}server/server.conf
	#SET SERVER CA
	sed -i "s#^ca .*#ca ${EASY_RSA_DIR}openvpn-ca/pki/ca.crt#g" ${OPEN_VPN_DIR}server/server.conf
	#SET SERVER CERT
	sed -i "s#^cert .*#cert ${EASY_RSA_DIR}openvpn-ca/server/server.crt#g" ${OPEN_VPN_DIR}server/server.conf
	#SET SERVER KEY
	sed -i "s#^key .*#key ${EASY_RSA_DIR}openvpn-ca/server/server.key#g" ${OPEN_VPN_DIR}server/server.conf
	#SET VERIFY-CLIENT-CERT
	if ! grep -q '^verify-client-cert require' ${OPEN_VPN_DIR}server/server.conf; then
	  echo 'verify-client-cert require' >> ${OPEN_VPN_DIR}server/server.conf
	fi

        # CHANGE THE PORT NUMBER
        sed -i "s/^port .*/port ${PORT_NUMBER}/g" ${OPEN_VPN_DIR}server/server.conf

        # CHANGE THE PROTOCOL
        sed -i "s/^proto .*/proto ${PROTOCOL}/g" ${OPEN_VPN_DIR}server/server.conf

        #REMOVE THE PUSH ROUTES
        sed -i '/^push "route *"$/d' ${OPEN_VPN_DIR}server/server.conf

        #ADD THE PUSH ROUTES (IF NOT EMPTY)
	if [ ! -z "$SUBNETS" ]; then
	  for SUBNET in "${SUBNETS[@]}"; do
	    IFS='-' read -ra SERVER_NETWORK <<< "${SUBNET}"
	    SERVER_NET="${SERVER_NETWORK[0]}"
	    SERVET_MASK="${SERVER_NETWORK[1]}"
	    echo "push \"route ${SERVER_NET} ${SERVER_MASK}\"" >> ${OPEN_VPN_DIR}server/server.conf
	  done
	fi

	#ALLOW THE CLIENTS, BY ADDING THEM IN THE CCD DIRECTORY
        if [ ! -z "$CLIENTS" ]; then
	  #ALWAYS CREATE THE CCD DIRECTORY
      	  mkdir -p ${OPEN_VPN_DIR}server/ccd
	  #ALWAYS EMPTY THE CCD DIRECTORY BEFORE ADDING FILES TO IT
	  rm -f ${OPEN_VPN_DIR}server/ccd/*
	  #ADD A FILE FOR EACH CLIENT WITH ITS COMMON_NAME AS FILENAME
          for CLIENT in "${CLIENTS[@]}"; do
	    IFS='-' read -ra CLIENT_NETWORK <<< "${SUBNET}"
            CLIENT_ID="${CLIENT_NETWORK[0]}"
            CLIENT_NET="${CLIENT_NETWORK[1]}"
            CLIENT_MASK="${CLIENT_NETWORK[1]}"
            touch ${OPEN_VPN_DIR}server/ccd/${CLIENT_ID}
          done
        fi


        # SAVE THE CLIENT CONFIG FILES IN THE CONFIG DIRECTORY
	if [ ! -z "$CLIENTS" ]; then
          #FIRST, ALWAYS EMPTY THE configs DIRECTORY EXCEPT OUR t1config.json FILE
          #rm -f ${SCRIPT_DIR}../configs/*
	  find "${SCRIPT_DIR}../configs/" -type f ! -name "configt1.json" -exec rm -f {} \;
          #ADD A FILE FOR EACH CLIENT WITH ITS CONFIG AND SAVE IT WITH THE MACHINE_ID AS FILENAME
          for CLIENT in "${CLIENTS[@]}"; do
            IFS='-' read -ra CLIENT_NETWORK <<< "${CLIENT}"
            CLIENT_ID="${CLIENT_NETWORK[0]}"
            CLIENT_NET="${CLIENT_NETWORK[1]}"
            CLIENT_MASK="${CLIENT_NETWORK[2]}"
	    CERT_CONTENT=$(cat "${EASY_RSA_DIR}openvpn-ca/client/${CLIENT_ID}.crt")
	    KEY_CONTENT=$(cat "${EASY_RSA_DIR}openvpn-ca/client/${CLIENT_ID}.key")
	    CA_CONTENT=$(cat "${EASY_RSA_DIR}openvpn-ca/pki/ca.crt")
CONFIG="client
dev tap
proto ${PROTOCOL}
remote ${HOST} ${PORT}
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
<ca>
$CA_CONTENT
</ca>

<cert>
${CERT_CONTENT}
</cert>

<key>
${KEY_CONTENT}
</key>
"
	    #WRITE THE CONFIG
	    echo "${CONFIG}" > ${SCRIPT_DIR}../configs/${CLIENT_ID}.conf
          done
        fi

	# ZIP ALL THE CONFIG FILES FOR DISTRIBUTION TO THE CLIENTS
	cd ${SCRIPT_DIR}../configs/
	pwd
	zip -r client_config.zip *



elif [ "$TYPE" == "client" ]; then
        #PROCES THE ZIPFILE  (UNZIP IT, PARSE SOME THINGS IN THE CLIENT CONFIG AND COPY IT)

	#CHECK IF CLIENT_CONFIG.ZIP EXISTS
	if [ -f "${SCRIPT_DIR}../configs/client_config.zip" ]; then
	  #GET MACHINE ID
	  MACHINE_ID=$("${SCRIPT_DIR}show_machine_id.sh" | grep -oP '(?<=machine_id" : ")[^"]+')

	  cd ${SCRIPT_DIR}../configs/

	  #UNZIP CLIENT_CONFIGS.ZIP
	  unzip "${SCRIPT_DIR}../configs/client_config.zip"

	  #CHECK IF A CONFIG EXISTS FOR THIS CLIENT
  	  if [ -f "${MACHINE_ID}.conf" ]; then
            # COPY THE FILE TO TO THE OPENVPN CLIENT CONFIG
            cp "${MACHINE_ID}.conf" "${OPEN_VPN_DIR}client/client.conf"
	  else
	    echo "ERROR: A client config does not exists for this client, did you specify this machine ID: ${MACHINE_ID} correctly?"
	    exit_abnormal
	  fi

	else
	  echo "ERROR: No client_config.zip file found!"
	  exit_abnormal
	fi

fi

