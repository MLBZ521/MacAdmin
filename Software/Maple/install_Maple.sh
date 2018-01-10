#!/bin/sh

###################################################################################################
# Script Name:  install_Maple.sh
# By:  Zack Thompson / Created:  3/2/2017
# Version:  1.2 / Updated:  1/8/2018 / By:  ZT
#
# Description:  This script silently installs Maple.
#
###################################################################################################

/bin/echo "*****  Install Maple process:  START  *****"

##################################################
# Define Variables

# Set working directory
	pkgDir=$(/usr/bin/dirname $0)
# Version that's being updated (this will be set by the build_Maple.sh script)
	version=

##################################################
# Bits staged...

# Install Maple
/bin/echo "Installing Maple..."
	"${pkgDir}/Maple${version}MacInstaller.app/Contents/MacOS/installbuilder.sh" --mode unattended
/bin/echo "Install complete!"

# Apple update 'Java for OS X 2015-001' is required for Maples as well, installing that here.
	/usr/sbin/installer -dumplog -verbose -pkg "${pkgDir}/JavaForOSX.pkg" -target /
/bin/echo 'Java installed!'

/bin/echo "*****  Install Maple process:  COMPLETE  *****"

exit 0