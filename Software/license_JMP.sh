#!/bin/bash

###################################################################################################
# Script Name:  license_JMP.sh
# By:  Zack Thompson / Created:  3/3/2017
# Version:  3.0 / Updated:  4/13/2018 / By:  ZT
#
# Description:  This script applies the license for JMP applications.
#
###################################################################################################

echo "*****  License JMP process:  START  *****"

##################################################
# Define Variables

# Get the current user
	currentUser=$(/usr/bin/python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");')

# Find all installed JMP versions.
	appPaths=$(/usr/bin/find /Applications -iname "JMP*.app" -maxdepth 1 -type d)

##################################################
# Define Functions

LicenseInfo() {

	# Set the proper license file location based on version
	case "${1}" in
		*"13"* )
			version="13"
			licenseFile="/Library/Application Support/JMP/13/JMP.per"
		;;
		*"14"* )
			version="14"
			licenseFile="/Library/Application Support/JMP/14/JMP.per"
		;;
		* )
			echo "A unexpected version was found!"
			echo "*****  License JMP process:  FAILED  *****"
			exit 1
		;;	
	esac

	# Assign the proper license per edition
	case "${1}" in
		*"JMP 13.app"* )
			licenseContents="Platform=Macintosh
Product=JMP
Release=13.0.x
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
		*"JMP Pro 13.app"* )
			licenseContents="Platform=Macintosh
Product=JMPPRO
Release=13.0.x
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
		*"JMP 14.app"* )
			licenseContents="Platform=Macintosh
Product=JMP
Release=14.0.x
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
		*"JMP Pro 14.app"* )
			licenseContents="Platform=Macintosh
Product=JMPPRO
Release=14.0.x
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
			echo "A unexpected version was found!"
			echo "*****  License JMP process:  FAILED  *****"
			exit 1
		;;
	esac
}

##################################################
# Bits staged, license software...

# Verify that a JMP version was found.
if [[ -z "${appPaths}" ]]; then
	echo "A version of JMP was not found in the expected location!"
	echo "*****  License JMP process:  FAILED  *****"
	exit 3
else
	# If the machine has multiple JMP Applications, loop through them...
	while IFS="\n" read -r appPath; do

		# Get the App Bundle name
		appName=$(echo "${appPath}" | /usr/bin/awk -F "/" '{print $NF}')
		echo "Version found:  ${appName}"

		# Function LicenseInfo
		LicenseInfo "${appName}"

		# Create the license file.
		echo "Creating license file..."
		/usr/bin/printf "${licenseContents}" > "${licenseFile}"

		# Set permissions on the file for everyone to be able to read.
		echo "Applying permissions to license file..."
		/bin/chmod 644 "${licenseFile}"

		# Set the location of the license file in the System Library folder plist.
		echo "Setting location of the license file..."
		/usr/bin/defaults write /Library/Preferences/com.sas.jmp.plist "Setinit_${version}_Path" "${licenseFile}"

		echo "Configuring user space..."
		# Remove the location from the users preference file (if it's configured there).
		/usr/bin/defaults delete "/Users/${currentUser}/Library/Preferences/com.sas.jmp.plist" "Setinit_${version}_Path" &> /dev/null
		
		# Mark as 'registration requested' so it doesn't ask the user.
		/usr/bin/defaults write "/Users/${currentUser}/Library/Application Support/JMP/${version}/License.plist" RegistrationRequested Y
		
		# Set permissions on the plist file.
		/bin/chmod 644 "/Users/${currentUser}/Library/Application Support/JMP/${version}/License.plist"

	done < <(echo "${appPaths}")
fi

echo "JMP has been activated!"
echo "*****  License JMP process:  COMPLETE  *****"

exit 0