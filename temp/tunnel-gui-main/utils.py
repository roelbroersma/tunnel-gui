import base64
import os
from pathlib import Path
import json
import subprocess
import requests
import io
import zipfile

BASE_DIR = Path(__file__).parent
SCRIPT_DIR = BASE_DIR / 'scripts/'
CONFIG_DIR = BASE_DIR / "configs\/" 
DEFAULT_EXECUTABLE = '/bin/bash'
IP_CONFIG_FILE = 'ip_config.json'
UPDATE_FILE = "https://github.com/roelbroersma/tunnel-gui/archive/refs/heads/main.zip"

class IpAddressChangeInfo:
    def __init__(self, ip_type, ip_address, dns_servers, subnet, gateway):
        self.ip_type = ip_type
        self.ip_address = ip_address
        self.dns_servers = dns_servers
        self.subnet = subnet
        self.gateway = gateway

    def to_json(self):
        data = {
            'ip_type': self.ip_type,
            'ip_address': self.ip_address,
            'subnet': self.subnet,
            'dns_servers': self.dns_servers,
            'gateway': self.gateway
        }
        return json.dumps(data, indent=4)

    @classmethod
    def from_json(cls, json_string):
        data = json.loads(json_string)
        return cls(
            ip_type=data['ip_type'],
            ip_address=data['ip_address'],
            subnet=data['subnet'],
            dns_servers=data['dns_servers'],
            gateway=data['gateway']
        )

    @classmethod
    def from_script_output(cls, output):
        # Result from show_ip.sh script should be json string
        try:
            data = json.loads(output)
            return cls(
                ip_type=data['ip_type'],
                ip_address=data['ip_address'],
                subnet=data['subnet'],
                dns_servers=data['dns_servers'],
                gateway=data['gateway']
            )
        except Exception as e:
            print('PROBLEM: ')
            print(e)
            print(output)
            return cls(
                ip_type='',
                ip_address='',
                subnet='',
                dns_servers='',
                gateway=''
            )


def change_ip(ip_address_info):
    try:
        subprocess.run(
            str(SCRIPT_DIR / "change_ip.sh") +\
            " -t {} -a {} -n {} -g {} -d {}".format(
                ip_address_info.ip_type,
                ip_address_info.ip_address,
                ip_address_info.subnet,
                ip_address_info.gateway,
                ip_address_info.dns_servers
            ),
            shell=True,
            executable=DEFAULT_EXECUTABLE,
        )
    except:
        pass


def show_ip():
    try:
        result = subprocess.run(str(SCRIPT_DIR / "show_ip.sh"), shell=True, executable=DEFAULT_EXECUTABLE, capture_output=True)
        output = result.stdout.decode('utf-8')
        return IpAddressChangeInfo.from_script_output(output)
    except:
        pass


class PublicIpInfo:
    def __init__(self, public_ipv4, public_ipv6):
        self.public_ipv4 = public_ipv4
        self.public_ipv6 = public_ipv6

    @classmethod
    def from_script_output(cls, output):
        # Result from show_public_ip.sh script should be json string
        try:
            data = json.loads(output)
            return cls(
                public_ipv4=data['public_ipv4'],
                public_ipv6=data['public_ipv6']
            )
        except Exception as e:
            print('PROBLEM: ')
            print(e)
            print(output)
            return cls(
                public_ipv4='',
                public_ipv6=''
            )


def show_public_ip():
    try:
        result = subprocess.run(str(SCRIPT_DIR / "show_public_ip.sh"), shell=True, executable=DEFAULT_EXECUTABLE, capture_output=True )
        output = result.stdout.decode('utf-8')
        return PublicIpInfo.from_script_output(output)
    except:
        pass


def do_change_password(new_password):
    try:
        subprocess.run(str(SCRIPT_DIR / "do_change_password.sh") + f" {new_password} root", shell=True, executable=DEFAULT_EXECUTABLE )
        subprocess.run(str(SCRIPT_DIR / "do_change_password.sh") + f" {new_password} dietpi", shell=True, executable=DEFAULT_EXECUTABLE )
        subprocess.run(str(SCRIPT_DIR / "save_password.sh") + f" {new_password}", shell=True, executable=DEFAULT_EXECUTABLE )
    except:
        pass


def get_token(password):
    message_bytes = password.encode('ascii')
    base64_bytes = base64.b64encode(message_bytes)
    base64_message = base64_bytes.decode('ascii')
    return base64_message


def get_passwords():
    super_password = os.getenv('SUPER_PASSWORD', None)

    with open(BASE_DIR / "web_password.txt", "r+") as f:
        web_password = f.read().strip()
    return [web_password, super_password]


def generate_keys(server, clients, regenerate=False):
    command = [str(SCRIPT_DIR / "change_keys.sh")]

    if server:
        command.extend(["-s", str(server)])

    for client in clients:
        command.extend(["-c", str(client)])

    if regenerate:
        command.extend(["-r"])
    command_str = " ".join(command)
    subprocess.run(command_str, shell=True, executable=DEFAULT_EXECUTABLE)


def generate_server_config(bridge, public_ip_or_ddns, protocol, port, server_networks, clients, features):
    try:
        command = [str(SCRIPT_DIR / "change_vpn.sh")]

        command.extend(["-t", "server"])
        command.extend(["-b", str(bridge)])
        command.extend (["-h", str(public_ip_or_ddns)])
        command.extend (["-p", str(protocol)])
        command.extend (["-n", str(port)])

        for server_network in server_networks:
            network_str = f"{server_network['server_network']}-{server_network['server_subnet']}"
            command.extend(["-s", str(network_str)])


        for client in clients:
            client_id = client['client_id']
            for client_network in client['client_networks']:
                client_str = f"{client_id}-{client_network['client_network']}-{client_network['client_subnet']}"
                command.extend(["-c", str(client_str)])

        for feature in features:
            command.extend(["-f", str(feature)])

        command_str = " ".join(command)

        subprocess.run(command_str, shell=True, executable=DEFAULT_EXECUTABLE)
        return True

    except:
        return False


def generate_client_config():
    try:
        command = [str(SCRIPT_DIR / "change_vpn.sh")]
        command.extend(["-t", "client"])
        command_str = " ".join(command)
        subprocess.run(command_str, shell=True, executable=DEFAULT_EXECUTABLE)
        return True
    except:
        return False


def save_tunnel_configuration(data):
    with open(CONFIG_DIR / "t1config.json", "w") as server_config_file:
        json.dump(data, server_config_file, indent=2)


def load_device_type():
    if os.path.exists(CONFIG_DIR / "t1config.json"):
        try:
            with open(server_conf_file, 'r') as file:
                return "master"
        except:
            return "notMaster"
    else:
        return "notMaster"



def load_tunnel_configuration(form):
    if os.path.exists(CONFIG_DIR / "t1config.json"):
        try:
            with open(server_conf_file, 'r') as file:
                config_data = json.load(file)
                #print(config_data)

                # GET GENERAL TUNNEL CONFIG AND SET IT TO THE FORM
                form.tunnel_type.data = config_data["tunnel_type"]
                form.public_ip_or_ddns_hostname.data = config_data["public_ip_or_ddns_hostname"]
                form.tunnel_port.data = config_data["tunnel_port"]
                form.protocol.data = config_data["protocol"]
                form.mdns.data = config_data["mdns"]
                form.pimd.data = config_data["pimd"]
                form.stp.data = config_data["stp"]

                # EMTY MASTER FORM (OTHERWISE IT HAS A NEW LINE)
                form.master_networks.pop_entry()
                # LOOP THROUGH THE SERVER NETWORKS ANS SET THEM AS DEFAULT TO THE FORM
                for i, server_network in enumerate(config_data["master_networks"]):
                    form.master_networks.append_entry()
                    form.master_networks[i].server_network.data = server_network["server_network"]
                    form.master_networks[i].server_subnet.data = server_network["server_subnet"]

                #EMPTY CLIENTS (OTHERWISE IT HAS A NEW LINE)
                form.clients.pop_entry()
                # LOOP THROUGH CLIENTS AND SET THEM AS DEFAULT TO THE FORM
                for i, client in enumerate(config_data["clients"]):
                    form.clients.append_entry()
                    form.clients[i].client_id.data = client["client_id"]

                    #CLEAR CLIENT NETWORKS FORM FOR EACH CLIENT (OTHERWISE IT HAS A NEW LINE)
                    form.clients[i].client_networks.pop_entry()
                    # AND ALSO LOOP THROUGH THE CLIENT NETWORKS FOR EACH CLIENT
                    for j, client_network in enumerate(client["client_networks"]):
                        form.clients[i].client_networks.append_entry()
                        form.clients[i].client_networks[j].client_network.data = client_network["client_network"]
                        form.clients[i].client_networks[j].client_subnet.data = client_network["client_subnet"]

        except FileNotFoundError:
            print(f"Config file '{server_conf_file}' not found.")
        except json.JSONDecodeError as e:
            print(f"Fout bij het decoderen van JSON: {e}")
    else:
        #THIS IS THE DEFAULT IF NO FILE CAN BE LOADED
        print(f"Config file '{server_conf_file}' does not exist.")
        form.public_ip_or_ddns_hostname.data = json.loads(subprocess.Popen(SCRIPT_DIR / "show_public_ip.sh", stdout=subprocess.PIPE).communicate()[0])["public_ipv4"]
        form.mdns.data = True

    return form

    # IF AN ERRORS OCCURS OR THE CONFIG FILE DOES NOT EXIST, RETURN AN EMPTY DICTIONARY
    return {}


def handle_uploaded_file(file):
    if file:
        filename=file.filename
        file.save(CONFIG_DIR / "client_config.zip")
        print("File succesfully saved!")
        return True
    else:
        print("No file part")
        return False



def core_upgrade(action):
    if action in ["now", "auto", "manual"]:
        command = [str(SCRIPT_DIR / "core_upgrade.sh")]
        command.extend(["-u", action])
        command_str = " ".join(command)
        subprocess.Popen(command_str, shell=True, executable=DEFAULT_EXECUTABLE)

def app_upgrade(action):
    if action in ["now"]:
        command = [str(SCRIPT_DIR / "app_upgrade.sh")]
        command.extend(["-u", action])
        command_str = " ".join(command)
        subprocess.Popen(command_str, shell=True, executable=DEFAULT_EXECUTABLE)

def do_reboot():
    subprocess.run([str(SCRIPT_DIR / "do_reboot.sh")], shell=True, executable=DEFAULT_EXECUTABLE)
    

def get_version(type="local"):
    if type in ["local", "remote", "all"]:
        pass
    else:
        type = "local"

    result = "{}"
    try:
        result = json.loads(subprocess.Popen([str(SCRIPT_DIR / "show_version.sh"), '-l', type ], stdout=subprocess.PIPE).communicate()[0])
    except:
        result = "{}"

    return result

