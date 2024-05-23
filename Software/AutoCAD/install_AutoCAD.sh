#!/bin/bash

####################################################################################################
# Script Name:  Install-AutoCAD.sh
# By:  Zack Thompson / Created:  9/2/2020
# Version:  1.3.0 / Updated:  5/20/2024 / By:  ZT
#
# Description:  This script silently installs AutoCAD 2023 and newer.
#	Probably works for AutoCAD 2021+ as well.
#
# Note:  The "new" silent install method (using `[...]/Setup -silent`) does not work when it is
#	executed from a .pkg's postinstall script for some odd reason.
#
####################################################################################################

echo -e "*****  Install AutoCAD Process:  START  *****\n"

##################################################
# Bits staged...

echo "Searching for the Installer App..."
installer_app=$( /usr/bin/find -E "/private/tmp" -iregex \
	".*/Install Autodesk AutoCAD [[:digit:]]{4} for Mac[.]app" -type d -maxdepth 1 -prune )

echo "Installing:  ${installer_app}"
"${installer_app}/Contents/Helper/Setup.app/Contents/MacOS/Setup" --silent
exit_code=$?

/bin/rm -Rf "${installer_app}"

if [[ $exit_code != 0 ]]; then
	echo -e "[Error] Failed to install!\nExit Code:  ${exit_code}"
	echo -e "\n*****  Install AutoCAD process:  FAILED  *****"
	exit $exit_code
fi

echo -e "AutoCAD has been installed!\n\n*****  Install AutoCAD Process:  COMPLETE  *****"
exit 0