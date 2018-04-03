#!/bin/bash

###################################################################################################
# Script Name:  license_Maple.sh
# By:  Zack Thompson / Created:  1/8/2018
# Version:  1.5.2 / Updated:  3/30/2018 / By:  ZT
#
# Description:  This script applies the license for Maple applications.
#
###################################################################################################

echo "*****  License Maple process:  START  *****"

##################################################
# Turn on case-insensitive pattern matching
shopt -s nocasematch

# Determine License Mechanism
	case "${4}" in
		"LM" | "License Manager" | "Network" )
			licenseMechanism="Network"
			;;
		"Stand Alone" | "Local" )
			licenseMechanism="Local"
			;;
		* )
			echo "ERROR:  Invalid License Mechanism provided"
			echo "*****  License Maple process:  FAILED  *****"
			exit 1
			;;
	esac

# Turn off case-insensitive pattern matching
shopt -u nocasematch

	echo "Licensing Mechanism:  ${licenseMechanism}"

##################################################
# Bits staged, license software...

# Find all install Maple versions.
appPaths=$(/usr/bin/find -E /Applications -iregex ".*Maple [0-9]{4}[.]app" -maxdepth 2 -type d -prune)

# Verify that a Maple version was found.
if [[ -z "${appPaths}" ]]; then
	echo "A version of Maple was not found in the expected location!"
	echo "*****  License Maple process:  FAILED  *****"
	exit 2
else
	# If the machine has multiple Maple Applications, loop through them...
	while IFS="\n" read -r appPath; do

		# Get the Maple version
			majorVersion=$(/usr/bin/defaults read "${appPath}/Contents/Info.plist" CFBundleShortVersionString | /usr/bin/awk -F "." '{print $1}')
			echo "Applying License for Major Version:  ${majorVersion}"

		# Location of the License File
			licenseFile="/Library/Frameworks/Maple.framework/Versions/${majorVersion}/license/license.dat"

		if [[ -d "${appPath}" ]]; then

			if [[ $licenseMechanism == "Network" ]]; then
				echo "Configuring the License Manager Server..."

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
/usr/bin/expect - <<activateLicense
set timeout 1
spawn /Library/Frameworks/Maple.framework/Versions/$majorVersion/bin/activation -console
expect "Do you access the internet through a proxy server?" { send "no\r" }
expect "Please enter your purchase code" { send "${licenseCode}\r" }
expect "First Name*" { send "First\r" }
expect "Middle Initial" { send "\r" }
expect "Last Name*" { send "Last\r" }
expect "Email address*" { send "email@email.com\r" }
expect "Phone Number" { send "\r" }
expect "Address 1" { send "\r" }
expect "Address 2" { send "\r" }
expect "City" { send "Tempe\r" }
expect "Province or State" { send "AZ\r" }
expect "Country*" { send "USA\r" }
expect "Postal Code" { send "\r" }
expect "The Maple Reporter (Professional Edition)" { send "\r" }
expect "The Maple Reporter (Academic Edition)" { send "\r" }
expect "Upcoming Events and Seminars" { send "\r" }
expect "Special Product Announcements" { send "\r" }
expect "Press ENTER to finish" { send "\r"; exp_continue }
activateLicense
)

				if [[ $exitStatus == *"Activation successful!"* ]]; then
					echo "License Code applied successfully!"
					echo "Maple ${majorVersion} has been activated!"
				else
					echo "ERROR:  Failed to apply License Code for:  Maple ${majorVersion}"
					echo "ERROR Contents:  $(echo ${exitStatus} | /usr/bin/xargs)"
					echo "*****  License Maple process:  FAILED  *****"
				fi
			fi
		fi

		if [[ $(/usr/bin/stat -f "%OLp" "${licenseFile}") != "666" ]]; then
			# Set permissions on default permissions on the file.
				echo "Applying permissions to license file..."
				/bin/chmod 666 "${licenseFile}"
		fi
	done < <(echo "${appPaths}")
fi

echo "*****  License Maple process:  COMPLETE  *****"
exit 0