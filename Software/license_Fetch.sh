#!/bin/sh

###################################################################################################
# Script Name:  license_Fetch.sh
# By:  Zack Thompson / Created:  6/28/2017
# Version:  1.1.1 / Updated:  3/30/2018 / By:  ZT
#
# Description:  This script will license Fetch.
#
###################################################################################################

echo "*****  license Fetch Process:  START  *****"

##################################################
# Define Variables
FetchApp="/Applications/Fetch.app"
plist="/Library/Preferences/com.fetchsoftworks.Fetch.License"
registrantName="Customer Name"
serialNumber="FETCH12345-6789-0123-4567-8910-1112"

##################################################
# Bits staged...

if [[ ! -x $FetchApp ]]; then
	echo "Error:  Fetch is not properly installed."
	echo "*****  license Fetch Process:  FAILED  *****"
	exit 1
else
	echo "Applying the Fetch license..."
	/usr/bin/defaults write $plist SerialNumber "$serialNumber"
	/usr/bin/defaults write $plist RegistrantName "$registrantName"

	if [[ -e $plist ]]; then
		echo "Fetch has been licensed!"
		echo "*****  license Fetch Process:  COMPLETE  *****"
	else
		echo "Error:  License does not exist."
		echo "*****  license Fetch Process:  FAILED  *****"
		exit 2
	fi
fi

exit 0