#!/bin/bash

###################################################################################################
# Script Name:  update_SPSS.sh
# By:  Zack Thompson / Created:  11/22//2017
# Version:  1.2 / Updated:  12/13/2017 / By:  ZT
#
# Description:  This script grabs the current location of the SPSSStatistics.app and injects it into the installer.properties file and then will upgrade an SPSS Installation.
#
###################################################################################################

/bin/echo "**************************************************"
/bin/echo 'Starting PostInstall Upgrade Script'
/bin/echo "**************************************************"

# Set working directory
	pkgDir=$(/usr/bin/dirname $0)

# Get the location of SPSSStatistics.app
	fullPath=$(/usr/bin/find /Applications -name *.app | /usr/bin/grep -E "(24\/)?(SPSS) ?(Statistics) ?(24)?(.app)" | /usr/bin/grep -Ev "(.app/|Python)")

# Get the *.app name
	appName=$(echo $fullPath | awk -F "/" '{print $NF}')

# Get only the install path
	installPath=$(echo $fullPath | awk -F "/$appName" '{print $1}')

# Inject the location to the installer.properties file
	LANG=C /usr/bin/sed -i '' 's,USER_INSTALL_DIR=,&'"$installPath"',' $pkgDir/installer.properties

# Make sure the Patch.bin file is executable
	/bin/chmod x+ $pkgDir/SPSS_Statistics_Installer_Mac_Patch.bin

# Silent upgrade using information in the installer.properties file
	/bin/echo "Upgrading SPSS..."
		$pkgDir/SPSS_Statistics_Installer_Mac_Patch.bin -f $pkgDir/installer.properties
	/bin/echo "Upgrade complete!"

# Inject the proper version into the Info.plist file
	/usr/bin/sed -i '' 's/24.0.0.1/24.0.0.2/' $fullPath/Contents/Info.plist

/bin/echo "**************************************************"
/bin/echo 'PostInstall Upgrade Script Finished'
/bin/echo "**************************************************"

exit 0
