#! /bin/sh

###################################################################################################
# Script Name:  install_SPSS.sh
# By:  Zack Thompson / Created:  11/1/2017
# Version:  1.0 / Updated:  11/1/2017 / By:  ZT
#
# Description:  This script silently installs SPSS.
#
###################################################################################################

/bin/echo "**************************************************"
/bin/echo 'Starting PostInstall Script'
/bin/echo "**************************************************"

# Set working directory
pkgDir=$(/usr/bin/dirname $0)

# Silent install using information in the installer.properties file
./SPSS_Statistics_Installer.bin -f ./installer.properties

/bin/echo "**************************************************"
/bin/echo 'PostInstall Script Finished'
/bin/echo "**************************************************"

exit 0
