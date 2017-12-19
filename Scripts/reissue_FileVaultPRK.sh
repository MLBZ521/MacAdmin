#!/bin/bash

###################################################################################################
# Script Name:  reissue_FileVaultPRK.sh
# By:  Zack Thompson / Created:  12/19/2017
# Version:  1.0 / Updated:  12/19/2017 / By:  ZT
#
# Description:  This script creates a new FileVault Personal Recovery Key by passing a valid Unlock Key via JSS Parameter to the Script.
#		- A valid Unlock Key can be any of:  a user account password or current Personal Recovery Key
#
###################################################################################################

/usr/bin/logger -s "*****  FileVault Key Reissue process:  START  *****"

##################################################
# Define Variables

cmdFileVault="/usr/bin/fdesetup"
# Check if machine is FileVault enabled
	fvStatus=$($cmdFileVault isactive)

##################################################
# Now that we have our work setup...

if [[ $fvStatus == "true" ]]; then
	/usr/bin/logger -s "Machine is FileVault Encrypted."

	$cmdFileVault changerecovery -personal -inputplist <<XML
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
<key>Password</key>
<string>$4</string>
</dict>
</plist>
XML 1> /dev/null

else
	/usr/bin/logger -s "Machine is not FileVault Encrypted."
fi

/usr/bin/logger -s "*****  FileVault Key Reissue process:  COMPLETE  *****"

exit 0
