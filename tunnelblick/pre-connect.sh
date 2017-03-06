#!/bin/bash

# Script to make Tunnelblick work with OpenVPN with Yubikey.
#
# 1. Install Tunnelblick 3.7.0.  If you're switching from Viscosity, you may have to run:
#    $ sudo kextunload -b com.viscosityvpn.Viscosity.tun
# 2. Configure your VPN connection.
# 3. Copy this script (pre-connect.sh) to the VPN configuration directory for each VPN connection:
#    ~/Library/Application Support/Tunnelblick/Configurations/$VPN_CONNECTION.tblk/Contents/Resources
#    (where $VPN_CONNECTION is the name of your VPN connection).
#
# 4. Connect to the VPN.  On first run, you'll need to enter your username and password.  Once
#    these are cached in keychain, you'll only need to tap the YubiKey.

script="$(realpath $0)"
vpn_connection="$(echo $script | sed 's|.*/\([^/]*\)\.tblk/.*|\1|')"
keychain_get_cmd="/usr/bin/security find-generic-password -ws Tunnelblick-Auth-$vpn_connection"
keychain_set_cmd="/usr/bin/security add-generic-password -Us Tunnelblick-Auth-$vpn_connection"

# Tunnelblick pre-connect script will block the login dialog; to be able to populate the password
# field, it re-runs itself in the background, yielding control to Tunnelblick.
if [ "$1" != "bg" ]; then
    "$0" bg &
    exit
fi

# Store username or password in keychain if necessary and return it.
# Call with either "username" or "password".
function cache_in_keychain() {
  user_or_pwd="$1"
  value="$($keychain_get_cmd -a $user_or_pwd)"
  if [ -z "$value" ]; then
      value=$(osascript <<EOD
          tell application "Tunnelblick"
            display dialog "Enter your VPN $user_or_pwd to cache in keychain:" default answer ""
            set val to text returned of result
            return val
          end tell
          EOD
          )
      $keychain_set_cmd -a $user_or_pwd -w "$value"
  fi
  echo $value
}

username=$(cache_in_keychain "username")
password=$(cache_in_keychain "password")

# Configure Tunnelblick to read the username from keychain, but not the password.
defaults write net.tunnelblick.tunnelblick "$vpn_connection-keychainHasUsername" -bool YES
defaults write net.tunnelblick.tunnelblick "$vpn_connection-keychainHasPassword" -bool NO

# Get the Yubi token.
token=$(osascript <<EOD
tell application "Tunnelblick"
  display dialog "Tap your YubiKey to generate an OTP:" default answer ""
  set yubi_token to text returned of result
  return yubi_token
end tell
EOD
)

# Populate the password field with the password from keychain and the Yubi token appended.
# The keystore hack (letter by letter with shift key released) is needed due to a macOS bug:
# https://openradar.appspot.com/29825727
osascript <<EOD
tell application "Tunnelblick"
  delay 1
  tell application "System Events"
    repeat with letter in "$password$token"
        keystroke letter
        key up {shift}
    end repeat
    delay 0.5
    key code 36
  end tell
end tell
EOD
