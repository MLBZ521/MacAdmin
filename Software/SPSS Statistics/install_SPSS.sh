#! /bin/sh

###################################################################################################
# Script Name:  install_SPSS.sh
# By:  Zack Thompson / Created:  11/1/2017
# Version:  1.1 / Updated:  11/2/2017 / By:  ZT
#
# Description:  This script silently installs SPSS.
#
###################################################################################################

/bin/echo "**************************************************"
/bin/echo 'Starting PostInstall Script'
/bin/echo "**************************************************"

# Install prerequisite:  Java JDK
/bin/echo "Installing prerequisite Java JDK from Jamf..."
/usr/local/bin/jamf policy -id 721

# Set working directory
pkgDir=$(/usr/bin/dirname $0)

# Silent install using information in the installer.properties file
/bin/echo "Installing SPSS..."
./SPSS_Statistics_Installer.bin -f ./installer.properties

/bin/echo "Install complete!"

/bin/echo "**************************************************"
/bin/echo 'PostInstall Script Finished'
/bin/echo "**************************************************"

exit 0
