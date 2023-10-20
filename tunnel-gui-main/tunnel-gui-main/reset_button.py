import time
from gpiozero import Button
import subprocess

# DEFINE PIN ON WHICH THE RESET BUTTON IS CONNECTED
button = Button(2)  # Dit is GPIO2, pas aan naar uw configuratie

def reset_system():
    print("System will reset to factory defaults...")
    subprocess.run(["/scripts/reset_factory_defaults.sh"], shell=True)

def check_button():
    while True:
        # WAIT FOR BUTTON PRESS
        button.wait_for_press()
        press_time = time.time()
        # WAIT FOR BUTTON RELEASE
        button.wait_for_release()
        release_time = time.time()
        # CHECK IF BUTTON IS PRESSED LONGER THAN 10 SECONDS
        if release_time - press_time > 10:
            reset_system()

if __name__ == "__main__":
    check_button()
