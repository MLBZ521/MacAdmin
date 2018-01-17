#!/bin/bash

###################################################################################################
# Script Name:  license_Maple.sh
# By:  Zack Thompson / Created:  1/8/2018
# Version:  1.1 / Updated:  1/17/2018 / By:  ZT
#
# Description:  This script applies the license for Maple applications.
#
###################################################################################################

/usr/bin/logger -s "*****  License Maple process:  START  *****"

##################################################
# Define Variables

# Determine License Mechanism
	case "${4}" in
		"LM" | "License Manager" | "Network" )
			licenseMechanism="Network"
			;;
		"Stand Alone" | "Local" )
			licenseMechanism="Local"
			;;
		* )
			/usr/bin/logger -s "ERROR:  Invalid License Mechanism provided"
			/usr/bin/logger -s "*****  License Maple process:  FAILED  *****"
			exit 1
			;;
	esac

	/usr/bin/logger -s "Licensing Mechanism:  ${licenseMechanism}"

##################################################
# Bits staged, license software...

# If the machine has multiple Maple Applications, loop through them...
/usr/bin/find /Applications -iname "Maple*.app" -maxdepth 1 -type d | while IFS="\n" read -r appPath; do

	# Get the Maple version
		majorVersion=$(/usr/bin/defaults read "${appPath}/Contents/Info.plist" CFBundleShortVersionString | /usr/bin/awk -F "." '{print $1}')
		/usr/bin/logger -s "Applying License for Major Version:  ${majorVersion}"

	# Location of the License File
		licenseFile="/Library/Frameworks/Maple.framework/Versions/${majorVersion}/license/license.dat"

	if [[ -d "${appPath}" ]]; then

		if [[ $licenseMechanism == "Network" ]]; then

			/usr/bin/logger -s "Creating license file..."
			/usr/bin/logger -s "Setting the License Manager Server..."

			/bin/cat > "${licenseFile}" <<licenseContents
#
# License File for network installations
#
SERVER license.server.com ANY 11000
USE_SERVER
# This file is used by Maple to determine which server
# the FLEXlm daemon (lmgrd) is installed on.
# You should not have to edit this file directly.
licenseContents

			# Set permissions on the file for everyone to be able to read.
				/usr/bin/logger -s "Applying permissions to license file..."
				/bin/chmod 644 "${licenseFile}"

		elif [[ $licenseMechanism == "Local" ]]; then

			# Assign the proper license per edition
			case "${majorVersion}" in
				"2017" )
					licenseCode="201712345678910"
					;;
				"2016" )
					licenseCode="201612345678910"
					;;
				"2015" )
					licenseCode="201512345678910"
					;;
			esac

	# Apply License Code
	exitStatus=$(
expect - <<activateLicense
set timeout 1
spawn /Library/Frameworks/Maple.framework/Versions/2016/bin/activation -console
expect "Do you access the internet through a proxy server?" { send "no\r" }
expect "Please enter your purchase code: " { send "${licenseCode}\r" }
expect "First Name* []: " { send "First\r" }
expect "Middle Initial []: " { send "\r" }
expect "Last Name* []: " {send "Last\r" }
expect "Email address* []: " { send "email@email.com\r" }
expect "Phone Number []: " { send "\r" }
expect "Address 1 []: " { send "\r" }
expect "Address 2 []: " { send "\r" }
expect "City []: " { send "Tempe\r" }
expect "Province or State []: " { send "AZ\r" }
expect "Country* []: " { send "USA\r" }
expect "Postal Code []: " { send "\r" }
expect "The Maple Reporter (Professional Edition) []: " { send "\r" }
expect "The Maple Reporter (Academic Edition) []: " { send "\r" }
expect "Upcoming Events and Seminars []: " { send "\r" }
expect "Special Product Announcements []: " { send "\r" }
interact
activateLicense
)

			if [[ $exitStatus == *"Activation successful!"* ]]; then
				/usr/bin/logger -s "License Code applied successfully!"
			else
				/usr/bin/logger -s "ERROR:  Failed to apply License Code"
				/usr/bin/logger -s "ERROR Contents:  ${exitStatus}"
				/usr/bin/logger -s "*****  License Maple process:  FAILED  *****"
				exit 3
			fi
		fi

	else
		/usr/bin/logger -s "A version of Maple was not located in the expected location!"
		/usr/bin/logger -s "*****  License Maple process:  FAILED  *****"
		exit 2
	fi

/usr/bin/logger -s "Maple has been activated!"
/usr/bin/logger -s "*****  License Maple process:  COMPLETE  *****"

exit 0
