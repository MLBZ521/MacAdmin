#!/bin/bash

###################################################################################################
# Script Name:  build_macOSFirmware.sh
# By:  Zack Thompson / Created: 6/4/2018
# Version:  1.0 / Updated:  6/5/2018 / By:  ZT
#
# Description:  This script extracts the firmware from a macOS Install <Version>.app, builds a pkg with it and also outputs a list of firmware updates.
#
#	Inspired by Allister Banks' post:  https://www.afp548.com/2017/08/31/uefi-10-13apfs-and-your-imaging/
#
###################################################################################################

echo "*****  build_macOSFirmware process:  START  *****"

##################################################
# Define Variables

postinstall="#!/bin/sh

/usr/libexec/FirmwareUpdateLauncher -p \"$PWD/Tools\"
/usr/libexec/efiupdater -p \"$PWD/Tools/EFIPayloads\""

##################################################
# Bits Staged

# Search in the the /Applications directory.
appLocation=$(/usr/bin/find -E /Applications -iregex ".*/Install macOS .*[.]app" -maxdepth 1 -type d -prune)

# If it does not exist, prompt user for the location of the macOS Install app.
if [[ -z "${appLocation}" ]]; then
	echo "Didn't find a OS Installer in the expected location..."
	# Prompt for location of "macOS Install <Version>.app".
	appLocation=$(/usr/bin/osascript -e 'tell application (path to frontmost application as text)' -e 'return POSIX path of(choose file with prompt "Select file:" of type {"app"})' -e 'end tell')
else
	echo "Found:  ${appLocation}"
fi

# Get the Version that the Install macOS app is for.
appVersion=$(echo "10."$(/usr/bin/defaults read "${appLocation}/Contents/Info.plist" CFBundleShortVersionString | /usr/bin/awk -F '.' '{print $1"."$2}'))

echo "Installer is for Version:  ${appVersion}"
echo " "

echo "Mounting the InstallESD.dmg..."
# Mount the InstallESD in the OS Installer.
/usr/bin/hdiutil mount "${appLocation}/Contents/SharedSupport/InstallESD.dmg"

echo "Expanding the FirmwareUpdate.pkg..."
# Expand the FirmwareUpdate Package within the mounted InstallESD Volume.
/usr/sbin/pkgutil --expand "/Volumes/InstallESD/Packages/FirmwareUpdate.pkg" /tmp/FirmwareUpdate

# Create the a template directory
munkipkg --create /tmp/FirmwareUpdateStandalone

echo "Staging the project directory..."
# Setup the build-info.plist file.
/usr/libexec/PlistBuddy -c "set identifier com.github.mlbz521.pkg.macOS Firmware ${appVersion}" /tmp/FirmwareUpdateStandalone/build-info.plist
/usr/libexec/PlistBuddy -c "set name macOS Firmware-${appVersion}.pkg" /tmp/FirmwareUpdateStandalone/build-info.plist
/usr/libexec/PlistBuddy -c "set version ${appVersion}" /tmp/FirmwareUpdateStandalone/build-info.plist

# Copy over the Update Script (if it exists), if not create it.
if [[ -e /tmp/FirmwareUpdate/Scripts/postinstall_actions/update ]]; then
	/bin/cp /tmp/FirmwareUpdate/Scripts/postinstall_actions/update /tmp/FirmwareUpdateStandalone/scripts/postinstall
else
	/usr/bin/printf "${postinstall}" > /tmp/FirmwareUpdateStandalone/scripts/postinstall
fi

# Copy over the firmware update files.
/bin/cp -R /tmp/FirmwareUpdate/Scripts/Tools /tmp/FirmwareUpdateStandalone/scripts/

echo "Building a list of models with Firmware Updates found in this package..."
# Build list of Firmware Updates.
firmwareUpdates=$(ls /tmp/FirmwareUpdateStandalone/scripts/Tools/EFIPayloads/)

while IFS=$'\n' read -r firmware; do

	model=$(/usr/bin/printf "${firmware}" | /usr/bin/awk -F '_' '{print $1}')
	firmwareVersion=$(/usr/bin/printf "${firmware}" | /usr/bin/sed 's/\([.]scap\)//' | /usr/bin/sed 's/\([.]fd\)//' | /usr/bin/awk -F '_' '{print $1"."$2"."$3}')

	case $model in
		"IM"* )
			# iMac
			echo -e "iMac $(/usr/bin/printf "${model}" | /usr/bin/awk '{ gsub(/([[:alpha:]]+|digit:]]+)/,"&\n",$0) ; printf $2 }' | /usr/bin/sed 's/.$/,&/')\t${firmwareVersion}" >> /tmp/FirmwareUpdateStandalone/FirmwareList-$appVersion.csv
			;;
		"MB"* )
			# MacBook
			echo -e "MacBook $(/usr/bin/printf "${model}" | /usr/bin/awk '{ gsub(/([[:alpha:]]+|digit:]]+)/,"&\n",$0) ; printf $2 }' | /usr/bin/sed 's/.$/,&/')\t${firmwareVersion}" >> /tmp/FirmwareUpdateStandalone/FirmwareList-$appVersion.csv
			;;
		"MBP"* )
			# MacBook Pro
			echo -e "MacBook Pro $(/usr/bin/printf "${model}" | /usr/bin/awk '{ gsub(/([[:alpha:]]+|digit:]]+)/,"&\n",$0) ; printf $2 }' | /usr/bin/sed 's/.$/,&/')\t${firmwareVersion}" >> /tmp/FirmwareUpdateStandalone/FirmwareList-$appVersion.csv
			;;
		"MBA"* )
			# MacBook Air
			echo -e "MacBook Air $(/usr/bin/printf "${model}" | /usr/bin/awk '{ gsub(/([[:alpha:]]+|digit:]]+)/,"&\n",$0) ; printf $2 }' | /usr/bin/sed 's/.$/,&/')\t${firmwareVersion}" >> /tmp/FirmwareUpdateStandalone/FirmwareList-$appVersion.csv
			;;
		"MM"* )
			# MacMini
			echo -e "MacMini $(/usr/bin/printf "${model}" | /usr/bin/awk '{ gsub(/([[:alpha:]]+|digit:]]+)/,"&\n",$0) ; printf $2 }' | /usr/bin/sed 's/.$/,&/')\t${firmwareVersion}" >> /tmp/FirmwareUpdateStandalone/FirmwareList-$appVersion.csv
			;;
		"MP"* )
			# Mac Pro
			echo -e "Mac Pro $(/usr/bin/printf "${model}" | /usr/bin/awk '{ gsub(/([[:alpha:]]+|digit:]]+)/,"&\n",$0) ; printf $2 }' | /usr/bin/sed 's/.$/,&/')\t${firmwareVersion}" >> /tmp/FirmwareUpdateStandalone/FirmwareList-$appVersion.csv
			;;
	esac

done < <(/usr/bin/printf '%s\n' "${firmwareUpdates}")


# Create the firmware PKG.
munkipkg /tmp/FirmwareUpdateStandalone

echo "Package created!"

echo "Performing some clean up..."
# Remove tmp directory and unmount Volume.
/bin/rm -Rf /tmp/FirmwareUpdate
/usr/bin/hdiutil eject /Volumes/InstallESD

echo "*****  build_macOSFirmware process:  COMPLETE  *****"

exit 0