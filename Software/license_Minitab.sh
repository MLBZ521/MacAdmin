#!/bin/bash

###################################################################################################
# Script Name:  license_Minitab.sh
# By:  Zack Thompson / Created:  3/6/2017
# Version:  1.1 / Updated:  1/10/2018 / By:  ZT
#
# Description:  This script applies the license for Minitab.
#
###################################################################################################

/usr/bin/logger -s "*****  License Minitab process:  START  *****"

##################################################
# Define Variables

licenseFile="/Library/Application Support/Minitab/Minitab Express/mtblic.plist"

##################################################
# Bits staged, license software...

/usr/bin/logger -s "Configuring the License Manager Server..."
/usr/bin/defaults write "${licenseFile}" "License File" @license.server.com

if [[ -e "${licenseFile}" ]]; then
	# Set permissions on the file for everyone to be able to read.
	/usr/bin/logger -s "Applying permissions to license file..."
	/bin/chmod 644 "${licenseFile}"
else
	/usr/bin/logger -s "ERROR:  Failed to create the license file!"
	/usr/bin/logger -s "*****  License Minitab process:  FAILED  *****"
	exit 1
fi

/usr/bin/logger -s "Minitab has been activated!"
/usr/bin/logger -s "*****  License Minitab process:  COMPLETE  *****"

exit 0
