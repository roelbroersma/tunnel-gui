#!/usr/bin/bash
#THIS SCRIPT IS WILL CHANGE THE INTERFACE TO BRIDGE MODE OR CHANGE IT BACK TO NORMAL (NON-BRIDGE) MODE

# USAGE FUNCTION
usage() {
        echo "Usage: change_bride -b [on|off]

Note: When setting the interface in bridge mode while it's already in bridge mode, nothing will change." 1>&2
}

# EXIT ERROR FUNCTION
exit_abnormal() {
        usage
        exit 1
}

# CHECK THE -b ARGUMENT, SEE IF WE NEED TO SET TO SET THE BRIDGE ON OR OFF
while getopts ":b:" options; do
        case "${options}" in
                b)
                  BRIDGE=${OPTARG}
                  ;;
                :)
                echo "ERROR: Argument -b can not be empty. It should contain one of the following options: on or off."
                echo ""
                exit_abnormal
        esac
done

# ERROR HANDLING FOR -t ARGUMENT
if [ -z "$BRIDGE" ]; then
        echo "ERROR: Use of argument -b is required!"
        echo ""
        exit_abnormal
fi
if [ "$BRIDGE" != "on" ] && [ "$BRIDGE" != "off" ]; then
        echo "ERROR: Invalid option for -b specified. Argument -b should contain one of the following options: on or off."
        echo ""
        exit_abnormal
fi



# INITIALIZE VARIABLES AND MAKE SURE THEY ARE EMTPY
SCRIPT_DIR=$(dirname -- "$0")
CURRENT_IP_INFO=""
CURRENT_MODE=""
CURRENT_TYPE=""
CURRENT_IP_ADDRESS=""
CURRENT_SUBNET=""
CURRENT_GATEWAY=""
CURRENT_DNS_SERVERS=""
BUGFIX1=""

# GET CURRENT IP ADDRESS INFO (DHCP/STATIC? IP, SUBNET, GATEWAY AND DNS)
CURRENT_IP_INFO=$(./show_ip.sh)
CURRENT_MODE=$(echo $CURRENT_IP_INFO | awk -f callbacks.awk -f JSON.awk - | grep mode | awk -F ' ' '{print $2}' | tr -d \")
CURRENT_TYPE=$(echo $CURRENT_IP_INFO | awk -f callbacks.awk -f JSON.awk - | grep type | awk -F ' ' '{print $2}' | tr -d \")
CURRENT_IP_ADDRESS=$(echo $CURRENT_IP_INFO | awk -f callbacks.awk -f JSON.awk - | grep ip_address | awk -F ' ' '{print $2}' | tr -d \")
CURRENT_SUBNET=$(echo $CURRENT_IP_INFO | awk -f callbacks.awk -f JSON.awk - | grep subnet | awk -F ' ' '{print $2}' | tr -d \")
CURRENT_GATEWAY=$(echo $CURRENT_IP_INFO | awk -f callbacks.awk -f JSON.awk - | grep gateway | awk -F ' ' '{print $2}' | tr -d \")
CURRENT_DNS_SERVERS=$(echo $CURRENT_IP_INFO | awk -f callbacks.awk -f JSON.awk - | grep dns_servers | awk -F ' ' '{print $2}' | tr -d \" | paste -d " " - -)

# CHECK IF WE NEED TO APPLY A DIRTY BUGFIX
if grep -q "wpa-conf" /etc/network/interfaces; then
        BUGFIX1=`grep "wpa-conf" /etc/network/interfaces`                               #SAVE THE wpa-conf LINE IN A VARIABLE SO WE CAN ADD IT LATER BACK TO THE FILE.
        sed -i 's/wpa-conf.*//' /etc/network/interfaces         #REMOVE THE wpa-conf LINE BECAUSE OUR CHANGE-INTERFACES AWK SCRIPT DOESNT HANDLE IT WELL
fi


#SWITCH TO BRIDGE MODE
if [ "$CURRENT_MODE" == "normal" ] && [ $BRIDGE == "on" ]; then

        # SET ETH0 TO MANUAL
        echo "Changing Interface eth0 to manual"
        awk -f $SCRIPT_DIR/changeInterface.awk /etc/network/interfaces dev=eth0 mode=manual > /tmp/tmp_interfaces

        # FOR SOME REASON WE CAN NOT WRITE TO THE /ETC/NETWORK/INTERFACES FILE DIRECTLY, SO WE DO IT THIS WAY, VIA A TMP FILE.
        cp /tmp/tmp_interfaces /etc/network/interfaces

        # NOW ADD THE BRIDGE INTERFACE
        #DO WE NEED TO ADD A BRIDGE WITH DHCP?
        if [ "$CURRENT_TYPE" == "dhcp" ]; then
                echo "Adding Bridge interface with DHCP"
                awk -f $SCRIPT_DIR/changeInterface.awk /etc/network/interfaces dev=br0 action=add mode=dhcp 'bridge_ports=eth0 tap0' > /tmp/tmp_interfaces
                #WHEN SETTING A BRIDGE TO DHCP, THE BRIDGE_PORTS CONFIGURATION IS LOST, SO ADD IT HERE
                echo "  bridge_ports eth0 tap0" >> /tmp/tmp_interfaces

        #OTHERWISE, ADD BRIDGE WITH STATIC IP
        else
                echo "Adding Bridge interface with Static IP"
                awk -f $SCRIPT_DIR/changeInterface.awk /etc/network/interfaces dev=br0 action=add mode=static 'bridge_ports=eth0 tap0' address=$CURRENT_IP_ADDRESS netmask=$CURRENT_SUBNET gateway=$CURRENT_GATEWAY "dns=$CURRENT_DNS_SERVERS" > /tmp/tmp_interfaces
        fi

        #SHOULD WE APPLY BUGFIX1?
        if [ -n "$BUGFIX1" ]; then
                echo $BUGFIX1 >> /tmp/tmp_interfaces
        fi

        # FOR SOME REASON WE CAN NOT WRITE TO THE /ETC/NETWORK/INTERFACES FILE DIRECTLY, SO WE DO IT THIS WAY, VIA A TMP FILE.
        cp /tmp/tmp_interfaces /etc/network/interfaces

        #SET THE ETH0 INTERFACE TO DOWN MANUALLY, THIS WILL REMOVE THE DHCP ADDRESS ON IT, WHEN WE RESTART NETWORKING, IT WILL COME UP WITHOUT IP (MANUAL)
        ip link set dev eth0 down

        #RESTART NETWORKING
        service networking restart

#SWITCH BACK TO NORMAL MODE
elif [ "$CURRENT_MODE" == "bridge" ] && [ $BRIDGE == "off" ]; then

        #REMOVE THE BRIDGE INTERFACE
        echo "Removing Bridge Interface"
        awk -f $SCRIPT_DIR/changeInterface.awk /etc/network/interfaces dev=br0 action=remove > /tmp/tmp_interfaces

       # FOR SOME REASON WE CAN NOT WRITE TO THE /ETC/NETWORK/INTERFACES FILE DIRECTLY, SO WE DO IT THIS WAY, VIA A TMP FILE.
        cp /tmp/tmp_interfaces /etc/network/interfaces

        # NOW CHANGE THE ETH0 INTERFACE
        #DO WE NEED TO CHANGE IT TO DHCP?
        if [ "$CURRENT_TYPE" == "dhcp" ]; then

                echo "Changing eth0 Interface to DHCP"
                awk -f $SCRIPT_DIR/changeInterface.awk /etc/network/interfaces dev=eth0 mode=dhcp > /tmp/tmp_interfaces

        #OTHERWISE, SET ETH0 WITH A STATIC IP
        else
                echo "Changing eth0 Interface to Static IP"
                awk -f $SCRIPT_DIR/changeInterface.awk /etc/network/interfaces dev=eth0 mode=static address=$CURRENT_IP_ADDRESS netmask=$CURRENT_SUBNET gateway=$CURRENT_GATEWAY "dns=$CURRENT_DNS_SERVERS" > /tmp/tmp_interfaces
        fi

        #SHOULD WE APPLY BUGFIX1?
        if [ -n "$BUGFIX1" ]; then
                echo $BUGFIX1 >> /tmp/tmp_interfaces
        fi

        # FOR SOME REASON WE CAN NOT WRITE TO THE /ETC/NETWORK/INTERFACES FILE DIRECTLY, SO WE DO IT THIS WAY, VIA A TMP FILE.
        cp /tmp/tmp_interfaces /etc/network/interfaces

        #FIRST, SET BRIDGE INTERFACE TO DOWN AND REMOVE BRIDGE
        ip link set dev br0 down
        brctl delbr br0

        #SECOND, NOW RESTART NETWORKING (IF WE DO IT THE OPPOSITE: RESTART NETWORKING AND THEN REMOVE THE BRIDGE, THE DEFAULT ROUTE WILL BE GONE)
        service networking restart

#NOTHING TO DO
elif [ "$CURRENT_MODE" == "bridge" ] && [ $BRIDGE == "on" ]; then
        echo "Nothing to do. We do not need to change to bridge mode since we are already running in bridge mode."

elif [ "$CURRENT_MODE" == "normal" ] && [ $BRIDGE == "off" ]; then
        echo "Nothing to do. We do not need to change to normal mode since we are already running in non-bridge mode."

fi
