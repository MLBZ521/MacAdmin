#!/bin/sh

###################################################################################################
# Script Name:  install_Maple.sh
# By:  Zack Thompson / Created:  3/2/2017
# Version:  1.0 / Updated:  3/2/2017 / By:  ZT
#
# Description:  This script installs silent installs and activates Maple 2016.0 with a network license.
#
###################################################################################################

# Define working directory
cd /tmp/Maple2016.0

# Install Maple via built-in script and option file. 
./Maple2016.0MacInstaller.app/Contents/MacOS/installbuilder.sh --optionfile ./installer.properties
Echo 'Maple has been installed!'

# Apple update 'Java for OS X 2015-001' is required for Maples as well, installing that here.
/usr/sbin/installer -dumplog -verbose -pkg ./JavaForOSX.pkg -target /
Echo 'Java installed!'

exit 0