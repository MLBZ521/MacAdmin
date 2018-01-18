#!/bin/sh

###################################################################################################
# Script Name:  install_Maple.sh
# By:  Zack Thompson / Created:  3/2/2017
# Version:  1.3 / Updated:  1/17/2018 / By:  ZT
#
# Description:  This script silently installs Maple.
#
###################################################################################################

/bin/echo "*****  Install Maple process:  START  *****"

##################################################
# Define Variables

# Set working directory
	pkgDir=$(/usr/bin/dirname $0)
# Java JDK Directory
	jdkDir="/Library/Java/JavaVirtualMachines"
# Version that's being updated (this will be set by the build_Maple.sh script)
	version=

##################################################
# Bits staged...

# Install Maple
/bin/echo "Installing Maple..."
	"${pkgDir}/Maple${version}MacInstaller.app/Contents/MacOS/installbuilder.sh" --mode unattended
	exitStatus=$?
/bin/echo "Exit Status:  ${exitStatus}"

if [[ $exitStatus != 0 ]]; then
	/bin/echo "ERROR:  Install failed!"
	/bin/echo "*****  Install Maple process:  FAILED  *****"
	exit 1
elif [[ -n $(/usr/bin/find $jdkDir -iname 1.6*.jdk) ]]; then
	/bin/echo "Java JDK 1.6 is required for full Maple functionality:  Installing..."
	# Apple update 'Java for OS X 2015-001' is required for Maples as well, installing that here.
		/usr/sbin/installer -dumplog -verbose -pkg "${pkgDir}/JavaForOSX.pkg" -target /
	/bin/echo 'Java JDK installed!'
fi

/bin/echo "Install complete!"
/bin/echo "*****  Install Maple process:  COMPLETE  *****"

exit 0