#!/bin/bash

###########################################################
# Script Name:  install_DesktopShortcuts.sh
# By:  Zack Thompson / Created:  9/4/2015
# Version:  1.1 / Updated:  8/15/2017 / By:  ZT
#
# Description:  This is a script to deploy Desktop Shortcuts to the logged in user and default users profiles.
#
###########################################################

# Check for local user profiles and then copy files into their Desktop Folders.
# The if statement is just to make sure we do not copy to the Guest and Shared Profiles.
for users in $(ls /Users)
	do
		if [[ $users != "Guest" || $users != "Shared" ]]; then
			sudo -u $users cp /Library/IT_Staging/*.webloc /Users/$users/Desktop/
		fi
done

# Copy over Desktop Shortcuts for New Users
sudo cp /Library/IT_Staging/Intranet.webloc /System/Library/User\ Template/English.lproj/Desktop/
sudo cp /Library/IT_Staging/Kronos\ Workforce\ Central.webloc /System/Library/User\ Template/English.lproj/Desktop/
sudo cp /Library/IT_Staging/Support.webloc /System/Library/User\ Template/English.lproj/Desktop/
sudo cp /Library/IT_Staging/Website 1.webloc /System/Library/User\ Template/English.lproj/Desktop/
sudo cp /Library/IT_Staging/Website 2.webloc /System/Library/User\ Template/English.lproj/Desktop/

# Delete all staging files.
rm /Library/IT_Staging/*

exit 0