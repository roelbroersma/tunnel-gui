#!/usr/bin/bash
#THIS SCRIPT IS WILL SET THE IP ADDRESS TO STATIC OR DHCP AND KEEP BRIDGE MODE IF IT EXISTS

# USAGE FUNCTION
usage() {
echo "Usage: change_ip -t [dhcp|static]
                  [-a 192.168.0.1 -n 255.255.255.0 -g 192.168.0.254 -d \"8.8.8.8 [8.8.4.4]]\"
		  
Note: The DNS Servers (even if it's only 1) should be between double quotes." 1>&2
}

# EXIT ERROR FUNCTION
exit_abnormal() {
	usage
	exit 1
}

# INITIALIZE VARIABLES AND MAKE SURE THEY ARE EMTPY
SCRIPT_DIR=$(dirname -- "$0")
IP=""
NETWORK=""
GATEWAY=""
DNS=""
BRIDGE=""
BUGFIX1=""


# CHECK THE -t ARGUMENT, SEE IF WE NEED TO SET TO STATIC OR DHCP
while getopts ":t:" options; do
	case "${options}" in
		t)
		  TYPE=${OPTARG}
		  ;;
	  	:)
		echo "ERROR: Argument -t can not be empty. It should contain one of the following options: dhcp or static."
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
if [ "$TYPE" != "dhcp" ] && [ "$TYPE" != "static" ]; then
        echo "ERROR: Invalid option for -t specified. Argument -t should contain one of the following options: dhcpor static."
        echo ""
        exit_abnormal
fi


# CHECK IF WE ARE CURRENTLY IN BRIDGE MODE
if grep -q "iface br0" /etc/network/interfaces; then
	BRIDGE=ACTIVE
fi


# CHECK IF WE NEED TO APPLY A DIRTY BUGFIX
if grep -q "wpa-conf" /etc/network/interfaces; then
	BUGFIX1=`grep "wpa-conf" /etc/network/interfaces`				#SAVE THE wpa-conf LINE IN A VARIABLE SO WE CAN ADD IT LATER BACK TO THE FILE.
	sed -i 's/wpa-conf.*//' /etc/network/interfaces		#REMOVE THE wpa-conf LINE BECAUSE OUR CHANGE-INTERFACES AWK SCRIPT DOESNT HANDLE IT WELL
fi



# IF WE NEED TO SET A STATIC IP, DO THIS:	
if [ "$TYPE" == "static" ]; then

	unset OPTIND	#RESET GETOPTS
	re_ip="^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$" #REGEX PATTERN TO CHECK FOR VALID IP (NOT TO TIGHT, MAKE 0.0.0.0 OR 255.255.255.255 STILL POSSIBLE)
       re_dns="^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(([[:space:]]((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))?)$" #REGEX PATTERN TO CHECK FOR VALID DNS SERVER(S) (NOT TO TIGHT, MAKE 0.0.0.0 OR 255.255.255.255 STILL POSSIBLE)

	# GET -a, -n, -g and -d  ARGUMENTS
	while getopts ":t:a:n:g:d:" options; do
		case "${options}" in
		a)
			IP=${OPTARG}
			if ! [[ $IP =~ $re_ip ]]; then
				echo "Invalid IP Address. No changes will be made."
				exit_abnormal
				exit 1
			fi
	       	;;
		n)
			NETWORK=${OPTARG}
			if ! [[ $NETWORK =~ $re_ip ]]; then
				echo "Invalid NETWORK Address. No changes will be made."
				exit_abnormal
				exit 1
			fi
		;;
		g)
			GATEWAY=${OPTARG}
			if ! [[ $GATEWAY =~ $re_ip ]]; then
				echo "Invalid GATEWAY Address. No changes will be made."
				exit_abnormal
				exit 1
			fi
		;;
		d)
			DNS=${OPTARG}
			if ! [[ $DNS =~ $re_dns ]]; then
				echo "Invalid DNS SERVER Address(es). No changes will be made."
				exit_abnormal
				exit 1
		       	fi
		;;
		esac
	done

	if [ -z "$IP" ] || [ -z "$NETWORK" ] || [ -z "$GATEWAY" ] || [ -z "$DNS" ]; then
		echo "ERROR: When setting -t to static, -a, -n, -g and -d are all required!"
		echo ""
		exit_abnormal
	fi


	#STATIC ADDRESS
	if [ "$BRIDGE" == "ACTIVE" ]; then
		#USING BRIDGE MODE, SO CHANGE IP ADDRESS OF BRIDGE
		echo "Changing IP Address of br0 to new Static IP"
		awk -f $SCRIPT_DIR/changeInterface.awk /etc/network/interfaces dev=br0 mode=static 'bridge_ports=eth0 tap0' address=$IP netmask=$NETWORK gateway=$GATEWAY "dns=$DNS" > /tmp/tmp_interfaces
	else
		#USING NON-BRIDGE MODE, SO ONLY CHANGE IP ADDRESS OF ETH0
		echo "Changing IP Address of eth0 to new Static IP"
		awk -f $SCRIPT_DIR/changeInterface.awk /etc/network/interfaces dev=eth0 mode=static address=$IP netmask=$NETWORK gateway=$GATEWAY "dns=$DNS" > /tmp/tmp_interfaces
	fi

fi

#DHCP ADDRESS
if [ "$TYPE" == "dhcp" ]; then

	if [ "$BRIDGE" == "ACTIVE" ]; then
		#USING BRIDGE MODE, SO CHANGE IP ADDRESS OF BRIDGE
		echo "Changing IP Address of br0 to DHCP Mode"
		awk -f $SCRIPT_DIR/changeInterface.awk /etc/network/interfaces dev=br0 mode=dhcp > /tmp/tmp_interfaces
	else
		#USING NON-BRIDGE MODE, SO ONLY CHANGE IP ADDRESS OF ETH0
		echo "Changing IP Address of eth0 to DHCP Mode"
		awk -f $SCRIPT_DIR/changeInterface.awk /etc/network/interfaces dev=eth0 mode=dhcp > /tmp/tmp_interfaces
	fi
fi


#DO CHECK TO SEE IF INTERFACES WILL COME UP BY DEFAULT, IF NOT, ADD THE AUTO COMMAND
if [ "$BRIDGE" == "active" ]; then
	if ! grep -q "auto br0" /etc/network/interfaces; then
		sed -i '/iface br0/i auto br0' /tmp/tmp_interfaces
	fi
fi

if ! grep -q "auto eth0" /etc/network/interfaces; then
	sed -i '/iface eth0/i auto eth0' /tmp/tmp_interfaces
fi

#SHOULD WE APPLY BUGFIX1?
if [ -n "$BUGFIX1" ]; then
	echo $BUGFIX1 >> /tmp/tmp_interfaces
fi


# FOR SOME REASON WE CAN NOT WRITE TO THE /ETC/NETWORK/INTERFACES FILE DIRECTLY, SO WE DO IT THIS WAY, VIA A TMP FILE.
cp /tmp/tmp_interfaces /etc/network/interfaces
#rm /tmp/tmp_interfaces

#RESTART NETWORKING
service networking restart
