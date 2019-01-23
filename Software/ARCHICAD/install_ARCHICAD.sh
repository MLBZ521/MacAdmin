#!/bin/bash

###################################################################################################
# Script Name:  install_ARCHICAD.sh
# By:  Zack Thompson / Created:  1/17/2019
# Version:  1.0.1 / Updated:  1/22/2019 / By:  ZT
#
# Description:  This script installs ARCHICAD in unattended mode.
#
###################################################################################################

echo "*****  Install ARCHICAD Process:  START  *****"

##################################################
# Define Variables

# License Key
eduSerialNumber=""
# User ID
eduUserID=""
# Set working directory
pkgDir=$(/usr/bin/dirname "${0}")
# Get the filename of the .app file
ARCHICADinstaller=$(/bin/ls "${pkgDir}" | /usr/bin/grep .app)

##################################################
# Bits staged...

# Check the installation target.
if [[ $3 != "/" ]]; then
	echo "ERROR:  Target disk is not the startup disk."
	echo "*****  Install ARCHICAD process:  FAILED  *****"
	exit 1
fi

echo "Installing: " $( "${pkgDir}/${ARCHICADinstaller}/Contents/MacOS/installbuilder.sh" --version --mode unattended )

installResult=$( "${pkgDir}/${ARCHICADinstaller}/Contents/MacOS/installbuilder.sh" --mode unattended --unattendedmodeui none --desktopshortcut 0 --dockshortcut 0 --eduSerialNumber "${eduSerialNumber}" --eduUserID "${eduUserID}" )
exitCode=$?

if [[ $exitCode != 0 ]]; then
	echo "Installation FAILED!"
	echo "Reason:  ${installResult}"
	echo "Exit Code:  ${exitCode}"
	echo "*****  Install ARCHICAD process:  FAILED  *****"
	exit 2
fi

echo "ARCHICAD has been installed!"
echo "*****  Install ARCHICAD Process:  COMPLETE  *****"
exit 0