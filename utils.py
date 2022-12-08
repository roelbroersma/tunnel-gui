import base64
import os
from pathlib import Path
import json
import subprocess

BASE_DIR = Path(__file__).parent
DEFAULT_EXECUTABLE = '/bin/bash'
IP_CONFIG_FILE = 'ip_config.json'


class IpAddressChangeInfo:
    def __init__(self, static_or_dhcp, ip_address, dns_address, subnet_mask, gateway):
        self.static_or_dhcp = static_or_dhcp
        is_static = self.static_or_dhcp == 'static'
        def or_empty(val):
            return val if is_static else ''
        self.ip_address = or_empty(ip_address)
        self.dns_address = or_empty(dns_address)
        self.subnet_mask = or_empty(subnet_mask)
        self.gateway = or_empty(gateway)

    def to_json(self):
        data = {
            'staticOrDhcp': self.static_or_dhcp,
            'ipAddress': self.ip_address,
            'subnetMask': self.subnet_mask,
            'dnsAddress': self.dns_address,
            'gateway': self.gateway
        }
        return json.dumps(data, indent=4)

    @classmethod
    def from_json(cls, json_string):
        data = json.loads(json_string)
        return cls(
            static_or_dhcp=data['staticOrDhcp'],
            ip_address=data['ipAddress'],
            subnet_mask=data['subnetMask'],
            dns_address=data['dnsAddress'],
            gateway=data['gateway']
        )

    @classmethod
    def from_script_output(cls, output):
        # Result from show_ip.sh script should be json string
        try:
            data = json.loads(output)
            return cls(
                static_or_dhcp=data['type'],
                ip_address=data['ip_address'],
                subnet_mask=data['subnet'],
                dns_address=data['dns_servers'][0],
                gateway=data['gateway']
            )
        except Exception as e:
            print('PROBLEM: ')
            print(e)
            print(output)
            return cls(
                static_or_dhcp='',
                ip_address='',
                subnet_mask='',
                dns_address='',
                gateway=''
            )


def change_ip(ip_address_info):
    # network_interface = open("netconfig", "w")
    # content = ["IP Address \n", "Subnet Mask \n", "Gateway"]
    # network_interface.writeLines(content)
    # network_interface.close()
    with open(BASE_DIR / IP_CONFIG_FILE, 'w+') as f:
        f.write(ip_address_info.to_json())

    subprocess.run(
        str(BASE_DIR / "scripts/change_ip.sh") +\
        " -t {} -a {} -n {} -g {} -d {}".format(
            ip_address_info.static_or_dhcp,
            ip_address_info.ip_address,
            ip_address_info.subnet_mask,
            ip_address_info.gateway,
            ip_address_info.dns_address
        ),
        shell=True,
        executable=DEFAULT_EXECUTABLE,
    )
    # subprocess.run(["mv", network_interface, "/etc/"])
    # subprocess.run(["systemctl", "restart", "netctl"])


def show_ip():
    result = subprocess.run(
        str(BASE_DIR / "scripts/show_ip.sh"),
        shell=True,
        executable=DEFAULT_EXECUTABLE,
        capture_output=True,
    )
    output = result.stdout
    return IpAddressChangeInfo.from_script_output(output)


def do_change_password(new_password):
    # subprocess.run("scripts/do_change_password.sh {} {}".format(new_password, "tunnel_demo"), shell=True)
    subprocess.run(
        str(BASE_DIR / "scripts/do_change_password.sh") +\
        f" {new_password} root",
        shell=True,
        executable=DEFAULT_EXECUTABLE,
    )
    subprocess.run(
        str(BASE_DIR / "scripts/do_change_password.sh") +\
        f" {new_password} dietpi",
        shell=True,
        executable=DEFAULT_EXECUTABLE,
    )
    subprocess.run(
        str(BASE_DIR / f"scripts/save_password.sh") + f" {new_password}",
        shell=True,
        executable=DEFAULT_EXECUTABLE,
    )


def get_token(password):
    message_bytes = password.encode('ascii')
    base64_bytes = base64.b64encode(message_bytes)
    base64_message = base64_bytes.decode('ascii')
    return base64_message


def get_passwords():
    super_password = os.getenv('SUPER_PASSWORD', None)

    BASE_DIR = Path(__file__).resolve().parent
    with open(BASE_DIR / "web_password.txt", "r+") as f:
        web_password = f.read().strip()
    return [web_password, super_password]
