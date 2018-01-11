#!/bin/sh

###########################################################
# Script Name:  license_Minitab.sh
# By:  Zack Thompson / Created:  3/6/2017
# Version:  1.0 / Updated:  3/6/2017 / By:  ZT
#
# Description:  This script is used activate Minitab with a Network License Server.
#
###########################################################

# All that is required is to write in the plist file the name of the license server.
Echo "Adding network server address for activation..."
sudo defaults write /Library/Application\ Support/Minitab/Minitab\ Express/mtblic.plist "License File" @server.company.com

# Set permissions on the file for everyone to be able to read.
sudo chmod 644 /Library/Application\ Support/Minitab/Minitab\ Express/mtblic.plist

Echo "Configuration Complete!"

exit 0
