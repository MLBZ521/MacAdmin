#!/bin/bash

###################################################################################################
# Script Name:  Remove-LocalAdminRights.sh
# By:  Zack Thompson / Created:  2/14/2020
# Version:  1.0.0 / Updated:  2/14/2020 / By:  ZT
#
# Description:  This script removes local accounts from the local admin group; accounts that are 
# 		desired to be in the group are be specified from the Jamf Pro script parameter 4
#
###################################################################################################

echo "*****  Remove-LocalAdminRights Process:  START  *****"

##################################################
# Define Variables

prod="https://prod.jps.server.com:8443/"
prod_jma="jma"
dev="https://dev.jps.server.com:8443/"
dev_jma="jmadev"

##################################################
# Build protected_admins array

protected_admins=()
protected_admins+=("root")

# If parameters were provided, loop through them.
if [[ -n $4 ]]; then
	IFS=", " read accounts <<< $4

	for account in $accounts; do
		protected_admins+=("${account}")
	done
fi

# Check the local environment and remove the proper account
if [[ -e "/Library/Preferences/com.jamfsoftware.jamf.plist" ]]; then
    jss_url=$( /usr/bin/defaults read "/Library/Preferences/com.jamfsoftware.jamf" jss_url )

    if [[ "${jss_url}" == "${prod}" ]]; then
        protected_admins+=("${prod_jma}")
    elif [[ "${jss_url}" == "${dev}" ]]; then
        protected_admins+=("${dev_jma}")
    else
        echo "ERROR:  Unknown Jamf Pro environment!"
        exit 2
    fi
else
    echo "ERROR:  Issue with the Jamf Framework!"
    exit 1
fi

##################################################
# Bits staged...

exit_code=0

# Get a list of the current admin group
admin_users=$( /usr/bin/dscl . -read Groups/admin GroupMembership | /usr/bin/awk -F "GroupMembership: " '{print $2}' )

# For verbosity in the policy log
echo "The following accounts are in the local admin group:"
for user in $admin_users; do
	echo " - ${user}"
done

# Loop through the admin users
for user in $admin_users; do

	echo -e "${user} - "

	# Check if the admin user is a protected_admin
	if [[ "${protected_admins[*]}" == *"${user}"* ]]; then

		# Remove user from the admin group
		/usr/sbin/dseditgroup -o edit -d "${user}" -t user admin
		exit_code_check=$?

		# Check if the removal was successful
		if [ $exit_code_check == "0" ]; then
			echo "removed from admin group"
		else
			echo "FAILED to remove from admin group"
			exit_code=1
		fi

	else
		echo "protected admin"
	fi

done

# Get an updated list of the local admin group
updatedLocalAdminGroup=$( /usr/bin/dscl . -read Groups/admin GroupMembership | /usr/bin/awk -F "GroupMembership: " '{print $2}' )

# For verbosity in the policy log
echo "Updated local admin group:"
for user in $updatedLocalAdminGroup; do
	echo " - ${user}"
done

echo "*****  Remove-LocalAdminRights Process:  COMPLETE  *****"
exit $exit_code