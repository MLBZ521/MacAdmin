#!/bin/bash

###################################################################################################
# Script Name:  install_Zoom-ForIT.sh
# By:  Zack Thompson / Created:  5/25/2018
# Version:  1.0 / Updated:  5/25/2018 / By:  ZT
#
# Description:  This script installs the Zoom package with a configuration .plist.
#
###################################################################################################

echo "*****  Install Zoom-ForIT Process:  START  *****"

##################################################
# Define Variables

# Set working directory
	pkgDir=$(/usr/bin/dirname "${0}")
# Get the filename of the .dmg file
	ZoomPKG=$(/bin/ls "${pkgDir}" | /usr/bin/grep .pkg)
# Set the configuration .plist details
	configuration="<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
<dict>
	<key>nogoogle</key>
	<string>1</string>
	<key>nofacebook</key>
	<string>1</string>
	<key>ZDisableVideo</key>
	<true/>
	<key>ZAutoJoinVoip</key>
	<true/>
	<key>ZDualMonitorOn</key>
	<true/>
	<key>ZAutoSSOLogin</key>
	<true/>
	<key>ZSSOHost</key>
	<string>yourVanityURL.zoom.us</string>
	<key>ZAutoFullScreenWhenViewShare</key>
	<true/>
	<key>ZAutoFitWhenViewShare</key>
	<true/>
	<key>ZUse720PByDefault</key>
	<false/>
	<key>ZRemoteControlAllApp</key>
	<true/>
	<key>ZHideNoVideoUser</key>
	<false/>
</dict>
</plist>"

##################################################
# Bits staged...

# Check the installation target.
if [[ $3 != "/" ]]; then
	echo "ERROR:  Target disk is not the startup disk."
	echo "*****  Install Zoom-ForIT process:  FAILED  *****"
	exit 1
fi

echo "Installing ${ZoomPKG}..."
exitResult=$(/usr/sbin/installer -dumplog -verbose -pkg "${pkgDir}/${ZoomPKG}" -allowUntrusted -target /)
exitCode=$?

if [[ $exitCode != 0 ]]; then
	echo "Installation FAILED!"
	echo "Reason:  ${exitResult}"
	echo "Exit Code:  ${exitCode}"
	echo "*****  Install Zoom-ForIT process:  FAILED  *****"
	exit 2
else
	echo "${2} has been installed!"
	echo "Installing custom configuration details..."
	/usr/bin/printf "${configuration}" > "${pkgDir}/us.zoom.config.plist"
	/bin/mv "${pkgDir}/us.zoom.config.plist" "/Library/Preferences/us.zoom.config.plist"
fi

echo "*****  Install Zoom-ForIT Process:  COMPLETE  *****"
exit 0