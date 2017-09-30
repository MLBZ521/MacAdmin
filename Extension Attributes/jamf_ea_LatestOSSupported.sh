#!/bin/bash

###################################################################################################
# Script Name:  jamf_ea_LatestOSSupported.sh
# By:  Zack Thompson / Created:  9/26/2017
# Version:  1.0 / Updated:  9/29/2017 / By:  ZT
#
# Description:  A Jamf Extension Attribute to check the latest compatible version of macOS.
#
#	System Requirements can be found here:  
#		High Sierra - https://support.apple.com/en-us/HT201475
#		Sierra - https://support.apple.com/kb/sp742
#		El Capitan - https://support.apple.com/kb/sp728
#
###################################################################################################

##################################################
# Define Variables

# Setting the minimum RAM and free disk space required for compatibility (opting for 4GB instead of 2GB)
	minimumRAM=4
	minimumFreeSpace=15
# Transform GB into Bytes
	convertToGigabytes=$((1024 * 1024 * 1024))
	requiredRAM=$(($minimumRAM * $convertToGigabytes))
	requiredFreeSpace=$(($minimumFreeSpace * $convertToGigabytes))

##################################################
# Setup Functions

function modelCheck {
	if [[ $modelMajorVersion -ge $1 && $osVersion -ge 10.8 ]]; then
		echo "<result>High Sierra</result>"
	if [[ $modelMajorVersion -ge $1 && $osVersion -ge 10.7.5 ]]; then
		echo "<result>Sierra</result>"  # (Current OS Limitation, 10,13 Compatible)
	elif [[ $modelMajorVersion -ge $2 && $osVersion -ge 10.6.8 ]]; then
		echo "<result>El Capitan</result>"
	else
		echo "<result>Model or Current OS Not Supported</result>"
	fi
}

##################################################
# Get machine info

# Get the OS Version
	osVersion=$(sw_vers -productVersion)
# Get the Model Type and Major Version
	modelType=$(/usr/sbin/sysctl -n hw.model | sed 's/[^a-zA-Z]//g')
	modelMajorVersion=$(/usr/sbin/sysctl -n hw.model | sed 's/[^0-9,]//g' | awk -F, '{print $1}')
# Get RAM
	systemRAM=$(/usr/sbin/sysctl -n hw.memsize)
# Get free space on the boot disk
	systemFreeSpace=$(diskutil info / | awk -F '[()]' '/Free Space|Available Space/ {print $2}' | cut -d " " -f1)

##################################################
# Check for compatibility...

if [[ $systemRAM -ge $requiredRAM && $systemFreeSpace -ge $requiredFreeSpace ]]; then

	# First parameter is for High Sierra, the second parameter is for El Capitan, to check compatible HW models.
	case $modelType in
		"iMac" )
			# Function modelCheck
				modelCheck 10 7
			;;
		"MacBook" )
			# Function modelCheck
				modelCheck 6 5
			;;
		"MacBookPro" )
			# Function modelCheck
				modelCheck 7 3
			;;
		"MacBookAir" )
			# Function modelCheck
				modelCheck 3 2
			;;
		"MacMini" )
			# Function modelCheck
				modelCheck 4 3
			;;
		"MacPro" )
			# Function modelCheck
				modelCheck 5 3
			;;
	esac

else
	echo "<result>Insufficient Resources</result>"
fi

exit 0