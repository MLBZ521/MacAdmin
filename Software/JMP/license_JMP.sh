#!/bin/sh

###################################################################################################
# Script Name:  license_JMP.sh
# By:  Zack Thompson / Created:  3/3/2017
# Version:  1.0 / Updated:  3/3/2017 / By:  ZT
#
# Description:  This script activates JMP 13.
#
###################################################################################################

# Set the location of the license file in the system library folder plist.
sudo defaults write /Library/Preferences/com.sas.jmp.plist Setinit_13_Path Library/Application\ Support/JMP/13/JMP.per

# Set permissions on the file for everyone to be able to read.
sudo chmod 644 /Library/Application\ Support/JMP/13/JMP.per 

# Remove the location from the users preference file.
defaults delete ~/Library/Preferences/com.sas.jmp.plist Setinit_13_Path

# Mark as 'registration requested' so it doesn't ask the user.
defaults ~/Library/Application\ Support/JMP/13/License.plist RegistrationRequested Y

Echo 'JMP has been activated!'

exit 0