#!/bin/bash

###################################################################################################
# Script Name:  install_Mathematica.sh
# By:  Zack Thompson / Created:  1/10/2018
# Version:  1.3 / Updated:  3/23/2018 / By:  ZT
#
# Description:  This script silently installs Mathematica.
#
###################################################################################################

echo "*****  Install Mathematica process:  START  *****"

##################################################
# Define Variables

# Set working directory
	pkgDir=$(/usr/bin/dirname "${0}")

##################################################
# Bits staged...

# Check if Mathematic is already installed.
if [[ -e "/Applications/Mathematica.app" ]]; then
	echo "Mathematica is currently installed, removing..."
	/bin/rm -rf "/Applications/Mathematica.app"
fi

# Install Mathematica
echo "Installing Mathematica..."
	/bin/mv "${pkgDir}/Mathematica.app" /Applications
echo "Install complete!"

echo "*****  Install Mathematica process:  COMPLETE  *****"

exit 0