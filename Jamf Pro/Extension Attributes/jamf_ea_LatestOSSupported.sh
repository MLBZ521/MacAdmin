#!/bin/bash

###################################################################################################
# Script Name:  jamf_ea_LatestOSSupported.sh
# By:  Zack Thompson / Created:  9/26/2017
# Version:  1.4.1 / Updated:  8/6/2017 / By:  ZT
#
# Description:  A Jamf Extension Attribute to check the latest compatible version of macOS.
#
#	System Requirements can be found here:  
#		Mojave - (https://developer.apple.com/)
#		High Sierra - https://support.apple.com/en-us/HT201475
#		Sierra - https://support.apple.com/kb/sp742
#		El Capitan - https://support.apple.com/kb/sp728
#
###################################################################################################

##################################################
# Define Variables

# Setting the minimum RAM and free disk space required for compatibility (opting for 4GB instead of 2GB)
	minimumRAM=4
	minimumFreeSpace=20
# Transform GB into Bytes
	convertToGigabytes=$((1024 * 1024 * 1024))
	requiredRAM=$(($minimumRAM * $convertToGigabytes))
	requiredFreeSpace=$(($minimumFreeSpace * $convertToGigabytes))

##################################################
# Setup Functions

modelCheck() {
	if [[ $modelMajorVersion -ge $1 && $(/usr/bin/bc <<< "${osVersion} >= 8") -eq 1 ]]; then
		echo "<result>Mojave</result>"
	elif [[ $modelMajorVersion -ge $2 && $(/usr/bin/bc <<< "${osVersion} >= 8") -eq 1 ]]; then
		echo "<result>High Sierra</result>"
	elif [[ $modelMajorVersion -ge $2 && $(/usr/bin/bc <<< "${osVersion} >= 7.5") -eq 1 ]]; then
		echo "<result>Sierra</result>"  # (Current OS Limitation, 10.13 Compatible)
	elif [[ $modelMajorVersion -ge $3 && $(/usr/bin/bc <<< "${osVersion} >= 6.8") -eq 1  ]]; then
		echo "<result>El Capitan</result>"
	else
		echo "<result>Model or Current OS Not Supported</result>"
	fi
}

##################################################
# Get machine info

# Get the OS Version
	osVersion=$(/usr/bin/sw_vers -productVersion | /usr/bin/awk -F '.' '{print $2"."$3}')
# Get the Model Type and Major Version
	modelType=$(/usr/sbin/sysctl -n hw.model | /usr/bin/sed 's/[^a-zA-Z]//g')
	modelMajorVersion=$(/usr/sbin/sysctl -n hw.model | /usr/bin/sed 's/[^0-9,]//g' | /usr/bin/awk -F, '{print $1}')
# Get RAM
	systemRAM=$(/usr/sbin/sysctl -n hw.memsize)
# Get free space on the boot disk
	systemFreeSpace=$(/usr/sbin/diskutil info / | /usr/bin/awk -F '[()]' '/Free Space|Available Space/ {print $2}' | /usr/bin/cut -d " " -f1)

##################################################
# Check for compatibility...

if [[ $systemRAM -ge $requiredRAM && $systemFreeSpace -ge $requiredFreeSpace ]]; then

	# First parameter is for Mojave, the second parameter is for High Sierra, and the third for El Capitan, to check compatible HW models.
	case $modelType in
		"iMac" )
			# Function modelCheck
			modelCheck 13 10 7
		;;
		"MacBook" )
			# Function modelCheck
			modelCheck 8 6 5
		;;
		"MacBookPro" )
			# Function modelCheck
			modelCheck 9 7 3
		;;
		"MacBookAir" )
			# Function modelCheck
			modelCheck 5 3 2
		;;
		"Macmini" )
			# Function modelCheck
			modelCheck 6 4 3
		;;
		"MacPro" )
			# Function modelCheck
			modelCheck 5 5 3
		;;
		"iMacPro" )
			# Function modelCheck
			modelCheck 1 1
		;;
		* )
			echo "<result>Unknown Model</result>"
		;;
	esac

else
	echo "<result>Insufficient Resources</result>"
fi

exit 0