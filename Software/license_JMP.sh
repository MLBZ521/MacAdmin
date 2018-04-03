#!/bin/bash

###################################################################################################
# Script Name:  license_JMP.sh
# By:  Zack Thompson / Created:  3/3/2017
# Version:  2.1.1 / Updated:  3/30/2018 / By:  ZT
#
# Description:  This script applies the license for JMP applications.
#
###################################################################################################

echo "*****  License JMP process:  START  *****"

##################################################
# Define Variables

licenseFile="/Library/Application Support/JMP/13/JMP.per"
# Get the current user
	currentUser=$(/usr/bin/python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");')

# Get the install JMP.app edition (standard vs Pro)
	appPath=$(/usr/bin/find /Applications -iname "JMP*.app" -maxdepth 1 -type d)
	echo "Applying license for:  ${appPath}"

##################################################
# Create the license file.

# Assign the proper license per edition
	echo "Creating license file..."

if [[ $appPath == *"JMP 13.app"* ]]; then
	/bin/cat > "${licenseFile}" <<licenseContents
Platform=Macintosh
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
Department=
licenseContents

elif [[ $appPath == *"JMP Pro 13.app"* ]]; then
	/bin/cat > "${licenseFile}" <<licenseContents
Platform=Macintosh
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
Department=
licenseContents

else
	echo "A version of JMP was not located in the expected location!"
	echo "*****  License JMP process:  FAILED  *****"
	exit 1
fi

# Set permissions on the file for everyone to be able to read.
	echo "Applying permissions to license file..."
	/bin/chmod 644 "${licenseFile}"

##################################################
# Additional configuration

# Set the location of the license file in the System Library folder plist.
	echo "Setting location of the license file..."
	/usr/bin/defaults write /Library/Preferences/com.sas.jmp.plist Setinit_13_Path "${licenseFile}"

echo "Configuring user space..."
	# Remove the location from the users preference file (if it's configured there).
		/usr/bin/defaults delete /Users/$currentUser/Library/Preferences/com.sas.jmp.plist Setinit_13_Path &> /dev/null
	# Mark as 'registration requested' so it doesn't ask the user.
		/usr/bin/defaults write "/Users/${currentUser}/Library/Application Support/JMP/13/License.plist" RegistrationRequested Y
	# Set permissions on the plist file.
		/bin/chmod 644 "/Users/${currentUser}/Library/Application Support/JMP/13/License.plist"

echo "JMP has been activated!"
echo "*****  License JMP process:  COMPLETE  *****"

exit 0