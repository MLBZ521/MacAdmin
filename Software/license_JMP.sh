#!/bin/bash

####################################################################################################
# Script Name:  license_JMP.sh
# By:  Zack Thompson / Created:  3/3/2017
# Version:  4.0.0 / Updated:  12/11/2023 / By:  ZT
#
# Description:  This script applies the license for JMP applications.
#
####################################################################################################

echo "*****  License JMP process:  START  *****"

##################################################
# Define Variables

# Get the current user
current_user=$( echo "show State:/Users/ConsoleUser" \
	| /usr/sbin/scutil | /usr/bin/awk '/Name :/&&!/loginwindow/{print $3}' )

# Find all installed JMP versions.
app_paths=$( /usr/bin/find /Applications -iname "JMP*.app" -maxdepth 1 -type d )

##################################################
# Define Functions

get_license_info() {
	# Set the proper license file location based on
	# version and assign the proper license per edition

	# Arguments
	# $1 = (str) A string containing the name of the app bundle

	case "${1}" in
		*"13"* | *"14"* | *"15"* | *"16"* )
			supported="Unsupported"
		;;
# 		*"JMP 13.app"* )
			# version="13"
			# license_file="/Library/Application Support/JMP/13/JMP.per"
# 			licenseContents="Platform=Macintosh
# Product=JMP
# Release=13.0.x
# LType=SiteLicense
# EMode=Full
# SiteID=
# MaxNUsers=
# Starts=
# Expires=
# Administrator=
# Organization=
# Password1=
# Department="
# 		;;
# 		*"JMP Pro 13.app"* )
			# version="13"
			# license_file="/Library/Application Support/JMP/13/JMP.per"
# 			licenseContents="Platform=Macintosh
# Product=JMPPRO
# Release=13.0.x
# LType=SiteLicense
# EMode=Full
# SiteID=
# MaxNUsers=
# Starts=
# Expires=
# Administrator=
# Organization=
# Password1=
# Department="
# 		;;
		*"JMP 17.app"* )
			supported="Supported"
			version="17"
			license_file="/Library/Application Support/JMP/17/JMP.per"
			license_contents="Platform=Macintosh
Product=JMP
Release=17.0.x
LType=SiteLicense
EMode=Full
SiteID=
MaxNUsers=
Starts=
Expires=
Administrator=
Organization=
Password1=
Department="
		;;
		*"JMP Pro 17.app"* )
			supported="Supported"
			version="17"
			license_file="/Library/Application Support/JMP/17/JMP.per"
			license_contents="Platform=Macintosh
Product=JMPPRO
Release=17.0.x
LType=SiteLicense
EMode=Full
SiteID=
MaxNUsers=
Starts=
Expires=
Administrator=
Organization=
Password1=
Department="
		;;
		* )
			echo "[WARNING] A unsupported version was found!"
			supported="Unsupported"
		;;
	esac
}

##################################################
# Bits staged, license software...

# Verify that a JMP version was found.
if [[ -z "${app_paths}" ]]; then
	echo "[ERROR] A version of JMP was not found in the expected location!"
	echo "*****  License JMP process:  FAILED  *****"
	exit 1
else
	# If the machine has multiple JMP Applications, loop through them...
	while IFS=$'\n' read -r appPath; do

		# Get the App Bundle name
		app_name=$( echo "${appPath}" | /usr/bin/awk -F "/" '{print $NF}' )
		echo "Version found:  ${app_name}"

		# Function get_license_info
		get_license_info "${app_name}"

		if [[ "${supported}" == "Unsupported" ]]; then
			echo " -> [WARNING] This version of JMP is no longer supported!"
		else

			# Create the license file.
			echo " -> Creating license file..."
			/usr/bin/printf "${license_contents}" > "${license_file}"

			# Set permissions on the file for everyone to be able to read.
			echo " -> Applying permissions to license file..."
			/bin/chmod 644 "${license_file}"

			# Set the location of the license file in the System Library folder plist.
			echo " -> Setting location of the license file..."
			/usr/bin/defaults write /Library/Preferences/com.sas.jmp.plist \
				"Setinit_${version}_Path" "${license_file}"

			echo " -> Configuring user space..."
			# Remove the location from the users preference file (if it's configured there).
			/usr/bin/defaults delete \
				"/Users/${current_user}/Library/Preferences/com.sas.jmp.plist" \
				"Setinit_${version}_Path" &> /dev/null

			# Mark as 'registration requested' so it doesn't ask the user.
			/usr/bin/defaults write \
				"/Users/${current_user}/Library/Application Support/JMP/${version}/License.plist" \
				RegistrationRequested Y

			# Set permissions on the plist file.
			/bin/chmod 644 \
				"/Users/${current_user}/Library/Application Support/JMP/${version}/License.plist"

			echo " -> JMP has been activated!"
			successfully_licensed="true"

		fi
	done < <( echo "${app_paths}" )
fi

if [[ "${successfully_licensed}" = "true" ]]; then
	echo "*****  License JMP process:  COMPLETE  *****"
	exit 0
else
	echo "*****  License JMP process:  FAILED  *****"
	exit 2
fi
