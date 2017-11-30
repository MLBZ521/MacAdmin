#!/bin/bash

###################################################################################################
# Script Name:  iamRoot_LockdownRoot.sh
# By:  Zack Thompson / Created:  11/28/2017
# Version:  1.0 / Updated:  11/28/2017 / By:  ZT
#
# Description:  This script is designed to block login access to the root account on macOS. It does this with the following actions:
#		1)  Sets the root account's password to a randomized 32 character string
#		2)  Sets the root account's login shell to /usr/bin/false
#
# Borrowed and modified from:  https://github.com/rtrouton/rtrouton_scripts/tree/master/rtrouton_scripts/block_root_account_login
# 		+ Along with bits and pieces from @doggles and others on the MacAdmins Slack
#
###################################################################################################

/bin/echo "*****  disable_Root Process:  START  *****"

# Generate a new password to a randomized 32 character string
	newPassword=$(LC_CTYPE=C /usr/bin/tr -dc 'A-Za-z0-9_\@\#\^\&\(\)-+=' < /dev/urandom | /usr/bin/head -c 32)
# Set the root accounts' password
	/bin/echo "Setting new password..."
	/usr/bin/dscl . -passwd /Users/root "${rootpassword}"
# Get the current shell for root
	rootshell=$(/usr/bin/dscl . -read /Users/root UserShell | /usr/bin/awk '{print $2}')

# Disable root login by setting root's shell to /usr/bin/false.
if [[ -z "${rootshell}" ]]; then
	# If root shell is blank or otherwise not set, use dscl to set the shell to:  /usr/bin/false
	/bin/echo "Setting blank root shell to /usr/bin/false"
	/usr/bin/dscl . -create /Users/root UserShell /usr/bin/false
else
	# If root shell is set to an existing value, use dscl to change the shell from the existing value and set it to:  /usr/bin/false
	/bin/echo "Changing root shell from ${rootshell} to /usr/bin/false"
	/usr/bin/dscl . -change /Users/root UserShell "${rootshell}" /usr/bin/false
fi

/bin/echo "*****  disable_Root Process:  COMPLETE  *****"

exit 0
