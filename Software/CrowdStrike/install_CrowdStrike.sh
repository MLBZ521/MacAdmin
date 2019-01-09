#!/bin/bash

###################################################################################################
# Script Name:  install_CrowdStrike.sh
# By:  Zack Thompson / Created:  1/8/2019
# Version:  1.0.0 / Updated:  1/8/2019 / By:  ZT
#
# Description:  This script installs and licenes CrowdStrike.
#
###################################################################################################

echo "*****  Install CrowdStrike Process:  START  *****"

##################################################
# Define Variables

# Unique customer ID checksum (CID)
licenseID="1234567890ABCDEF1234567890ABCDEF-12"
# Set working directory
pkgDir=$(/usr/bin/dirname "${0}")
# Get the filename of the .pkg file
CrowdStrikePKG=$( /bin/ls "${pkgDir}" | /usr/bin/grep .pkg )

##################################################
# Bits staged...

# Install CrowdStrike
echo "Installing ${CrowdStrikePKG}..."
/usr/sbin/installer -dumplog -verbose -pkg "${pkgDir}/${CrowdStrikePKG}" -target /
exitCode=$?
/bin/sleep 2

if [[ $exitCode == 0 ]]; then
	# Apply License
	echo "Applying License..."
	exitStatus=$( /Library/CS/falconctl license $licenseID 2>&1 )
	exitCode=$?

	if [[ $exitCode == 0 ]]; then
		echo "License applied successfully!"
	elif [[ $exitStatus == "Error: This machine is already licensed" ]]; then
		echo "This machine is already licensed!"
	else
		echo "ERROR:  License failed to apply!"
		echo "Exit Code:  ${exitCode}"
		echo "Exit Status:  ${exitStatus}"
		echo "*****  Install CrowdStrike process:  FAILED  *****"
		exit 2
	fi
else
	echo "ERROR:  Install failed!"
	echo "Exit Code:  ${exitCode}"
	echo "*****  Install CrowdStrike process:  FAILED  *****"
	exit 1
fi

echo "${CrowdStrikePKG} has been installed!"
echo "*****  Install CrowdStrike Process:  COMPLETE  *****"

exit 0