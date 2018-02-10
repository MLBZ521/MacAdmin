#!/bin/bash

###################################################################################################
# Script Name:  fix_UserHomeDirectory.sh
# By:  Zack Thompson / Created:  1/11/2018
# Version:  1.0 / Updated:  1/11/2018 / By:  ZT
#
# Description:  This script fixes an incorrectly configured user account Home Directory
#
###################################################################################################

username="$4"

homeDir=$(/usr/bin/dscl . read /Users/$username/ NFSHomeDirectory | /usr/bin/awk -F ": " '{print $2}')

if [[ $homeDir == "//"* ]]; then
	/bin/echo "Incorrect home directory...  Fixing..."
	/usr/bin/dscl . -change $homeDir NFSHomeDirectory $homeDir /Users/$username
fi

/bin/echo "Correct home directory set!"

exit 0