#!/bin/bash

###################################################################################################
# Script Name:  delete_Account.sh
# By:  Zack Thompson / Created:  2/8/2018
# Version:  1.0 / Updated:  2/8/2018 / By:  ZT
#
# Description:  This script checks if the accounts exists and deletes it and removes the home directory.
#
###################################################################################################

# Account to delete.
account="cas"

# Check if the account exists (and grab it's home directory at the same time).
checkIfExists=$(/usr/bin/dscl . -read /Users/$account NFSHomeDirectory | /usr/bin/awk '{print $2}')

# dscl will exit zero if the account exists
if [[ $checkIfExists != *"eDSRecordNotFound"* ]]; then
	/bin/echo "Accounts $account exists!  Deleting it now..."
	/usr/bin/dscl . delete /Users/$account
	/bin/echo "Account has been deleted!"
	/bin/rm -Rf "${checkIfExists}"
	/bin/echo "Removed home directory!"
else
	/bin/echo "Account does not exist!"
fi

exit 0