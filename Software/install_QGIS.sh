#!/bin/bash

###################################################################################################
# Script Name:  install_QGIS.sh
# By:  Zack Thompson / Created:  7/26/2017
# Version:  1.0 / Updated:  7/26/2017 / By:  ZT
#
# Description:  This script installs all the packages that are contained in this package.
#
###################################################################################################

/bin/echo "**************************************************"
/bin/echo 'Starting PostInstall Script'
/bin/echo "**************************************************"

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

/bin/echo "**************************************************"
/bin/echo 'PostInstall Script Finished'
/bin/echo "**************************************************"

exit 0