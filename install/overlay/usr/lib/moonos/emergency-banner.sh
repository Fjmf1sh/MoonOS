#!/bin/bash
# Friendly full-screen message shown when Moon Shell and recovery both fail
# to start. Printed to tty1 just before the login prompt.
{
    printf '\033[H\033[2J'                 # home + clear
    printf '\033[38;5;147m'                # moonlight accent
    cat <<'BANNER'

        M O O N   O S

   Moon OS could not start the interface.

   This is almost always a software issue, not your Pi.
   Your paired PCs and settings are safe.

   What to do:
     * Log in with your normal Raspberry Pi OS user and read:
         sudo journalctl -u moon-shell -u moon-recovery --no-pager

     * To try again from here:
         sudo systemctl restart moon-shell

     * Try updating Moon OS:
         sudo systemctl start moon-update && sudo reboot

     * To wipe settings and start fresh:
         sudo touch /var/lib/moonos/.factory-reset && sudo reboot

BANNER
    printf '\033[0m'
} > /dev/tty1 2>/dev/null
