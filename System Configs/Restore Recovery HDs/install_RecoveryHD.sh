#!/bin/bash

###################################################################################################
# Script Name:  install_RecoveryHD.sh
# By:  Zack Thompson / Created:  3/21/2018
# Version:  1.1 / Updated:  3/23/2018 / By:  ZT
#
# Description:  This script will install the proper Recovery HD based on the OS Version.
#
###################################################################################################

echo " "
echo " "
echo "*****  Install RecoveryHD process:  START  *****"
echo " "

##################################################
# Define Variables
restoreFiles="${DS_REPOSITORY_PATH}/Files/Deskside/RecoveryHD"
targetVolume="/Volumes/${DS_LAST_SELECTED_TARGET}"
osVersion=$("${DS_REPOSITORY_PATH}/Tools/PlistBuddy" -c "Print :ProductVersion" "${targetVolume}/System/Library/CoreServices/SystemVersion.plist")
dsRuntimeOSVersion=$("${DS_REPOSITORY_PATH}/Tools/PlistBuddy" -c "Print :ProductVersion" "/Volumes/DeployStudioRuntime//System/Library/CoreServices/SystemVersion.plist")
dmtestBinary="${DS_REPOSITORY_PATH}/Tools/dmtest"
BaseSystemDMG="${restoreFiles}/${version}/BaseSystem.dmg"
BaseSystemChunkList="${restoreFiles}/${version}/BaseSystem.chunklist"

##################################################
# Bits staged...

echo "Selected Volume:  ${DS_LAST_SELECTED_TARGET}"
echo "Selected Volume OS Version:  ${osVersion}"
echo "NetBoot Set OS Version:  ${dsRuntimeOSVersion}"
# echo "Installing:  macOS Restore Recovery HD-${osVersion}.pkg"
echo " "

if [[ $(echo "${dsRuntimeOSVersion}" | /usr/bin/awk -F '.' '{print $1"."$2}') == "10.11" ]]; then
	echo " "
	echo "WARNING:  You are booted into a 10.11 El Capitan NetBoot Set."
	echo "We have had poor success using this NetBoot Set version to restore the Recovery HD -- we recommend using a different NetBoot Set if possible."
	echo "Please contact us if you need further assistance."
	echo " "
	echo " "
fi

# Install the package.
# /usr/sbin/installer -pkg "${restoreFiles}/macOS Restore Recovery HD-${osVersion}.pkg" -target "${targetVolume}" -allowUntrusted -verbose

echo "Creating the missing Recovery HD...."
# Create the Recovery HD Partition
"${dmtestBinary}" ensureRecoveryPartition "${targetVolume}" "${BaseSystemDMG}" 0 0 "${BaseSystemChunkList}"

# Get the Exit Code
exitCode=$?

if [[ $exitCode != 0 ]]; then
	echo "ERROR:  Install failed!"
	echo "Exit Code:  ${exitCode}"
	echo "*****  Install RecoveryHD process:  FAILED  *****"
	exit 1
fi

echo " "
echo "Install complete!"
echo "*****  Install RecoveryHD process:  COMPLETE  *****"
echo " "
echo " "

exit 0