#!/bin/bash

###################################################################################################
# Script Name:  jamf_ea_CrowdStrikeVersion.sh
# By:  Zack Thompson / Created:  1/8/2019
# Version:  1.1.0 / Updated:  1/30/2019 / By:  ZT
#
# Description:  This script gets the version of Crowd Strike, if installed.
#
###################################################################################################

echo "Checking if Crowd Strike is installed..."

if [[ -e "/Library/CS/falconctl" ]]

	# Querty for the version string
	echo "Checking the Crowd Strike Version..."
	csVersion=$( /usr/sbin/sysctl -n cs.version 2>&1 )

	# Check if the command was successful
	if [[ $? == "0" ]]; then
		echo "<result>${csVersion}</result>"
	else
		echo "<result>Not Running</result>"
	fi

else
	echo "<result>Not Installed</result>"
fi

exit 0