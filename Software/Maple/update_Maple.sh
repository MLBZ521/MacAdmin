#!/bin/sh

###################################################################################################
# Script Name:  update_Maple.sh
# By:  Zack Thompson / Created:  3/2/2017
# Version:  1.1 / Updated:  4/4/2017 / By:  ZT
#
# Description:  This script installs silent installs Maple 2016 patches.
#
###################################################################################################

cd /tmp/Maple2016.2

./Maple2016.2MacUpgrade.app/Contents/MacOS/installbuilder.sh --optionfile /tmp/Maple2016.2/installer.properties

Echo 'Maple has been installed!'

exit 0