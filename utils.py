import base64
import os
from pathlib import Path
import subprocess

BASE_DIR = Path(__file__).parent
IP_CONFIG_FILE = 'ip_config.json'


def change_ip(ip_address_info):
    # network_interface = open("netconfig", "w")
    # content = ["IP Address \n", "Subnet Mask \n", "Gateway"]
    # network_interface.writeLines(content)
    # network_interface.close()
    with open(BASE_DIR / IP_CONFIG_FILE, 'w+') as f:
        f.write(ip_address_info.to_json())

    subprocess.run(
        "scripts/change_ip.sh -t {} -a {} -n {} -g {} -d {}".format(
            ip_address_info.static_or_dhcp,
            ip_address_info.ip_address,
            ip_address_info.subnet_mask,
            ip_address_info.gateway,
            ip_address_info.dns_address
        ),
        shell=True,
    )
    # subprocess.run(["mv", network_interface, "/etc/"])
    # subprocess.run(["systemctl", "restart", "netctl"])


def do_change_password(new_password):
    # subprocess.run("scripts/do_change_password.sh {} {}".format(new_password, "tunnel_demo"), shell=True)
    subprocess.run(
        "scripts/do_change_password.sh {} {}".format(new_password, "root"), shell=True
    )
    subprocess.run(
        "scripts/do_change_password.sh {} {}".format(new_password, "dietpi"), shell=True
    )
    subprocess.run(
        f"scripts/save_password.sh {new_password}", shell=True
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
