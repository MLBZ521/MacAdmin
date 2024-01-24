#!/bin/bash

###################################################################################################
# Script Name:  FixIt-CiscoSecureClientLaunchDaemon.sh
# By:  Zack Thompson / Created:  1/22/2024
# Version:  1.0.0 / Updated:  1/22/2024 / By:  ZT
#
# Description:  Fixes a known issue with the Cisco Secure Client installation process on
#     macOS Sonoma 14.2+.
#
###################################################################################################

echo -e "\n*****  Fix Cisco Secure Client LaunchDaemon Process:  START  *****\n"

##################################################
# Define Variables

launch_daemon="com.cisco.secureclient.vpnagentd.plist"
launch_daemon_location="/Library/LaunchDaemons/${launch_daemon}"
cisco_launch_daemon_location="/opt/cisco/secureclient/bin/Cisco Secure\
 Client - AnyConnect VPN Service.app/Contents/Resources/${launch_daemon}"

##################################################
# Bits staged...

if [[ -e "${cisco_launch_daemon_location}" ]]; then

	if [[ ! -e "${launch_daemon_location}" ]]; then
		echo "Staging LaunchDaemon..."
		/bin/cp "${cisco_launch_daemon_location}" "${launch_daemon_location}"
	fi

	echo "Bootstrapping LaunchDaemon..."
	/bin/launchctl bootstrap system "${launch_daemon_location}"

else
	echo "Missing required files -- was the Secure Client installed first?"
	echo -e "\n*****  Fix Cisco Secure Client LaunchDaemon Process:  FAILED  *****"
	exit 1
fi

echo -e "\n*****  Fix Cisco Secure Client LaunchDaemon Process:  COMPLETE  *****"
exit 0