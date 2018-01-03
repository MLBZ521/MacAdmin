#!/bin/bash

###################################################################################################
# Script Name:  update_SPSS.sh
# By:  Zack Thompson / Created:  11/22//2017
# Version:  1.0 / Updated:  11/22/2017 / By:  ZT
#
# Description:  This script grab the current location of the SPSSStatistics.app and inject it into the installer.properties file and then will upgrade an SPSS Installation.
#
###################################################################################################

/bin/echo "**************************************************"
/bin/echo 'Starting PostInstall Upgrade Script'
/bin/echo "**************************************************"

# Set working directory
	pkgDir=$(/usr/bin/dirname $0)
# Get the location of SPSSStatistics.app
	$installLocation=$(/usr/sbin/system_profiler -detailLevel Mini SPApplicationsDataType | /usr/bin/awk -F 'Location: ' '{print $2}' | /usr/bin/grep /Applications | /usr/bin/grep SPSSStatistics.app)

# Inject the location to the installer.properties file
	/usr/bin/awk '/USER_INSTALL_DIR=/ {print; print $installLocation;next}1' installer.properties

# Silent upgrade using information in the installer.properties file
	/bin/echo "Upgrading SPSS..."
		$pkgDir/SPSS_Statistics_Installer_Mac_Patch.bin -f $pkgDir/installer.properties
	/bin/echo "Upgrade complete!"

/bin/echo "**************************************************"
/bin/echo 'PostInstall Upgrade Script Finished'
/bin/echo "**************************************************"

exit 0
