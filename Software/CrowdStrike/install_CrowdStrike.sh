#!/bin/bash

###################################################################################################
# Script Name:  install_CrowdStrike.sh
# By:  Zack Thompson / Created:  1/8/2019
# Version:  1.1.0 / Updated:  11/18/2020 / By:  ZT
#
# Description:  This script installs and license CrowdStrike.
#
###################################################################################################

echo "*****  Install CrowdStrike Process:  START  *****"

##################################################
# Define Variables

# Unique customer ID checksum (CID)
licenseID="1234567890ABCDEF1234567890ABCDEF-12"

# Set working directory
pkgDir=$( /usr/bin/dirname "${0}" )

# Possible falconctl binary locations
falconctl_AppLocation="/Applications/Falcon.app/Contents/Resources/falconctl"
falconctl_OldLocation="/Library/CS/falconctl"

# Get the filename of the .pkg file
CrowdStrikePKG=$( /bin/ls "${pkgDir}" | /usr/bin/grep .pkg )

##################################################
# Bits staged...

# Install CrowdStrike
echo "Installing ${CrowdStrikePKG}..."
/usr/sbin/installer -dumplog -verbose -pkg "${pkgDir}/${CrowdStrikePKG}" -target /
exitCode=$?
/bin/sleep 2

# Verify installer exited successfully
if [[ $exitCode != 0 ]]; then

	echo "ERROR:  Install failed!"
	echo "Exit Code:  ${exitCode}"
	echo "*****  Install CrowdStrike process:  FAILED  *****"
	exit 1

fi

# Check which location exists
if  [[ -e "${falconctl_AppLocation}" && -e "${falconctl_OldLocation}" ]]; then

    # Multiple versions installed
	echo "ERROR:  Multiple versions installed!"
	echo "*****  Install CrowdStrike process:  FAILED  *****"
	exit 2

elif  [[ -e "${falconctl_AppLocation}" ]]; then

	# Apply License
	echo "Applying License..."
	exitStatus=$( "${falconctl_AppLocation}" license "${licenseID}" 2>&1 )
	exitCode=$?

elif  [[ -e "${falconctl_OldLocation}" ]]; then

	# Apply License
	echo "Applying License..."
	exitStatus=$( "${falconctl_OldLocation}" license "${licenseID}" 2>&1 )
	exitCode=$?

else

    # Could not find a version
	echo "ERROR:  Unable to locate falconctl!"
	echo "*****  Install CrowdStrike process:  FAILED  *****"
	exit 3

fi

# Verify licensing exit code
if [[ $exitCode == 0 ]]; then

	echo "License applied successfully!"

elif [[ $exitStatus == "Error: This machine is already licensed" ]]; then

	echo "This machine is already licensed!"

else

	echo "ERROR:  License failed to apply!"
	echo "Exit Code:  ${exitCode}"
	echo "Exit Status:  ${exitStatus}"
	echo "*****  Install CrowdStrike process:  FAILED  *****"
	exit 4

fi

echo "${CrowdStrikePKG} has been installed!"
echo "*****  Install CrowdStrike Process:  COMPLETE  *****"
exit 0