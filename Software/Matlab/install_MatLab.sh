#!/bin/sh

###################################################################################################
# Script Name:  install_MatLab.sh
# By:  Zack Thompson / Created:  3/6/2017
# Version:  1.3 / Updated:  1/11/2018 / By:  ZT
#
# Description:  This script installs MatLab.
#
###################################################################################################

/bin/echo "*****  Install Matlab process:  START  *****"

##################################################
# Define Variables

# Set working directory
	pkgDir=$(/usr/bin/dirname $0)
# Version that's being updated (this will be set by the build_Matlab.sh script)
	version=

##################################################
# Bits staged...

# Install MatLab with an option file.
/bin/echo "Installing Matlab..."
	"${pkgDir}/Matlab_${version}_Mac/InstallForMacOSX.app/Contents/MacOS/InstallForMacOSX" -inputFile "${pkgDir}/installer_input.txt"
exitStatus=$?

if [[ $exitStatus != 0 ]]; then
	/bin/echo "ERROR:  Install failed!"
	/bin/echo "*****  Install Matlab process:  FAILED  *****"
	exit 1
fi

/bin/echo "*****  Install Matlab process:  COMPLETE  *****"

exit 0
