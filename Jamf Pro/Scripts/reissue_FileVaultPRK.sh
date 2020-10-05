#!/bin/bash

###################################################################################################
# Script Name:  reissue_FileVaultPRK.sh
# By:  Zack Thompson / Created:  12/19/2017
# Version:  1.2.1 / Updated:  10/5/2020 / By:  ZT
#
# Description:  This script creates a new FileVault Personal Recovery Key by passing a valid Unlock Key via JSS Parameter to the Script.
#		- A valid Unlock Key can be any of:  a password for a FileVault enabled user account or current Personal Recovery Key
#
#	Modern FileVault Logic details can be found in the "FDE Recovery Key Escrow Payload" section documented here:  
#		https://developer.apple.com/enterprise/documentation/Configuration-Profile-Reference.pdf
#
#	Some bits are inspired by Elliot Jordan's project:  https://github.com/homebysix/jss-filevault-reissue
#
###################################################################################################

echo "*****  FileVault Key Reissue process:  START  *****"

##################################################
# Define Variables

exitValue=0
cmdFileVault="/usr/bin/fdesetup"
checkModernPRK="/var/db/FileVaultPRK.dat"
# Substitute XML reserved characters
fvPW=$(echo "${4}" | /usr/bin/sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g')
# Get the OS Version
osMinorVersion=$(/usr/bin/sw_vers -productVersion | /usr/bin/awk -F '.' '{print $2}')
# Check if machine is FileVault enabled
fvStatus=$($cmdFileVault isactive)
# Set Profile Identifiers 
legacyProfileID=""
modernProfileID=""

##################################################
# Bits staged...

if [[ $(/usr/bin/profiles -Cv | /usr/bin/grep --quiet --fixed-strings --regexp="${legacyProfileID}" --regexp="${modernProfileID}") -ne 0 ]]; then
	echo "This device is missing the required FileVault Redirection Configuration Profile."
	echo "*****  FileVault Key Reissue process:  FAILED  *****"
	exit 1
fi

if [[ $fvStatus == "true" ]]; then
	echo "Machine is FileVault Encrypted."

	if [[ "${osMinorVersion}" -ge 13 && -e "${checkModernPRK}" ]]; then
		echo "Found pre-existing PRK data file; recording details..."
		preCheckPRK=$(/usr/bin/stat -f "%Sm" -t "%s" "${checkModernPRK}")
	fi

	$cmdFileVault changerecovery -personal -inputplist &> /dev/null <<XML
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
<key>Password</key>
<string>$fvPW</string>
</dict>
</plist>
XML

	exitCode=$?

	# Clear password variable.
	unset fvPW

	if [[ $exitCode != 0 ]]; then
		echo "Failed to issue a new Recovery Key."
		echo "\`fdesetup\` exit code was:  ${exitCode}"
		echo "The list of exit codes and their meaning can be found here:  https://developer.apple.com/legacy/library/documentation/Darwin/Reference/ManPages/man8/fdesetup.8.html"
		echo "*****  FileVault Key Reissue process:  FAILED  *****"
		exit 2
	fi

	if [[ "${osMinorVersion}" -ge 13 && -e "${checkModernPRK}" ]]; then
		postCheckPRK=$(/usr/bin/stat -f "%Sm" -t "%s" "${checkModernPRK}")

		if [[ $postCheckPRK -gt $preCheckPRK ]]; then	
			echo "PRK Data file has been updated, running a Jamf Recon to Escrow the new Key."
			# This Inventory/Recon should Escrow the key and the next Recon should validate it.
			/usr/local/bin/jamf recon 2&1>>/dev/null
		else
			echo "WARNING:  The PRK Data file does not appear to have been updated.  Reissue attempt may have failed."
			exitValue=3
		fi
	fi
else
	echo "Machine is not FileVault Encrypted."
fi

echo "*****  FileVault Key Reissue process:  COMPLETE  *****"

exit $exitValue