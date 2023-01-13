# Tunnel GUI (T1)
This is a very user friendly VPN Tunnel. Use it for connecting your House to your vacation House and don't worry about networking: Use printers, Sonos devices, KNX or other Multicast protocols like it's ONE network.

The T1 is not limited to two locations. You can even connect several houses, boats and cars (with networking) as if it's ONE network. Simple and very private and secure! No need to buy expensive firewalls and struggle with complex configurations!

This Github project is the Web Interface. You can enroll it yourself or **buy a ready-to-go T1 device from ..here..todo..** It works out of the box and in case you need any support, give us a ring and we are happy to help you until it works, also in weekends!

When you want to enroll it yourself, you can use a **physical device** like a Raspberry Pi or a **virtual device** like VM on Hyper-V.


## Running on a Physical device (T1)
We recommend setting up the Tunnel GUI on a Raspberry Pi 2/3/4. Running it on an Odroid or other devices which can run the DietPi image is possible and even devices with non-DietPi images might be possible but we still recommend the Raspberry Pi because of stability and because our developpers also use it.
1. Download the [DietPi](https://dietpi.com/ image for your device) (eg. for Raspberry Pi 2/3/4)
2. Install the DietPi image to a MicroSD card.
3. Copy the modified dietpi.txt from ..here..todo...  to the /boot/dietpi.txt  (it will use it on first boot)
4. Startup your device with the DietPi image.
5. When you startup your device, it will automatically obtain an IP address from DHCP and install the tunnel-gui. If it didn't got an address from DHCP, the tunnel-gui couldn't be installed and you have to do it manually by typing the following at the prompt:
#+begin_src shell
  wget -q -O - https://github.com/roelbroersma/tunnel-gui/raw/main/install.txt | bash  at the shell
#+end_src


## Running on Hyper-V
1. Download the DietPi image for Hyper-V
2. Run the following at the prompt:
#+begin_src shell
  wget -q -O - https://github.com/roelbroersma/tunnel-gui/raw/main/install.txt | bash  at the shell
#+end_src


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
    1. SECRET_KEY - secret value for web-project
    2. DEBUG - True or False.
    3. SUPER_PASSWORD - password value for web admin's purposes (web-project allows login with this password or with RaspberryPI password)
    4. LOG_PATH - path to file which tail will be showed on IP Address page
    5. PORT - The port the application is running on, like 80 or 8080

All script files which interface with the backend (openvpn, pimd, mdns, bridge-tools, ip address changes, etc.) are located in the /scripts/ folder. These files are developped and tested for the DietPi image, however they may work on other Debian-based Linux installations and other Linux installations as well because we try to keep the backend very flexible.

Run the application with this command:
#+begin_src shell
  make -f Makefile start_flask
#+end_src