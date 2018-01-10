#!/bin/sh

###################################################################################################
# Script Name:  update_Maple.sh
# By:  Zack Thompson / Created:  3/2/2017
# Version:  1.0 / Updated:  3/2/2017 / By:  ZT
#
# Description:  This script installs silent installs Maple 2016.1.
#
###################################################################################################

cd /tmp/Maple2016.1

./Maple2016.1MacUpgrade.app/Contents/MacOS/installbuilder.sh --optionfile /tmp/Maple2016.1/installer.properties

Echo 'Maple has been installed!'

exit 0