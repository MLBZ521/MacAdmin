#!/bin/bash

###################################################################################################
# Script Name:  install_Avast.sh
# By:  Zack Thompson / Created:  2/9/2018
# Version:  1.0 / Updated:  2/9/2018 / By:  ZT
#
# Description:  This script installs Avast.
#
###################################################################################################

/bin/echo "*****  install_Avast Process:  START  *****"

##################################################
# Define Variables

# Set working directory
	pkgDir=$(/usr/bin/dirname $0)

##################################################
# Install Avast

/bin/echo "Installing Avast..."
	/usr/sbin/installer -dumplog -verbose -pkg "${pkgDir}/Avast Business AntiVirus.pkg" -target /
	exitCode=$?

if [[ $exitCode != 0 ]]; then
	/bin/echo "ERROR:  Install failed!"
	/bin/echo "Exit Code:  ${exitCode}"
	/bin/echo "*****  Install Maple process:  FAILED  *****"
	exit 1
fi

/bin/echo "Install complete!"
/bin/echo "*****  install_Avast Process:  COMPLETE  *****"

exit 0
