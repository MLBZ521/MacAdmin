#!/bin/bash

###################################################################################################
# Script Name:  install_MatLab.sh
# By:  Zack Thompson / Created:  3/6/2017
# Version:  1.5 / Updated:  1/31/2018 / By:  ZT
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

# Install MatLab with option file.
/bin/echo "Installing Matlab..."

if [[ $version == "2017a" ]]; then
	# Inject dummy location to the installer.input file -- hacky, but works
	LANG=C /usr/bin/sed -Ei '' 's,(#)?licensePath=.*,'"licensePath=${pkgDir}/installer_input.txt"',' "${pkgDir}/installer_input.txt"
	# -mode silent did not work in the option file for me.
	exitStatus=$("${pkgDir}/install" -mode silent -inputFile "${pkgDir}/installer_input.txt")
else
	# I'm assuming all future version will be packaged in this manner...(/hoping)..?
	exitStatus=$("${pkgDir}/InstallForMacOSX.app/Contents/MacOS/InstallForMacOSX" -inputFile "${pkgDir}/installer_input.txt")
fi
exitCode=$?

if [[ $exitCode != 0 ]]; then
	/bin/echo "Exit Code:  ${exitCode}"
fi

if [[ $exitStatus == *"End - Unsuccessful"* ]]; then
	/bin/echo "ERROR:  Install failed!"
	/bin/echo "ERROR Content:  ${exitStatus}"
	/bin/echo "*****  Install Matlab process:  FAILED  *****"
	exit 1
fi

/bin/echo "Install complete!"
/bin/echo "*****  Install Matlab process:  COMPLETE  *****"

exit 0