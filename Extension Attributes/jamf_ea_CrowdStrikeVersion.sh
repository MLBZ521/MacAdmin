#!/bin/bash

###################################################################################################
# Script Name:  jamf_ea_CrowdStrikeVersion.sh
# By:  Zack Thompson / Created:  1/8/2019
# Version:  1.0.0 / Updated:  1/8/2019 / By:  ZT
#
# Description:  This script gets the version of Crowd Strike.
#
###################################################################################################

echo "Checking the Crowd Strike Version..."

# Querty for the version string
csVersion=$( /usr/sbin/sysctl -n cs.version 2>&1 )

# Check if the command was successful
if [[ $? == "0" ]]; then
	echo "<result>${csVersion}</result>"
else
	echo "<result>Not installed or running</result>"
fi

exit 0