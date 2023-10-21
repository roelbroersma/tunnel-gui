# Tunnel GUI (T1)
_A very user-friendly VPN Tunnel for connecting multiple locations as it's ONE_

##Table of Contents
- [Overview](#overview)
- [Installing on a Rasperry Pi (method1)](#installing-on-a-raspberry-pi-2345-method-1))
- [Installing on a Rasperry/Odroid or other device (method2)](#installing-on-a-raspberry-pi-or-other-system-method-2))
- [Installing on Hyper-V/VMWare/VirtualBox or Proxmox](#installing-on-hyper-v-vmware-virtualbox-or-proxmox)
- [Installing manually](#installing-manually-on-you-LinuxDebianCentOSRHEL-machine)
- [Installing on Docker (for development purposes)](#running-on-docker-for-development-purposes)
- [Eplanation about the files](#explanation_about_the_files)
- [Contributing](#contributing)
- [License](#license)

## Overview
Use it for connecting your House to your vacation House and don't worry about networking: Use printers, Sonos devices, KNX or other Multicast protocols like it's ONE network.

The T1 is not limited to two locations. You can even connect several houses, boats and cars (with networking) as if it's ONE network. Simple and very private and secure! No need to buy expensive firewalls and struggle with complex configurations!

This Github project is the Web Interface. You can enroll it yourself or **buy a ready-to-go T1 device**. The T1 device works out of the box, comes with lifetime support and you support the project by buying it.

When you want to enroll it yourself, you can use a **physical device** like a Raspberry Pi or a **virtual device**, for example on Hyper-V.


## Installing on a Raspberry Pi 2/3/4/5 (method 1)
1. Download the latest version for Raspberry Pi from the Releases page.
2. Unpack the .zip file and use [balenaEtcher](https://www.balena.io/etcher/) to put the .iso on a microSD card.
3. Put the microSD card in the Pi, connect the Pi to your network using an ethernet cable and start the Pi. It might be convenient to attach a monitor and keyboard but it's not required.
4. After the whole unattended installation process finished, you can login to http://<ip address>:8080 using password: tunnel1. You can also login using SSH. Username: dietpi, Password: tunnel1

## Installing on a Raspberry Pi or other system (method 2)
We recommend setting up the Tunnel GUI on a Raspberry Pi 2/3/4. Running it on an Odroid or other devices which can run the DietPi image is possible and even devices with non-DietPi images might be possible but we still recommend the Raspberry Pi because of stability and because our developpers also use it.
1. Download the [DietPi](https://dietpi.com/) image for your device (eg. for Raspberry Pi 2/3/4 or Odroid)
2. Install the DietPi image to a MicroSD card using [balenaEtcher](https://www.balena.io/etcher/).
3. Copy the [modified dietpi.txt](https://github.com/roelbroersma/tunnel-gui/blob/main/dietpi.txt) to /boot/dietpi.txt on the microSD card. It will use it on first boot.
4. Startup your device with the microSD card with the the DietPi image.
5. When you startup your device, it will automatically obtain an IP address from DHCP and install the tunnel-gui. If it didn't got an address from DHCP, the tunnel-gui couldn't be installed and you have to do it manually by typing the following at the prompt:
`wget -q -O - https://github.com/roelbroersma/tunnel-gui/raw/main/install.txt | bash`
6. The tunnel-gui will automatically start at system boot. If you want to start/stop it manually, type `service t1service start` or `service t1service stop` which effectively starts or stops a `python3 app.py`
7. Navigate with your browser to: http://<ip address of Pi>:8080, the default password is tunnel1. If you change the password via the web interface, it will also change the password of the dietpi and root user.


## Installing on Hyper-V, VMWare, VirtualBox or Proxmox
1. Download the DietPi image for Hyper-V/VMWare/Virtualbox or Proxmox (yes, they supply separate images for this at www.dietpi.com
2. Create a new VM and supply the downloaded file.
3. Start the VM and login to the command prompt, then run the following: `wget -q -O - https://github.com/roelbroersma/tunnel-gui/raw/main/install.txt | bash`
This will download the latest repository and install all Python and Flask requiments. It will also create a default .env file, logfile and default password: tunnel1


## Installing manually on you Linux/Debian/CentOS/RHEL machine
1. Run `wget -q -O - https://github.com/roelbroersma/tunnel-gui/raw/main/install.txt | bash`.
2. Navigate to: http:///<ip address of Pi>:8080, the default password is `tunnel1` (or login with the password from the web_password.txt file). If you change the password via the web interface, it will also change the password of the dietpi and root user.


## Running on Docker (for development purposes)
You can download this repo to your own computer and run web-server locally in Docker container:
 1. You need to have installed Docker Desktop (https://www.docker.com/products/docker-desktop/)
 2. Run Docker Desktop
 3. Go to project's directory
 3. Create .env file (like in the paragraph above)
 4. Run `make -f Makefile run`
 5. You will be logged into container
 6. Run `make -f Makefile start`


## Explanation about the files
The following files need to be modified when checking out the project but they are automatically set for newly installed devices using the install script.
 1. A new file web_password.txt in project's directory with admin's password of RaspberryPI.
 2. An .env file with the following important values (See or renamce the example in .env.template file)
    * SECRET_KEY - Flask App Secret Key. It is used in the web gui for cross-site protection. You can change it freely.
    * DEBUG - True or False.
    * SUPER_PASSWORD - A super secret (backup) password so you can always login to the web gui. You can only change this password in this file.
    * OPENVPN_LOG_PATH - Set this to the log path as defined in openvpn config, default is: /var/log/openvpn/openvpn-status.log
    * PORT - The port the web application is running on, e.g. 8080. We use an alternative port because you probably want to run the tunnel itself at port 443.

All script files which interface with the backend (openvpn, pimd, mdns, bridge-tools, ip address changes, etc.) are located in the /scripts/ folder. These files are developped and tested for the DietPi image, however they may work on other Debian-based Linux installations and other Linux installations as well because we try to keep the backend very flexible.

Run the application with this command:
`make -f Makefile start_flask`

## Contributing
You can contribute to this project by buying a T1 device. 100% of the money is used to support this project.
Want to help coding or have a good idea? Use the [issue tracker](https://github.com/roelbroersma/tunnel-gui/issues) or send me an email at: info@roelbroersma.nl

# License
This project is open-source. You may use/distribute/change it for personal use.
It is not allowed to sell your own device with this software, if you want to do this, please contact me at: info@roelbroersma.nl

