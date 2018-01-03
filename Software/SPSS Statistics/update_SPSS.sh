#!/bin/bash

###################################################################################################
# Script Name:  update_SPSS.sh
# By:  Zack Thompson / Created:  11/22//2017
# Version:  1.1 / Updated:  11/27/2017 / By:  ZT
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
	installLocation=$(/usr/bin/find /Applications -name *.app | /usr/bin/grep -E "(24\/)?(SPSS) ?(Statistics) ?(24)?(.app)" | /usr/bin/grep -Ev "(.app/|Python)")

# Inject the location to the installer.properties file
	LANG=C /usr/bin/sed -i '' 's,USER_INSTALL_DIR=,&'"$installLocation"',' $pkgDir/installer.properties

# Silent upgrade using information in the installer.properties file
	/bin/echo "Upgrading SPSS..."
		$pkgDir/SPSS_Statistics_Installer_Mac_Patch.bin -f $pkgDir/installer.properties
	/bin/echo "Upgrade complete!"
	
	defaults write /Applications/SPSS/Statistics/24/SPSSStatistics.app/Contents/Info.plist CFBundleShortVersionString 24.0.0.2

/bin/echo "**************************************************"
/bin/echo 'PostInstall Upgrade Script Finished'
/bin/echo "**************************************************"

exit 0
