import subprocess


def change_ip(ip, network, gateway, dns):
    # network_interface = open("netconfig", "w")
    # content = ["IP Address \n", "Subnet Mask \n", "Gateway"]
    # network_interface.writeLines(content)
    # network_interface.close()
    subprocess.run(
        "scripts/change_ip.sh -t {} -a {} -n {} -g {} -d {}".format(
            ip, network, gateway, dns
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
