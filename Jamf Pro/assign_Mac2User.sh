#!/bin/bash

###################################################################################################
# Script Name:  assign_Mac2User.sh
# By:  Zack Thompson / Created:  4/18/2017
# Version:  1.0 / Updated:  4/18/2017 / By:  ZT
# ChangeLog:
#	v1.0 = First Production Version
#
# Description:  This script assigns a Mac to a User in JAMF Inventory records for a specific device.
#
###################################################################################################

# Use Apple Script to request information via dialog boxes and assign to variables.

endUsername=$(osascript -e 'set userInput to the text returned of (display dialog "Please enter your domain account:" default answer " ")')

realname=$(osascript -e 'set userInput to the text returned of (display dialog "Please enter your full name:" default answer " ")')

email=$(osascript -e 'set userInput to the text returned of (display dialog "Please enter your email address:" default answer " ")')

phone=$(osascript -e 'set userInput to the text returned of (display dialog "Please enter your phone number:" default answer " ")')


# Run jamf recon and field it the values gathered above.

sudo jamf recon -endUsername "$endUsername" -realname "$realname" -email "$email" -phone "$phone"


exit 0