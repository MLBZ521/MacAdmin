#!/bin/sh

###########################################################
# Script Name:  install_MatLab.sh
# By:  Zack Thompson / Created:  3/6/2017
# Version:  1.2 / Updated:  11/27/2017 / By:  ZT
#
# Description:  This script is used to install and activate MatLab with a Network License Server.
#
###########################################################

/bin/echo "**************************************************"
/bin/echo 'Starting PostInstall Script'
/bin/echo "**************************************************"

# Set working directory
	pkgDir=$(/usr/bin/dirname $0)

# Inject the location to the installer.properties file
	LANG=C /usr/bin/sed -i '' 's,licensePath=,&'"${pkgDir}/network.lic"',' ./installer_input.txt

# Install MatLab via built-in script and option file.
	./Matlab_2017b_Mac/InstallForMacOSX.app/Contents/MacOS/InstallForMacOSX -mode silent -inputFile ./installer_input.txt

/bin/echo 'MatLab has been installed!'

/bin/echo "**************************************************"
/bin/echo 'PostInstall Script Finished'
/bin/echo "**************************************************"

exit 0
