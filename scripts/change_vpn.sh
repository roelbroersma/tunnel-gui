#!/usr/bin/bash

#THIS SCRIPT WILL CHANGE VPN SETTINGS

# USAGE FUNCTION
usage() {
        echo "Usage: change_vpn -t [client|server]

        When -t=server, following options are supported:
                  -b [on|off] This enables or disables the Bridge mode.
                  -h [public IP address or DDNS hostname] Example: 123.51.25.49 or yourhostname.no-ip.org
                  -p [udp|tcp] TCP is only advised when many UDP traffic flows via the tunnel, otherwise use UDP!
                  -n [0-65535] Port number, use 443 to bypass most firewall and port blocking issues
                  -s [network,subnet] Can be multiple lines, e.g. -s 192.168.5.0-255.255.255.0 -s 10.0.0.0-255.255.0.0
                  -c [client_id-network-subnet] Can be multiple lines, e.g. -c ABCDEFGH-192.168.4.0-255.255.255.0 -c UVWXYZ-92.168.10.0-255.255.255.0
                  -f [mdns|pimd|stp] Currently supported features: mdns, pimd, stp. Can be multiple lines, e.g. -f mdns -f pimd
                      mdns = Enables Avahi-Daemon MDNS Reflector which forwards all MDNS traffic (only needed when not in bridge mode)
                      pimd = Enabled PIMD Multicast routers that forwards all Multicasts (only needed when not in bridge mode)
		      stp  = Enables Forwarding of STP/RSTP/PVSTP/MST BPDUs (Only relevant in Bridge mode. Be carefull, switch may block your port!)

" 1>&2
}

OPEN_VPN_DIR="/etc/openvpn/"
EASY_RSA_DIR=${OPEN_VPN_DIR}"easy-rsa/"
SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")/"
CONFIG_DIR="${SCRIPT_DIR}../configs/"
OPENVPN_STATUS_FILE="/var/log/openvpn/openvpn-status.log"
PIMD_CONF_FILE="/etc/pimd.conf"
AVAHI_CONF_FILE="/etc/avahi/avahi-daemon.conf"

#INITIALIZE VARIABLES
unset TYPE
unset BRIDGE
unset HOST
unset PROTOCOL
unset PORT_NUMBER
unset SUBNETS
unset CLIENTS
unset FEATURES
unset FOUND_STP

# EXIT ERROR FUNCTION
exit_abnormal() {
	echo ""
	usage
	exit 1
}

# FUNCTION TO DISABLE FEATURES
disable_features() {
	systemctl stop avahi-daemon && systemctl disable avahi-daemon
	systemctl stop pimd && systemctl disable pimd

	if [ $BRIDGE == "on" ]; then
		echo "Disabling the Spanning Tree over the Bridge..."
		brctl stp br0 off
		#ALL PVST VLANS
		ebtables -A FORWARD -d 01:00:0c:cc:cc:00/ff:ff:ff:ff:ff:00 -j DROP
		#ALL STP, RSTP and MST
		ebtables -A FORWARD -d 01:80:C2:00:00:00/ff:ff:ff:ff:ff:f0 -j DROP
	fi
}

# FUNCTION TO ENABLE FEATURES
# VARIABLES NEEDED: FEATURES,CLIENTS,SUBNETS
# WHEN FEATURE STP IS SET, IT ALSO NEEDS BRIDGE VARIABLE
# WHEN RUNNING ON A CLIENT, IT ALSO NEEDS: MACHINE_ID AND TYPE
enable_features() {
	#ACTIVATE FEATURES
	for FEATURE in "${FEATURES[@]}"; do

		if [ $FEATURE == "mdns" ]; then
			#SET THE MDNS CONFIG
			sed -i 's#^enable-reflector=.*#enable-reflector=yes#g' ${AVAHI_CONF_FILE}
			systemctl enable avahi-daemon && systemctl start avahi-daemon

		elif [ $FEATURE == "pimd" ]; then
			#SET THE PIMD CONFIG

			#REMOVE THE phyint LINES
			sed -i '/^phyint .*/d' ${PIMD_CONF_FILE}

			#SET BSR CANDIDATE LINE (SET TO LOW PRIORITY=LOW)
			if grep -qE '^[;#]?bsr-candidate' ${PIMD_CONF_FILE}; then
				#REPLACE
				sed -i 's/^[;#]\?bsr-candidate.*/bsr-candidate priority 2/' ${PIMD_CONF_FILE}
			else
				#ADD
    				echo 'bsr-candidate priority 2' >> ${PIMD_CONF_FILE}
			fi

			#SET RP CANDIDATE LINE (SET TO LOW PRIORITY=HIGH)
			if grep -qE '^[;#]?rp-candidate' ${PIMD_CONF_FILE}; then
				#REPLACE
				sed -i 's/^[;#]\?rp-candidate.*/rp-candidate time 30 priority 250/' ${PIMD_CONF_FILE}
			else
				#ADD
    				echo 'rp-candidate time 30 priority 250' >> ${PIMD_CONF_FILE}
			fi

			#SET GROUP PREFIX
			if grep -qE '^[;#]?group-prefix' ${PIMD_CONF_FILE}; then
				#REPLACE
				sed -i 's/^[;#]\?group-prefix.*/group-prefix 224.0.0.0 masklen 4/' ${PIMD_CONF_FILE}
			else
				#ADD
    				echo 'group-prefix 224.0.0.0 masklen 4' >> ${PIMD_CONF_FILE}
			fi

			# IF THIS WE ARE RUNNING ON THE CLIENT, ADD ALL ALTNETS HERE
			if [[ ${TYPE} == "client" ]]; then
				# ADD ALL NETWORKS OF THE SERVER TO THE CLIENT'S TAP INTERFACE
				ALTNET_TAP="phyint tap0 enable altnet 172.16.199.0/24"
				ALTNET_ETH="phyint eth0 enable"
				if [ ! -z "$SUBNETS" ]; then
					for NETWORK in "${SUBNETS[@]}"; do
						IFS='-' read -ra SERVER_NETWORK <<< "${NETWORK}"
						SERVER_NET="${SERVER_NETWORK[0]}"
						SERVER_MASK="${SERVER_NETWORK[1]}"
						SERVER_CIDR=$(mask_to_cidr $SERVER_MASK)
						ALTNET_TAP="${ALTNET_TAP} altnet ${SERVER_NET}/${SERVER_CIDR}"
					done
				fi
				# ALSO ADD ALL OTHER CLIENTS SUBNETS TO THE TAP0 INTERFACE (BUT NOT OUR OWN ONE)
				if [ ! -z "$CLIENTS" ]; then
					for CLIENT in "${CLIENTS[@]}"; do
						IFS='-' read -ra CLIENT_NETWORK <<< "${CLIENT}"
						CLIENT_ID="${CLIENT_NETWORK[0]}"
						CLIENT_NET="${CLIENT_NETWORK[1]}"
						CLIENT_MASK="${CLIENT_NETWORK[2]}"
						CLIENT_CIDR=$(mask_to_cidr $CLIENT_MASK)
						if [[ ${CLIENT_ID} == ${MACHINE_ID}  ]]; then
							ALTNET_ETH="${ALTNET_ETH} altnet $CLIENT_NET/$CLIENT_CIDR"
						else
							ALTNET_TAP="${ALTNET_TAP} altnet ${CLIENT_NET}/${CLIENT_CIDR}"
						fi
					done
				fi
				echo "${ALTNET_TAP}" >> ${PIMD_CONF_FILE}
				echo "${ALTNET_ETH}" >> ${PIMD_CONF_FILE}

			# IF THIS WE ARE RUNNING ON THE SERVER, ADD ALL ALTNETS HERE
			elif [[ ${TYPE} == "server" ]]; then
				# ADD ALL NETWORKS OF ALL CLIENTS TO THE SERVER'S TAP INTERFACE
				ALTNET_TAP="phyint tap0 enable altnet 172.16.199.0/24"
				ALTNET_ETH="phyint eth0 enable"
				if [ ! -z "$CLIENTS" ]; then
					for CLIENT in "${CLIENTS[@]}"; do
						IFS='-' read -ra CLIENT_NETWORK <<< "${CLIENT}"
						CLIENT_NET="${CLIENT_NETWORK[1]}"
						CLIENT_MASK="${CLIENT_NETWORK[2]}"
						CLIENT_CIDR=$(mask_to_cidr $CLIENT_MASK)
						ALTNET_TAP="${ALTNET_TAP} altnet ${CLIENT_NET}/${CLIENT_CIDR}"
					done
				fi
				# ALSO ADD ALL SERVERS SUBNETS TO THE ETH0 INTERFACE
				if [ ! -z "$SUBNETS" ]; then
					for NETWORK in "${SUBNETS[@]}"; do
						IFS='-' read -ra SERVER_NETWORK <<< "${NETWORK}"
						SERVER_NET="${SERVER_NETWORK[0]}"
						SERVER_MASK="${SERVER_NETWORK[1]}"
						SERVER_CIDR=$(mask_to_cidr $SERVER_MASK)
						ALTNET_ETH="${ALTNET_ETH} altnet ${SERVER_NET}/${SERVER_CIDR}"
					done
				fi
				echo "${ALTNET_TAP}" >> ${PIMD_CONF_FILE}
				echo "${ALTNET_ETH}" >> ${PIMD_CONF_FILE}
			fi

			systemctl enable pimd && systemctl start pimd

		elif [ $FEATURE == "stp" -a $BRIDGE == "on" ]; then
			brctl stp br0 on
			#DELETE THE FORWARD CHAIN
			ebtables -F FORWARD

		else
			echo "Invalid Features specified: $FEATURE. Currently only supporting mdns, pimd and stp as options."
			exit_abnormal
		fi
	done
}

#FUNCTION TO START AND STOP THE OPENVPN SERVER
#VARIABLES NEEDED: START_OR_STOP , TYPE (=CLIENT OR SERVER)
start_stop_openvpn (){
	local start_or_stop=$1
	#STOP ALL OCCURENCES OF OPENVPN, NO MATTER IF IT'S SERVER OR CLIENT
	if [ "${start_or_stop}" == "stop" ]; then
		systemctl stop openvpn-server@server.service
		systemctl stop openvpn-client@client.service
		#DISABLE OPENVPN FROM AUTOMATIC START AT SERVER REBOOT
		systemctl disable openvpn-server@server.service 
		systemctl disable openvpn-client@client.service
	fi

	#START OPENVPN SERVER (SERVER MODE)
	if [ "${start_or_stop}" == "start" -a "${TYPE}" == "server" ]; then
		systemctl start openvpn-server@server.service
		systemctl enable openvpn-server@server.service
	fi

	#START OPENVPN SERVER (CLIENT MODE)
	if [ "${start_or_stop}" == "start" -a "${TYPE}" == "client" ]; then
		systemctl start openvpn-client@client.service
		systemctl enable openvpn-client@client.service
	fi
}

# FUNCTION WHICH CONVERTS A NETMASK TO A CIDR. EXAMPLE: 255.255.0.0 => /16
mask_to_cidr() {
    local mask=$1
    local -i cidr=0
    IFS='.' read -r i1 i2 i3 i4 <<< "$mask"
    for octet in $i1 $i2 $i3 $i4; do
        while [ $octet -gt 0 ]; do
            cidr=$((cidr + (octet % 2)))
            octet=$((octet / 2))
        done
    done
    echo $cidr
}


# CHECK THE -b ARGUMENT, SEE IF WE NEED TO SET TO SET THE BRIDGE ON OR OFF
while getopts ":t:" options; do
	case "${options}" in
	t)
		TYPE=${OPTARG}
	;;
	:)
		echo "ERROR: Argument -t can not be empty. It should contain one of the following options: client or server."
		exit_abnormal
	;;
	esac
done


# ERROR HANDLING FOR -t ARGUMENT
if [ -z "$TYPE" ]; then
	echo "ERROR: Use of argument -t is required!"
	exit_abnormal
fi
if [ "$TYPE" != "server" ] && [ "$TYPE" != "client" ]; then
	echo "ERROR: Invalid option for -t specified. Argument -t should contain one of the following options: client or server."
	exit_abnormal
fi

#DO THIS WHEN THE SCRIPT IS CALLED WITH SERVER MODE
if [ "$TYPE" == "server" ]; then

	unset OPTIND    #RESET GETOPTS
	#REGEX PATTERN TO CHECK FOR VALID IP (NOT TO TIGHT, MAKE 0.0.0.0 OR 255.255.255.255 STILL POSSIBLE)
	re_ip="^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
	re_subnet="^(128|192|224|240|248|252|254|255)\.(0|128|192|224|240|248|252|254|255)\.(0|128|192|224|240|248|252|254|255)\.(0|128|192|224|240|248|252|254|255)$"

	# GET -h, -p, -n, -s and -c  ARGUMENTS
	while getopts ":t:b:h:p:n:s:c:f:" options; do
		case "${options}" in
		b)
			BRIDGE=${OPTARG}
			if ! [ $BRIDGE == "on" -o $BRIDGE == "off" ]; then
				echo "Bridge should be set to on or off."
				exit_abnormal
			fi
		;;
		h)
			HOST=${OPTARG}
			if [ -z "$HOST" ]; then
				echo "A public IP or Hostname should be given."
				exit_abnormal
			fi
		;;
		p)
			PROTOCOL=${OPTARG}
			if [ $PROTOCOL != "udp" -a $PROTOCOL != "tcp" ]; then
				echo "Invalid Protocol. No changes will be made."
				exit_abnormal
			fi
		;;
		n)
			PORT_NUMBER=${OPTARG}
			if ! [[ $PORT_NUMBER > 0 && $PORT_NUMBER < 65536 ]]; then
				echo "Invalid Port Number. No changes will be made."
				exit_abnormal
			fi
		;;
		s)
			IFS='-' read -ra SERVER_ADDR <<< "${OPTARG}"
			NETWORK="${SERVER_ADDR[0]}"
			SUBNET="${SERVER_ADDR[1]}"

			if ! [[ $NETWORK =~ $re_ip ]]; then
				echo "Invalid Server network: $NETWORK. No changes will be made."
				exit_abnormal
			fi

			if ! [[ $SUBNET =~ $re_subnet ]]; then
				echo "Invalid Server subnet: $SUBNET. No changes will be made."
				exit_abnormal
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
			fi

			if ! [[ $CLIENTNETWORK =~ $re_ip ]]; then
				echo "Invalid Client network: $CLIENTNETWORK. No changes will be made."
				exit_abnormal
			fi

			if ! [[ $CLIENTSUBNET =~ $re_subnet ]]; then
				echo "Invalid Client subnet: $CLIENTSUBNET. No changes will be made."
				exit_abnormal
			fi

			CLIENTS+=("${OPTARG}")
		;;
		f)
			FEATURES+=("${OPTARG}")
			for FEATURE in "${FEATURES[@]}"; do
				if ! [ $FEATURE == "mdns" -o $FEATURE == "pimd" -o $FEATURE == "stp" -o $FEATURE == ":" ]; then
					echo "Invalid Features specified: $FEATURE. Currently only supporting mdns, pimd and stp as options."
					exit_abnormal
				fi
			done
		;;
		esac
	done


	if [ -z "$BRIDGE" ] || [ -z "$HOST" ] || [ -z "$PROTOCOL" ] || [ -z "$PORT_NUMBER" ] ; then
		echo "ERROR: When setting -t to server, -b, -h, -p, -n and -s are all required!"
		exit_abnormal
	fi

	# DO EXTRA CHECKS FOR OPTIONS/ARGUMENTS
	FOUND_STP=false
	for feature in "${FEATURES[@]}"; do
		if [[ "$feature" == "stp" ]]; then
	        	found_stp=true
		        break
		fi
	done
	if [ "$BRIDGE" == "off" -a "$FOUND_STP" == true ]; then
		echo "ERROR: No Bridge selected but STP feature is enabled. STP feature will not work when in Normal (non-bridge) mode!"
		exit_abnormal
	fi

	#EXECUTE CHANGE BRIDGE SCRIPT (ONLY DOES SOMETHING IF MODE IS DIFFERENT THAN CURRENT MODE)
	${SCRIPT_DIR}change_bridge.sh -b $BRIDGE

	#ALWAYS SET THESE SETTINGS:
	#SET TO TAP MODE
	sed -i 's#^dev .*#dev tap#g' ${OPEN_VPN_DIR}server/server.conf
	#SET CLIENT CONFIG DIR
	sed -i "s#^;\?client-config-dir .*#client-config-dir ${OPEN_VPN_DIR}server/ccd#g" ${OPEN_VPN_DIR}server/server.conf
	#SET SERVER CA
	sed -i "s#^ca .*#ca ${EASY_RSA_DIR}openvpn-ca/pki/ca.crt#g" ${OPEN_VPN_DIR}server/server.conf
	#SET SERVER CERT
	sed -i "s#^cert .*#cert ${EASY_RSA_DIR}openvpn-ca/server/server.crt#g" ${OPEN_VPN_DIR}server/server.conf
	#SET SERVER KEY
	sed -i "s#^key .*#key ${EASY_RSA_DIR}openvpn-ca/server/server.key#g" ${OPEN_VPN_DIR}server/server.conf
	#DISABLE DIFFIE HELLMAN BECAUSE WE USE ELIPTIC CURVE KEYS
	sed -i "s/^\(dh .*\)/dh none/" ${OPEN_VPN_DIR}server/server.conf

	#SET VERIFY-CLIENT-CERT
	if ! grep -q '^verify-client-cert require' ${OPEN_VPN_DIR}server/server.conf; then
	  echo 'verify-client-cert require' >> ${OPEN_VPN_DIR}server/server.conf
	fi
	#DISABLE TLS-AUTH VIA SHARED-KEY (TODO FOR EXTRA SECURITY)
	sed -i "s/^\(tls-auth.*\)/;\1/" ${OPEN_VPN_DIR}server/server.conf

	#SET SERVER OR SERVER-BRIDGE SUBNET TO A VERY UNIQUE RANGE
	if [ "$BRIDGE" == "on" ]; then
		sed -i "s/^#\?;\?server-bridge .*/server-bridge 172.16.199.0 255.255.255.0/" ${OPEN_VPN_DIR}server/server.conf
		sed -i "s/^\(server .*\)/;\1/" ${OPEN_VPN_DIR}server/server.conf
	else
		sed -i "s/^#\?;\?server .*/server 172.16.199.0 255.255.255.0/" ${OPEN_VPN_DIR}server/server.conf
		sed -i "s/^\(server-bridge .*\)/;\1/" ${OPEN_VPN_DIR}server/server.conf
	fi

	#DISABLE (old) CIPHERS IN GENERAL, DEPRECATED SINCE OPENVPN 2.6
	sed -i "s/^#\?;\?\(ciphers .*\)/#\1/" ${OPEN_VPN_DIR}server/server.conf

	#DISABLE CIPHER IN GENERAL, DEPRECATED SINCE OPENVPN 2.6
	sed -i "s/^\(cipher.*\)/#\1/" ${OPEN_VPN_DIR}server/server.conf

	#CHANGE DATA-CIPHERS
	if ! grep -q '^#\?;\?data-ciphers ' ${OPEN_VPN_DIR}server/server.conf; then
		echo 'data-ciphers AES-256-GCM:AES-128-GCM' >> ${OPEN_VPN_DIR}server/server.conf
	else
		sed -i "s/^#\?;\?data-ciphers .*/data-ciphers AES-256-GCM:AES-128-GCM/" ${OPEN_VPN_DIR}server/server.conf
	fi

	#CHANGE FALLBACK-CIPHERS
	if ! grep -q '^#\?data-ciphers-fallback' ${OPEN_VPN_DIR}server/server.conf; then
		echo 'data-ciphers-fallback AES-256-CBC:AES-128-CBC' >> ${OPEN_VPN_DIR}server/server.conf
	else
		sed -i "s/^#\?data-ciphers-fallback.*/data-ciphers-fallback AES-256-CBC:AES-128-CBC/" ${OPEN_VPN_DIR}server/server.conf
	fi

	#SET explicit-exit-notify ONLY FOR UDP MODE
	if [ "$PROTOCOL" == "udp" ]; then
		sed -i "s/^#\?;\?explicit-exit-notify .*/explicit-exit-notify 1/" ${OPEN_VPN_DIR}server/server.conf
	else
		sed -i "s/^#\?;\?explicit-exit-notify .*/explicit-exit-notify 0/" ${OPEN_VPN_DIR}server/server.conf
	fi

	#CHANGE STATUS-LOG
	mkdir -p "$(dirname ${OPENVPN_STATUS_FILE})"
	if ! grep -q '^#\?;\?status ' ${OPEN_VPN_DIR}server/server.conf; then
		echo "status ${OPENVPN_STATUS_FILE}" >> ${OPEN_VPN_DIR}server/server.conf
	else
		sed -i "s|^#\?;\?status .*|status ${OPENVPN_STATUS_FILE}|" ${OPEN_VPN_DIR}server/server.conf
	fi

	# CHANGE THE PORT NUMBER
	sed -i "s/^port .*/port ${PORT_NUMBER}/g" ${OPEN_VPN_DIR}server/server.conf

	# CHANGE THE PROTOCOL
	sed -i "s/^proto .*/proto ${PROTOCOL}/g" ${OPEN_VPN_DIR}server/server.conf

	#REMOVE THE PUSH ROUTES
	sed -i '/^push "route .*"$/d' ${OPEN_VPN_DIR}server/server.conf

	#ADD THE PUSH ROUTES (IF NOT EMPTY)
	if [ ! -z "$SUBNETS" ]; then
		for SUBNET in "${SUBNETS[@]}"; do
			IFS='-' read -ra SERVER_NETWORK <<< "${SUBNET}"
			SERVER_NET="${SERVER_NETWORK[0]}"
			SERVER_MASK="${SERVER_NETWORK[1]}"
			echo "push \"route ${SERVER_NET} ${SERVER_MASK} vpn_gateway\"" >> ${OPEN_VPN_DIR}server/server.conf
		done
	fi

	#ALSO ADD ALL THE CLIENT NETWORKS AS PUSH ROUTES (SO EACH CLIENT KNOWS HOW TO REACH ANOTHER CLIENT)
	#USE A HIGHER METRIC SO A CLIENT WILL NOT ROUTE HIS OWN CLIENT-NETWORK THROUGH THE TUNNEL
	if [ ! -z "$CLIENTS" ]; then
		for CLIENT in "${CLIENTS[@]}"; do
			IFS='-' read -ra CLIENT_NETWORK <<< "${CLIENT}"
			CLIENT_ID="${CLIENT_NETWORK[0]}"
			CLIENT_NET="${CLIENT_NETWORK[1]}"
			CLIENT_MASK="${CLIENT_NETWORK[2]}"
			echo "push \"route ${CLIENT_NET} ${CLIENT_MASK} vpn_gateway 100\"" >> ${OPEN_VPN_DIR}server/server.conf
		done
	fi

	#FIX FOR USING A PRIVATE/LOCAL IP AS VPN-ENDPOINT. THEN THE TRAFFIC FROM THE CLIENTS TO THIS ENDPOINT MAY NOT FLOW VIA THE VPN BUT MUST FOLLOW THE CLIENT ROUTING TABLE
	if [[ ${HOST} =~ ^10\.(.*) || ${HOST} =~ ^172\.1[6-9]\.(.*) || ${HOST} =~ ^172\.2[0-9]\.(.*) || ${HOST} =~ ^172\.3[0-1]\.(.*) || ${HOST} =~ ^192\.168\.(.*) ]]; then
		echo "push \"route ${HOST} 255.255.255.255 net_gateway\"" >> ${OPEN_VPN_DIR}server/server.conf
	fi

	#ALLOW THE CLIENTS, BY ADDING THEM IN THE CCD DIRECTORY
	if [ ! -z "$CLIENTS" ]; then
		#ALWAYS CREATE THE CCD DIRECTORY
		mkdir -p ${OPEN_VPN_DIR}server/ccd
		#ALWAYS EMPTY THE CCD DIRECTORY BEFORE ADDING FILES TO IT
		rm -f ${OPEN_VPN_DIR}server/ccd/*
		#ADD A FILE FOR EACH CLIENT WITH ITS COMMON_NAME AS FILENAME
		for CLIENT in "${CLIENTS[@]}"; do
			IFS='-' read -ra CLIENT_NETWORK <<< "${CLIENT}"
			CLIENT_ID="${CLIENT_NETWORK[0]}"
			CLIENT_NET="${CLIENT_NETWORK[1]}"
			CLIENT_MASK="${CLIENT_NETWORK[2]}"
			#CHECK IF FILE EXISTS, IF NOT CREATE IT
            if [ ! -f ${OPEN_VPN_DIR}server/ccd/${CLIENT_ID} ]; then
				touch ${OPEN_VPN_DIR}server/ccd/${CLIENT_ID}
            fi
			#ADD THE NETWORKS TO THE RIGHT CLIENT'S FILE
			echo "iroute ${CLIENT_NET} ${CLIENT_MASK}" >> ${OPEN_VPN_DIR}server/ccd/${CLIENT_ID}
		done
	fi


	# SAVE THE CLIENT CONFIG FILES IN THE CONFIG DIRECTORY
	if [ ! -z "$CLIENTS" ]; then
		#FIRST, ALWAYS EMPTY THE configs DIRECTORY EXCEPT OUR t1config.json FILE
		#rm -f ${CONFIG_DIR}*
		find "${CONFIG_DIR}" -type f ! -name "configt1.json" -exec rm -f {} +
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
remote ${HOST} ${PORT_NUMBER}
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server"
			#SET explicit-exit-notify ONLY FOR UDP MODE
			if [ "$PROTOCOL" == "udp" ]; then
				CONFIG="${CONFIG}
explicit-exit-notify 1"
			fi
			CONFIG="${CONFIG}
status ${OPENVPN_STATUS_FILE} 
<ca>
$CA_CONTENT
</ca>

<cert>
${CERT_CONTENT}
</cert>

<key>
${KEY_CONTENT}
</key>
########################
#----T1 CONFIG BEGIN----
#BRIDGE: ${BRIDGE}
#FEATURES: ${FEATURES[*]}
#SERVER_NETWORKS: ${SUBNETS[*]}
#CLIENT: ${CLIENTS[*]}
#-----T1 CONFIG END-----
########################
"
			#WRITE THE CONFIG
			echo "${CONFIG}" > ${CONFIG_DIR}${CLIENT_ID}.conf
		done
	fi

	# ZIP ALL THE CONFIG FILES FOR DISTRIBUTION TO THE CLIENTS
	cd ${CONFIG_DIR}
	zip -r client_config.zip *

	#FIRST, DEACTIVATE ALL FEATURES
	disable_features
	
	#ACTIVATE THE REQUESTED FEATURES
	enable_features

	#STOP AND START THE OPENVPN SERVER AND MAKE SURE IT AUTOMATICALLY STARTS AT SYSTEM REBOOT
	start_stop_openvpn "stop"
	start_stop_openvpn "start"


elif [ "$TYPE" == "client" ]; then

	if [ "$BRIDGE" ] || [ "$HOST" ] || [ "$PROTOCOL" ] || [ "$PORT_NUMBER" ] || [ "$SUBNETS" ] || [ "$CLIENTS" ] || [ "$FEATURES" ]; then
		echo "ERROR: When setting -t to client, all other options like -b, -h, -p, -n, -s, -c and -f  are not allowed! The config is created at the server and save to a config file. Clients will only parse that config file."
		exit_abnormal
	fi

	#PROCES THE ZIPFILE  (UNZIP IT, PARSE SOME THINGS IN THE CLIENT CONFIG AND COPY IT)

	#GET MACHINE ID
	MACHINE_ID=$("${SCRIPT_DIR}show_machine_id.sh" | grep -oP '(?<=machine_id" : ")[^"]+')

	#GO TO THE CONFIG FOLDER
	cd ${CONFIG_DIR}

	#FIRST, ALWAYS EMPTY THE configs DIRECTORY EXCEPT OUR t1config.json FILE
        #rm -f ${CONFIG_DIR}*
	find "${CONFIG_DIR}" -type f ! \( -name "configt1.json" -o -name "client_config.zip" -o -name "${MACHINE_ID}.conf" \) -exec rm -f {} +


	#CHECK IF CLIENT_CONFIG.ZIP EXISTS
	if [ -f "client_config.zip" ]; then
		#UNZIP CLIENT_CONFIGS.ZIP
		echo "Unpacking config files..."
		unzip -o "client_config.zip"
	fi

	#CHECK IF A CONFIG FILE FOR THIS MACHINE_ID EXISTS
	if [ ! -f "${MACHINE_ID}.conf" ]; then
		echo "ERROR: No config file for this client found with <machine_id>.conf (we also checked the client_config.zip file)!"
		exit_abnormal
	else	
		#ALWAYS CREATE THE CLIENT DIRECTORY
                mkdir -p ${OPEN_VPN_DIR}client

		# COPY THE FILE TO TO THE OPENVPN CLIENT CONFIG
		cp "${MACHINE_ID}.conf" "${OPEN_VPN_DIR}client/client.conf"
		CONFIG_FILE="${MACHINE_ID}.conf"
	fi

	#GET THE BRIDGE VARIABLE
	BRIDGE=$(sed -n '/#BRIDGE:/s/.*: \(.*\)/\1/p' "$CONFIG_FILE")

	#CHANGE TO BRIDGE OR NORMAL MODE
	if [ "$BRIDGE" == "on" ] || [ "$BRIDGE" == "off" ]; then
		${SCRIPT_DIR}change_bridge.sh -b $BRIDGE
	fi

	#FIRST, DEACTIVATE ALL FEATURES
	disable_features

	#GET THE FEATURES VARIABLE
	FEATURES_LINE=$(sed -n '/#FEATURES:/s/.*: \(.*\)/\1/p' "$CONFIG_FILE")
	#PUT IT INTO AN ARRAY
	IFS=' ' read -r -a FEATURES <<< "$FEATURES_LINE"

	#GET THE CLIENTS VARIABLE
	CLIENTS_LINE=$(sed -n '/#CLIENT:/s/.*: \(.*\)/\1/p' "$CONFIG_FILE")
	#PUT IT INTO AN ARRAY
	IFS=' ' read -r -a CLIENTS <<< "$CLIENTS_LINE"

	#GET THE SERVER NETWORKS VARIABLE
	SERVER_NETWORKS_LINE=$(sed -n '/#SERVER_NETWORKS:/s/.*: \(.*\)/\1/p' "$CONFIG_FILE")
	#PUT IT INTO AN ARRAY
	IFS=' ' read -r -a SUBNETS <<< "$SERVER_NETWORKS_LINE"
	
	#ACTIVATE THE REQUESTED FEATURES
	enable_features

	#DELETE ALL FILES FROM CONFIG DIRECTORY
	rm -f ${CONFIG_DIR}*

	#STOP AND START THE OPENVPN CLIENT AND MAKE SURE IT AUTOMATICALLY STARTS AT SYSTEM REBOOT
	start_stop_openvpn "stop"
	start_stop_openvpn "start"

fi

