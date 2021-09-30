#!/bin/bash
# set -x

###################################################################################################
# Script Name:  jamf_ea_LatestOSSupported.sh
# By:  Zack Thompson / Created:  9/26/2017
# Version:  1.11.0c / Updated:  9/30/2021 / By:  ZT
#
# Description:  A Jamf Extension Attribute to check the latest compatible version of macOS.
#
#	System Requirements can be found here:
#		Monterey - https://www.apple.com/macos/monterey-preview/
#		Big Sur - https://support.apple.com/en-us/HT211238
# 			* If you’re running Mountain Lion 10.8, you will need to upgrade to El Capitan 10.11 first.
#		Catalina - https://support.apple.com/en-us/HT210222
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
	minimumRAMCatalinaPlus=4
	minimumFreeSpace=20 # This isn't the technical specification for pervious versions, just a suggestion
	minimumFreeSpaceBigSur=35.5 # For 10.12 or newer
# Transform GB into Bytes
	convertToGigabytes=$((1024 * 1024 * 1024))
	requiredRAMMojaveOlder=$((minimumRAMMojaveOlder * convertToGigabytes))
	requiredRAMCatalinaPlus=$((minimumRAMCatalinaPlus * convertToGigabytes))
	requiredFreeSpace=$((minimumFreeSpace * convertToGigabytes))
	requiredFreeSpaceBigSur=$( /usr/bin/bc <<< "${minimumFreeSpaceBigSur} * ${convertToGigabytes}" )
# Get the OS Version
	osVersion=$( /usr/bin/sw_vers -productVersion )
	osMajorVersion=$( echo "${osVersion}" | /usr/bin/awk -F '.' '{print $1}' )
	osMinorPatchVersion=$( echo "${osVersion}" | /usr/bin/awk -F '.' '{print $2"."$3}' )
# Get the Model Type and Major Version
	modelType=$( /usr/sbin/sysctl -n hw.model | /usr/bin/sed 's/[^a-zA-Z]//g' )
	modelVersion=$( /usr/sbin/sysctl -n hw.model | /usr/bin/sed 's/[^0-9,]//g' )
	modelMajorVersion=$( echo "${modelVersion}" | /usr/bin/awk -F ',' '{print $1}' )
	modelMinorVersion=$( echo "${modelVersion}" | /usr/bin/awk -F ',' '{print $2}' )
# Get RAM Info
	systemRAM=$( /usr/sbin/sysctl -n hw.memsize )
	RAMUpgradeable=$( /usr/sbin/system_profiler SPMemoryDataType | /usr/bin/awk -F "Upgradeable Memory: " '{print $2}' | /usr/bin/xargs )
# Get free space on the boot disk
	systemFreeSpace=$( /usr/sbin/diskutil info / | /usr/bin/awk -F '[()]' '/Free Space|Available Space/ {print $2}' | /usr/bin/cut -d " " -f1 )

##################################################
# Setup Functions

modelCheck() {

	if [[ $modelMajorVersion -ge $6 && ( $(/usr/bin/bc <<< "${osMajorVersion} >= 11") -eq 1 || $(/usr/bin/bc <<< "${osMinorPatchVersion} >= 9") -eq 1 ) ]]; then
		echo "Monterey"
	elif [[ $modelMajorVersion -ge $5 && ( $(/usr/bin/bc <<< "${osMajorVersion} >= 11") -eq 1 || $(/usr/bin/bc <<< "${osMinorPatchVersion} >= 9") -eq 1 ) ]]; then
		echo "Big Sur"
	elif [[ $modelMajorVersion -ge $4 && $(/usr/bin/bc <<< "${osMinorPatchVersion} >= 9") -eq 1 ]]; then
		echo "Catalina"
	elif [[ $modelMajorVersion -ge $4 && $(/usr/bin/bc <<< "${osMinorPatchVersion} <= 8") -eq 1 ]]; then
		echo "Mojave / OS Limitation"  # (Current OS Limitation, 10.15 Catalina)
	elif [[ $modelMajorVersion -ge $3 && $(/usr/bin/bc <<< "${osMinorPatchVersion} >= 8") -eq 1 ]]; then
		echo "Mojave"
	elif [[ $modelMajorVersion -ge $2 && $(/usr/bin/bc <<< "${osMinorPatchVersion} >= 8") -eq 1 ]]; then
		echo "High Sierra"
	elif [[ $modelMajorVersion -ge $2 && $(/usr/bin/bc <<< "${osMinorPatchVersion} >= 7.5") -eq 1 ]]; then
		echo "Sierra / OS Limitation"  # (Current OS Limitation, 10.13 Compatible)
	elif [[ $modelMajorVersion -ge $1 && $(/usr/bin/bc <<< "${osMinorPatchVersion} >= 6.8") -eq 1  ]]; then
		echo "El Capitan"
	else
		echo "Current OS Not Supported"
	fi

}

# Apple just had to make two MacBookPro models (11,4 & 11,5) support Monterey...
MacBookProModelCheck() {

	if [[ $modelMajorVersion -ge $6 && ( $(/usr/bin/bc <<< "${osMajorVersion} >= 11") -eq 1 || $(/usr/bin/bc <<< "${osMinorPatchVersion} >= 9") -eq 1 ) ]]; then
		echo "Monterey"
	elif [[ $modelMajorVersion -eq $5 && ( $(/usr/bin/bc <<< "${osMajorVersion} >= 11") -eq 1 || $(/usr/bin/bc <<< "${osMinorPatchVersion} >= 9") -eq 1 ) ]]; then
		if [[ $modelMinorVersion -ge 4 ]]; then
			echo "Monterey"
		else
			echo "Big Sur"
		fi
	elif [[ $modelMajorVersion -ge $4 && $(/usr/bin/bc <<< "${osMinorPatchVersion} >= 9") -eq 1 ]]; then
		echo "Catalina"
	elif [[ $modelMajorVersion -ge $4 && $(/usr/bin/bc <<< "${osMinorPatchVersion} <= 8") -eq 1 ]]; then
		echo "Mojave / OS Limitation"  # (Current OS Limitation, 10.15 Catalina Compatible)
	elif [[ $modelMajorVersion -ge $3 && $(/usr/bin/bc <<< "${osMinorPatchVersion} >= 8") -eq 1 ]]; then
		echo "Mojave"
	elif [[ $modelMajorVersion -ge $2 && $(/usr/bin/bc <<< "${osMinorPatchVersion} >= 8") -eq 1 ]]; then
		echo "High Sierra"
	elif [[ $modelMajorVersion -ge $2 && $(/usr/bin/bc <<< "${osMinorPatchVersion} >= 7.5") -eq 1 ]]; then
		echo "Sierra / OS Limitation"  # (Current OS Limitation, 10.13 Compatible)
	elif [[ $modelMajorVersion -ge $1 && $(/usr/bin/bc <<< "${osMinorPatchVersion} >= 6.8") -eq 1  ]]; then
		echo "El Capitan"
	else
		echo "Current OS Not Supported"
	fi

}

# Apple just had to make one iMac model (14,4) support Big Sur...
iMacModelCheck() {

	if [[ $modelMajorVersion -ge $6 && ( $(/usr/bin/bc <<< "${osMajorVersion} >= 11") -eq 1 || $(/usr/bin/bc <<< "${osMinorPatchVersion} >= 9") -eq 1 ) ]]; then
		echo "Monterey"
	elif [[ $modelMajorVersion -eq $5 && ( $(/usr/bin/bc <<< "${osMajorVersion} >= 11") -eq 1 || $(/usr/bin/bc <<< "${osMinorPatchVersion} >= 9") -eq 1 ) ]]; then
		if [[ $modelMinorVersion -ge 4 ]]; then
			echo "Big Sur"
		else
			echo "Catalina"
		fi
	elif [[ $modelMajorVersion -ge $4 && $(/usr/bin/bc <<< "${osMinorPatchVersion} >= 9") -eq 1 ]]; then
		echo "Catalina"
	elif [[ $modelMajorVersion -ge $4 && $(/usr/bin/bc <<< "${osMinorPatchVersion} <= 8") -eq 1 ]]; then
		echo "Mojave / OS Limitation"  # (Current OS Limitation, 10.15 Catalina Compatible)
	elif [[ $modelMajorVersion -ge $3 && $(/usr/bin/bc <<< "${osMinorPatchVersion} >= 8") -eq 1 ]]; then
		echo "Mojave"
	elif [[ $modelMajorVersion -ge $2 && $(/usr/bin/bc <<< "${osMinorPatchVersion} >= 8") -eq 1 ]]; then
		echo "High Sierra"
	elif [[ $modelMajorVersion -ge $2 && $(/usr/bin/bc <<< "${osMinorPatchVersion} >= 7.5") -eq 1 ]]; then
		echo "Sierra / OS Limitation"  # (Current OS Limitation, 10.13 Compatible)
	elif [[ $modelMajorVersion -ge $1 && $(/usr/bin/bc <<< "${osMinorPatchVersion} >= 6.8") -eq 1  ]]; then
		echo "El Capitan"
	else
		echo "Current OS Not Supported"
	fi

}

# Because Apple had to make Mojave support for MacPro's difficult...  I have to add complexity to the original "simplistic" logic in this script.
macProModelCheck() {

	if [[ $modelMajorVersion -ge $5 ]]; then
		# For MacPro 6,1 (2013/Trash Cans) and newer, these should be supported no matter the existing state, since they wouldn't be compatible with any OS that is old, nor have incompatible hardware.
		echo "Monterey"

	elif [[ $modelMajorVersion -ge $3 && $(/usr/bin/bc <<< "${osMinorPatchVersion} >= 13.6") -eq 1 ]]; then
		# Supports Mojave, but required Metal Capable Graphics Cards and FileVault must be disabled.
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

	elif [[ $modelMajorVersion -ge $3 && $(/usr/bin/bc <<< "${osMinorPatchVersion} <= 13.5") -eq 1 ]]; then

		echo "High Sierra / OS Limitation"  # Supports Mojave or newer, but requires a stepped upgrade path

	elif [[ $modelMajorVersion -ge $2 && $(/usr/bin/bc <<< "${osMinorPatchVersion} >= 7.5") -eq 1 ]]; then
		echo "Sierra / OS Limitation"  # (Current OS Limitation, 10.13 Compatible)

	elif [[ $modelMajorVersion -ge $1 && $(/usr/bin/bc <<< "${osMinorPatchVersion} >= 6.8") -eq 1  ]]; then
		echo "El Capitan"

	fi
}

##################################################
# Check for compatibility...

# Each number passed to the below functions is the minimum major model version for the model type.
	# The first parameter is for El Capitan, 
	# the second is for High Sierra, 
	# the third is for Mojave, 
	# the forth is for Catalina, 
	# the fifth is for Big Sur,
	# and the sixth is for Monterey
case $modelType in
	"iMac" )
		# Function iMacModelCheck
		latestOSSupport=$( iMacModelCheck 7 10 13 13 14 16 )
	;;
	"MacBook" )
		# Function modelCheck
		latestOSSupport=$( modelCheck 5 6 8 8 8 9 )
	;;
	"MacBookPro" )
		# Function modelCheck
		latestOSSupport=$( MacBookProModelCheck 3 6 9 9 11 12 )
	;;
	"MacBookAir" )
		# Function modelCheck
		latestOSSupport=$( modelCheck 2 3 5 5 6 7 )
	;;
	"Macmini" )
		# Function modelCheck
		latestOSSupport=$( modelCheck 3 4 6 6 7 7 )
	;;
	"MacPro" )
		# Function macProModelCheck
		latestOSSupport=$( macProModelCheck 3 5 5 6 6 6 )
	;;
	"iMacPro" )
		# Function modelCheck
		latestOSSupport=$( modelCheck 1 1 1 1 1 1 )
	;;
	* )
		echo "<result>Model No Longer Supported</result>"
		exit 0
	;;
esac

finalResult="<result>${latestOSSupport}"

# RAM validation check
if [[ "${latestOSSupport}" == "Catalina" || "${latestOSSupport}" == "Big Sur" || "${latestOSSupport}" == "Monterey" ]]; then
	# Based on model, device supports Catalina or newer

	if [[ $systemRAM -lt $requiredRAMCatalinaPlus ]]; then
		# Based on RAM, device does not have enough to support Catalina or newer

		if [[ "${RAMUpgradeable}" == "No" ]]; then
			# Device is not upgradable, so can never support Catalina or newer

			if [[ $systemRAM -ge $requiredRAMMojaveOlder ]]; then
				# Device has enough RAM to support Mojave
				latestOSSupport="Mojave"
			else
				# Device does not have enough RAM to support any upgrade!?
				echo "<result>Not Upgradable</result>"
				exit 0
			fi

		else
			# Device does not have enough RAM to upgrade currently, but RAM capacity can be increased.
			finalResult+=" / Insufficient RAM"
		fi

	fi

else
	# Based on model, device supports Mojave or older

	if [[ $systemRAM -lt $requiredRAMMojaveOlder ]]; then
		# Based on RAM, device does not have enough to upgrade

		if [[ "${RAMUpgradeable}" == "No" ]]; then
			# Device does not have enough RAM to support any upgrade!?
			echo "<result>Not Upgradable</result>"
			exit 0

		else
			# Device does not have enough RAM to upgrade currently, but RAM capacity can be increased.
			finalResult+=" / Insufficient RAM"

		fi

	fi

fi

# Check if the available free space is sufficient
if [[ "${latestOSSupport}" == "Big Sur" || "${latestOSSupport}" == "Monterey" ]]; then

	if [[  $( /usr/bin/bc <<< "${systemFreeSpace} <= ${requiredFreeSpaceBigSur}" ) -eq 1 ]]; then
		finalResult+=" / Insufficient Storage"

	fi

elif [[  $( /usr/bin/bc <<< "${systemFreeSpace} <= ${requiredFreeSpace}" ) -eq 1 ]]; then
	finalResult+=" / Insufficient Storage"

fi

echo "${finalResult}</result>"

exit 0
