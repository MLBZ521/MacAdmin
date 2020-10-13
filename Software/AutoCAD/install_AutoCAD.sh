#!/bin/bash

###################################################################################################
# Script Name:  install_AutoCAD.sh
# By:  Zack Thompson / Created:  9/2/2020
# Version:  1.0.0 / Updated:  9/2/2020 / By:  ZT
#
# Description:  This script silently installs AutoCAD 2021 and newer.
#
###################################################################################################

echo "*****  Install AutoCAD Process:  START  *****"

# Check the installation target.
if [[ $3 != "/" ]]; then
	echo "ERROR:  Target disk is not the startup disk."
	echo "*****  Install AutoCAD process:  FAILED  *****"
	exit 1
fi

##################################################
# Define Variables

# Set working directory
pkgDir=$( /usr/bin/dirname "${0}" )

# Get the filename of the .app file
AutoCADinstaller=$( /bin/ls "${pkgDir}" | /usr/bin/grep .app )

##################################################
# Bits staged...

installResult=$( "${pkgDir}/${AutoCADinstaller}/Contents/Helper/Setup.app/Contents/MacOS/Setup" --silent --install_mode install --hide_eula  )
exitCode=$?

if [[ $exitCode != 0 ]]; then
	echo "Installation FAILED!"
	echo "Reason:  ${installResult}"
	echo "Exit Code:  ${exitCode}"
	echo "*****  Install AutoCAD process:  FAILED  *****"
	exit 2
fi

echo "AutoCAD has been installed!"
echo "*****  Install AutoCAD Process:  COMPLETE  *****"
exit 0