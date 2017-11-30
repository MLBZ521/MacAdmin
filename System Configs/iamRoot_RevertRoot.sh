#!/bin/bash

###################################################################################################
# Script Name:  iamRoot_RevertRoot.sh
# By:  Zack Thompson / Created:  11/29/2017
# Version:  1.0 / Updated:  11/29/2017 / By:  ZT
#
# Description:  This script is designed to disable the root account after modifying to for the IamRoot security bug.  These are the following actions taken:
#		1)  Disables the root account -- Removed, this is done by the "Security Update 2017-001" patch
#		2)  Sets the root account's login shell back to /bin/sh -- This may be done as well, but just in case...
#
# Borrowed and modified from:  https://github.com/rtrouton/rtrouton_scripts/tree/master/rtrouton_scripts/block_root_account_login
# 		+ Along with bits and pieces from @doggles and others on the MacAdmins Slack
#
###################################################################################################

/bin/echo "*****  disable_Root Process:  START  *****"

# Disable the root account
#   /bin/echo "Disabling the root account..."
#   /usr/sbin/dsenableroot -d

# Get the current shell for root
	rootshell=$(/usr/bin/dscl . -read /Users/root UserShell | /usr/bin/awk '{print $2}')

# Revert shell back to the original shell (/bin/sh)
if [[ -z "${rootshell}" ]]; then
   # If root shell is blank or otherwise not set, use dscl to set the shell to:  /bin/sh
   /bin/echo "Setting blank root shell to /bin/sh"
   /usr/bin/dscl . -create /Users/root UserShell /bin/sh
elif [[ "${rootshell}" != "/bin/sh" ]]; then
   # If root shell is set to an existing value, use dscl to change the shell from the existing value and set it to:  /bin/sh
   /bin/echo "Changing root shell from ${rootshell} to /bin/sh"
   /usr/bin/dscl . -change /Users/root UserShell "${rootshell}" /bin/sh
fi

/bin/echo "*****  disable_Root Process:  COMPLETE  *****"

exit 0
