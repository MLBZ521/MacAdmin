#!/bin/bash

###################################################################################################
# Script Name:  install_QGIS.sh
# By:  Zack Thompson / Created:  7/26/2017
# Version:  1.1 / Updated:  2/7/2018 / By:  ZT
#
# Description:  This script installs all the packages that are contained in this package.
#
###################################################################################################

/bin/echo "*****  Install QGIS process:  START  *****"

if [[ $3 != "/" ]]; then
    /bin/echo "ERROR:  Target disk is not the startup disk."
    /bin/echo "*****  Install QGIS process:  FAILED  *****"
    exit 1
fi

# Set working directory
pkgDir=$(dirname $0)

# Check if QGIS is currently installed...
if [[ -e /Applications/QGIS.app ]]; then
	/bin/echo "QGIS is currently installed; removing this instance before continuing..."
	rm -rf /Applications/QGIS.app
	/bin/echo "QGIS has been removed."
fi

/bin/echo "Gathering packages that need to be installed for QGIS..."

# Loop through each .pkg in the directory...
for pkg in $(/bin/ls $pkgDir | /usr/bin/grep .pkg)
	do
		/bin/echo "Installing ${pkg}..."
		/usr/sbin/installer -dumplog -verbose -pkg $pkg -allowUntrusted -target /
		/bin/echo "${pkg} has been installed!"
	done

/bin/echo "All packages have been installed!"

# Disable version check (this is done because the version compared is not always the latest available for macOS).
/bin/echo "Disabling version check on launch..."
/usr/bin/defaults write org.qgis.QGIS2.plist qgis.checkVersion -boolean false

/bin/echo "*****  Install QGIS process:  COMPLETE  *****"

exit 0