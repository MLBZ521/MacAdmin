#!/bin/bash

###################################################################################################
# Script Name:  jamf_ea_HighSierraCompatibility.sh
# By:  Zack Thompson / Created:  9/26/2017
# Version:  1.0 / Updated:  9/26/2017 / By:  ZT
#
# Description:  A Jamf Extension Attribute to check the compatibly of macOS High Sierra.
#
#	Note:  System Requirements can be found here:  https://support.apple.com/en-us/HT201475
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
	if [[ $modelMajorVersion -ge $1 ]]; then
		echo "<result>True</result>"
	else
		echo "<result>False</result>"
	fi
}

##################################################
# Get machine info

# Get the OS Major Version
	osMinorVersion=$(sw_vers -productVersion | awk -F . '{print $2}')
# Get the Model Type and Major Version
	modelType=$(/usr/sbin/sysctl -n hw.model | sed 's/[^a-zA-Z]//g')
	modelMajorVersion=$(/usr/sbin/sysctl -n hw.model | sed 's/[^0-9,]//g' | awk -F, '{print $1}')
# Get RAM
	systemRAM=$(/usr/sbin/sysctl -n hw.memsize)
# Get free space on the boot disk
	systemFreeSpace=$(diskutil info / | awk -F '[()]' '/Free Space|Available Space/ {print $2}' | cut -d " " -f1)

##################################################
# Check for compatibility...

if [[ $osMinorVersion -ge 8 && $systemRAM -ge $requiredRAM && $systemFreeSpace -ge $requiredFreeSpace ]]; then

	case $modelType in
		"iMac" )
			# Function modelCheck
				modelCheck 10
			;;
		"MacBook" )
			# Function modelCheck
				modelCheck 6
			;;
		"MacBookPro" )
			# Function modelCheck
				modelCheck 7
			;;
		"MacBookAir" )
			# Function modelCheck
				modelCheck 3
			;;
		"MacMini" )
			# Function modelCheck
				modelCheck 4
			;;
		"MacPro" )
			# Function modelCheck
				modelCheck 5
			;;
	esac

else
	echo "<result>False</result>"
fi

exit 0