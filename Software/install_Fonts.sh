#!/bin/bash

###################################################################################################
# Script Name:  install_Fonts.sh
# By:  Zack Thompson / Created:  8/13/2015
# Version:  1.0 / Updated:  8/13/2015 / By:  ZT
# ChangeLog:
#	v1.0 = First Production Version
#
# Description:  This script copies all the fonts to the System Fonts folder.
#
###################################################################################################

# Copy the all font files to the System Fonts folder.
cp -r /Library/IT_Staging/ /Library/Fonts/

# Delete all font files.
rm /Library/IT_Staging/*

exit 0