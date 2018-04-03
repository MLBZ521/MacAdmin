#!/bin/bash

###################################################################################################
# Script Name:  license_Minitab.sh
# By:  Zack Thompson / Created:  3/6/2017
# Version:  1.1.1 / Updated:  3/30/2018 / By:  ZT
#
# Description:  This script applies the license for Minitab.
#
###################################################################################################

echo "*****  License Minitab process:  START  *****"

##################################################
# Define Variables

licenseFile="/Library/Application Support/Minitab/Minitab Express/mtblic.plist"

##################################################
# Bits staged, license software...

echo "Configuring the License Manager Server..."
/usr/bin/defaults write "${licenseFile}" "License File" @license.server.com

if [[ -e "${licenseFile}" ]]; then
	# Set permissions on the file for everyone to be able to read.
	echo "Applying permissions to license file..."
	/bin/chmod 644 "${licenseFile}"
else
	echo "ERROR:  Failed to create the license file!"
	echo "*****  License Minitab process:  FAILED  *****"
	exit 1
fi

echo "Minitab has been activated!"
echo "*****  License Minitab process:  COMPLETE  *****"

exit 0
