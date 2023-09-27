#!/usr/bin/bash
#THIS SCRIPT WILL SET/UPDATE AND RENEW VPN KEYS
echo "INPUT: $@" > /tmp/temp1.txt
# USAGE FUNCTION
usage() {
        echo "Usage: change_keys -s [server machine ID]
                   -c [client machine ID, you can give multiple IDs using: -c xxxxxx -c yyyyy -c zzzzz]
                   -r [regenerate all keys, only in combination with -s because it will also regenerate the server key. This will also generate the CA]
" 1>&2
}

#INTERNAL VARIABLES
server_id=""
client_ids=()
regen_all=false
easyrsa_dir="/etc/openvpn/easy-rsa/"


# EXIT ERROR FUNCTION
exit_abnormal() {
	echo ""
	usage
        exit 1
}

# CHECK FOR ARGUMENTS
if [ "$#" -eq 0 ]; then
    usage
fi

# CHECK THE -b ARGUMENT, SEE IF WE NEED TO SET TO SET THE BRIDGE ON OR OFF
while getopts ":s:c:r" options; do
        case "${options}" in
                s)
                  server_id=${OPTARG}
                  ;;
		c)
		  client_ids+=("${OPTARG}")
		  ;;
		r)
		  regen_all=true
		  ;;
		*)
		  usage
		  ;;
		\?)
		  echo "ERROR: Invalid Option: -$OPTARG"
		  exit_abnormal
		  ;;
                :)
                  echo "ERROR: Option -$OPTARG requires the machine ID as argument, e.g.: JKHJLKJGKL876545LJKGHJKJ"
                  echo ""
                  exit_abnormal
		  ;;
        esac
done

#CHECK IF REGEN ARGUMENT IS GIVEN WITHOUT A SERVER MACHINE ID
if [ "$regen_all" = true ] && [ -z "$server_id" ]; then
  echo "ERROR: -r is given without -s option. When regenerating all certs and keys, at least the server machine ID must be given."
  exit_abnormal
fi



# CHECK SERVER ID AND EXECUTE ACTION
if [ -n "$server_id" ]; then
    if [ "$regen_all" = true ]; then
        echo "Regenerating all keys for server"
	#DELETE OPEN-CA DIRECTORY
        [ -d "${easyrsa_dir}openvpn-ca" ] && rm -r ${easyrsa_dir}openvpn-ca
    fi

    #CHECK IF OPENVPN-CA FOLDER EXSITS, IF NOT, CREATE IT
    if [ ! -d "${easyrsa_dir}openvpn-ca" ]; then
      echo "Creating CA"
      make-cadir ${easyrsa_dir}openvpn-ca

      cd ${easyrsa_dir}openvpn-ca
 
      #SET THESE DEFAULTS (30 YEARS=10958 DAYS)
      echo "set_var EASYRSA_KEY_SIZE		2048" > vars
      echo "set_var EASYRSA_CA_EXPIRE		10958" >> vars
      echo "set_var EASYRSA_CERT_EXPIRE		10958" >> vars
      #USE ELLIPTIC CURVE VARIANT INSTEAD OF DIFFIE-HELLMAN FILE, THIS REQUIRES LESS CPU
      echo "set_var EASYRSA_ALGO		ec" >> vars
      echo "set_var EASYRSA_CURVE		prime256v1" >> vars

      #INITIALIZE PKI
      ./easyrsa --batch --vars=${easyrsa_dir}openvpn-ca/vars init-pki

      #CREATE NEW CA CERTIFICATE
      EASYRSA_REQ_CN="TunnelT1" ./easyrsa --batch --vars=${easyrsa_dir}openvpn-ca/vars build-ca nopass
    fi

    cd ${easyrsa_dir}openvpn-ca

    #CHECK IF SERVER FOLDER EXISTS AND IF NOT, CREATE IT
    [ ! -d "server" ] && mkdir server
 
    #CHECK IF CERT EXISTS, IF NOT CREATE IT
    if [ ! -f "server/server.crt" ]; then
	#DELETE CONTENTS OF THE SERVER FOLDER SO ANY PREVIOUS SERVER CERTS ARE DELETED
	rm -r server/*

	# GENERATE SERVER CERT AND KEY	
	echo "Creating Server Certificate and Key for: ${server_id}"
	./easyrsa --batch --req-cn=$server_id --vars=${easyrsa_dir}openvpn-ca/vars gen-req server nopass
    	./easyrsa --batch --vars=${easyrsa_dir}openvpn-ca/vars sign-req server server

	# MOVE CREATED CERT AND KEY TO SERVER FOLDER
	mv pki/issued/server.crt server/
	mv pki/private/server.key server/
else
    	#CERT ALREADY EXISTS, DO NOTHING
	:
   fi
fi



if [ "${#client_ids[@]}" -gt 0 ]; then
  #CHECK IF A SERVER CERTIFICATE EXISTS, IF NOT, ERROR
  if [ ! -d "${easyrsa_dir}openvpn-ca/" ] || [ $(find "${easyrsa_dir}openvpn-ca/" -maxdepth 1 -type f 2>/dev/null | wc -l) -lt 2 ]; then
    echo "ERROR: This is the FIRST TIME this command is running, please specify a server machine ID so we can build a CA."
    exit_abnormal
  fi

  cd ${easyrsa_dir}openvpn-ca

  #CHECK IF CLIENT FOLDER EXISTS AND IF NOT, CREATE IT
  [ ! -d "client" ] && mkdir client

  #LOOP THROUGH CLIENT MACHINE IDs
  for client_id in "${client_ids[@]}"; do
    #ONLY DO IF CLIENT CERT DOES NOT ALREADY EXISTS
    if [ ! -f "client/${client_id}.crt" ]; then
	# GENERATE CLIENT CERT AND KEY
        echo "Creating Client Certificate and Key for: ${client_id}"
        ./easyrsa --batch --req-cn=$client_id --vars=${easyrsa_dir}openvpn-ca/vars gen-req $client_id nopass
	./easyrsa --batch --vars=${easyrsa_dir}openvpn-ca/vars sign-req client $client_id

        # MOVE CREATED CERT AND KEY TO SERVER FOLDER
        mv pki/issued/$client_id.crt client/
        mv pki/private/$client_id.key client/

	#FOR SOME STUPID REASON WE NEED TO REMOVE THE METADATA FROM THE CERTIFICATE, EASYRSA ALWAYS DOES THIS AND OPENVPN WILL NOT HANDLE IT WHEN PLACING INLINE
	sed -i -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' client/$client_id.crt

    fi
  done
fi


