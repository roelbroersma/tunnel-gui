#!/usr/bin/bash
#THIS SCRIPT IS WILL REBOOT THE DEVICE

sleep 5
if command -v reboot >/dev/null 2>&1; then
    #reboot
elif command -v shutdown >/dev/null 2>&1; then
    #shutdown -r now
else
    echo "Could not find a valid reboot command"
fi
