#!/bin/sh

###################################################################################################
# Script Name:  install_Mathematica.sh
# By:  Zack Thompson / Created:  1/10/2018
# Version:  1.0 / Updated:  1/10/2018 / By:  ZT
#
# Description:  This script silently installs Mathematica.
#
###################################################################################################

/bin/echo "*****  Install Mathematica process:  START  *****"

##################################################
# Define Variables

# Set working directory
	pkgDir=$(/usr/bin/dirname $0)

##################################################
# Bits staged...

# Install Mathematica
/bin/echo "Installing Mathematica..."
	/bin/cp -Rf "${pkgDir}/Mathematica.app" /Applications
/bin/echo "Install complete!"

/bin/echo "*****  Install Mathematica process:  COMPLETE  *****"

exit 0