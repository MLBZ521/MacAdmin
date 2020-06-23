#!/bin/bash

###################################################################################################
# Script Name:  jamf_ea_LatestOSSupported.sh
# By:  Zack Thompson / Created:  9/26/2017
# Version:  1.7.0 / Updated:  3/23/2020 / By:  ZT
#
# Description:  A Jamf Extension Attribute to check the latest compatible version of macOS.
#
#	System Requirements can be found here:
#		Catalina - https://support.apple.com/en-us/HT201475
#		Mojave - https://support.apple.com/en-us/HT210190
#			* MacPro5,1's = https://support.apple.com/en-us/HT208898
#		High Sierra - https://support.apple.com/en-us/HT208969
#		Sierra - https://support.apple.com/kb/sp742
#		El Capitan - https://support.apple.com/kb/sp728
#
###################################################################################################

##################################################
# Define Variables

# Setting the minimum RAM and free disk space required for compatibility.
	minimumRAMMojaveOlder=2
	minimumRAMCatalina=4
	minimumFreeSpace=20 # This isn't completely accurate, but a minimum to start with.
# Transform GB into Bytes
	convertToGigabytes=$((1024 * 1024 * 1024))
	requiredRAMMojaveOlder=$(($minimumRAMMojaveOlder * $convertToGigabytes))
	requiredRAMCatalina=$(($minimumRAMCatalina * $convertToGigabytes))
	requiredFreeSpace=$(($minimumFreeSpace * $convertToGigabytes))
# Get the OS Version
	osVersion=$( /usr/bin/sw_vers -productVersion | /usr/bin/awk -F '.' '{print $2"."$3}' )
# Get the Model Type and Major Version
	modelType=$( /usr/sbin/sysctl -n hw.model | /usr/bin/sed 's/[^a-zA-Z]//g' )
	modelMajorVersion=$( /usr/sbin/sysctl -n hw.model | /usr/bin/sed 's/[^0-9,]//g' | /usr/bin/awk -F ',' '{print $1}' )
# Get RAM Info
	systemRAM=$( /usr/sbin/sysctl -n hw.memsize )
	RAMUpgradeable=$( /usr/sbin/system_profiler SPMemoryDataType | /usr/bin/awk -F "Upgradeable Memory: " '{print $2}' | /usr/bin/xargs )
# Get free space on the boot disk
	systemFreeSpace=$( /usr/sbin/diskutil info / | /usr/bin/awk -F '[()]' '/Free Space|Available Space/ {print $2}' | /usr/bin/cut -d " " -f1 )

##################################################
# Setup Functions

modelCheck() {

	if [[ $modelMajorVersion -ge $5 && $(/usr/bin/bc <<< "${osVersion} >= 8") -eq 1 ]]; then
		echo "Big Sur"
	elif [[ $modelMajorVersion -ge $4 && $(/usr/bin/bc <<< "${osVersion} >= 8") -eq 1 ]]; then
		echo "Catalina"
	elif [[ $modelMajorVersion -ge $3 && $(/usr/bin/bc <<< "${osVersion} >= 8") -eq 1 ]]; then
		echo "Mojave"
	elif [[ $modelMajorVersion -ge $2 && $(/usr/bin/bc <<< "${osVersion} >= 8") -eq 1 ]]; then
		echo "High Sierra"
	elif [[ $modelMajorVersion -ge $2 && $(/usr/bin/bc <<< "${osVersion} >= 7.5") -eq 1 ]]; then
		echo "Sierra / OS Limitation"  # (Current OS Limitation, 10.13 Compatible)
	elif [[ $modelMajorVersion -ge $1 && $(/usr/bin/bc <<< "${osVersion} >= 6.8") -eq 1  ]]; then
		echo "El Capitan"
	else
		echo "<result>Current OS Not Supported</result>"
		exit 0
	fi

}

# Because Apple had to make Mojave support for MacPro's difficult...  I have to add complexity to the original "simplistic" logic in this script.
macProModelCheck() {

	if [[ $modelMajorVersion -ge $4 ]]; then
		# For MacPro 6,1 (2013/Trash Cans), these should be supported no matter the existing state, since they wouldn't be compatible with any OS that is old, nor have incompatible hardware.
		echo "Catalina"

	elif [[ $modelMajorVersion -ge $3 && $(/usr/bin/bc <<< "${osVersion} >= 13.6") -eq 1 ]]; then
		# Supports Mojave, but required Metal Capabable Graphics Cards and FileVault must be disabled.
		macProResult="Mojave"

		# Check if the Graphics Card supports Metal
		if [[ $( /usr/sbin/system_profiler SPDisplaysDataType | /usr/bin/awk -F 'Metal: ' '{print $2}' | /usr/bin/xargs ) != *"Supported"* ]]; then
			macProResult+=" / GFX unsupported"
		fi

		# Check if FileVault is enabled
		if [[ $( /usr/bin/fdesetup status | /usr/bin/awk -F 'FileVault is ' '{print $2}' | /usr/bin/xargs ) != "Off." ]]; then
			macProResult+=" / FV Enabled"
		fi

		echo "${macProResult}"

	elif [[ $modelMajorVersion -ge $3 && $(/usr/bin/bc <<< "${osVersion} <= 13.6") -eq 1 ]]; then
		# Supports Mojave or newer, but requires a stepped upgrade path .

		echo "High Sierra / OS Limitation"

	elif [[ $modelMajorVersion -ge $2 && $(/usr/bin/bc <<< "${osVersion} >= 7.5") -eq 1 ]]; then
		echo "Sierra / OS Limitation"  # (Current OS Limitation, 10.13 Compatible)

	elif [[ $modelMajorVersion -ge $1 && $(/usr/bin/bc <<< "${osVersion} >= 6.8") -eq 1  ]]; then
		echo "El Capitan"

	fi
}

##################################################
# Check for compatibility...

# Each number passed to the below functions is the major model version for the model type.
# The first parameter is for El Capitan, the second is for High Sierra, the third is for Mojave, and the forth is for Catalina.
case $modelType in
	"iMac" )
		# Function modelCheck
		latestOSSupport=$( modelCheck 7 10 13 13 15 )
	;;
	"MacBook" )
		# Function modelCheck
		latestOSSupport=$( modelCheck 5 6 8 8 8 )
	;;
	"MacBookPro" )
		# Function modelCheck
		latestOSSupport=$( modelCheck 3 6 9 9 11 )
	;;
	"MacBookAir" )
		# Function modelCheck
		latestOSSupport=$( modelCheck 2 3 5 5 6 )
	;;
	"Macmini" )
		# Function modelCheck
		latestOSSupport=$( modelCheck 3 4 6 6 7 )
	;;
	"MacPro" )
		# Function modelCheck
		latestOSSupport=$( macProModelCheck 3 5 5 6 6 )
	;;
	"iMacPro" )
		# Function modelCheck
		latestOSSupport=$( modelCheck 1 1 1 1 1 )
	;;
	* )
		echo "<result>Model No Longer Supported</result>"
		exit 0
	;;
esac

finalResult="<result>${latestOSSupport}"

# RAM validation check
if [[ "${latestOSSupport}" == "Catalina" ]]; then
	# Based on model, device supports Catalina

	if [[ $systemRAM -lt $requiredRAMCatalina ]]; then
		# Based on RAM, device does not have enough to support Catalina

		if [[ "${RAMUpgradeable}" == "No" ]]; then
			# Device is not upgradable, so can never suppport Catalina

			if [[ $systemRAM -ge $requiredRAMMojaveOlder ]]; then
				# Device has enough RAM to support Mojave
				latestOSSupport="Mojave"
			else
				# Device does not have enough RAM to support any upgrade!?
				echo "<result>Not Upgrableable</result>"
				exit 0
			fi

		else
			# Device does not have enough RAM to upgrade currently, but RAM capacity can be increased.
			finalResult+="Insufficient RAM"
		fi

	fi

else
	# Based on model, device supports Mojave or older

	if [[ $systemRAM -lt $requiredRAMMojaveOlder ]]; then
		# Based on RAM, device does not have enough to upgrade

		if [[ "${RAMUpgradeable}" == "No" ]]; then
			# Device does not have enough RAM to support any upgrade!?
			echo "<result>Not Upgrableable</result>"
			exit 0

		else
			# Device does not have enough RAM to upgrade currently, but RAM capacity can be increased.
			finalResult+=" / Insufficient RAM"

		fi

	fi

fi

# Check if the available free space is sufficient
if [[ $systemFreeSpace -lt $requiredFreeSpace ]]; then
	finalResult+=" / Insufficient Storage"
fi

echo "${finalResult}</result>"

exit 0
