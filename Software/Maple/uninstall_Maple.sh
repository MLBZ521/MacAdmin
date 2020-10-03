#! /bin/bash

###################################################################################################
# Script Name:  uninstall_Maple.sh
# By:  Zack Thompson / Created:  3/26/2020
# Version:  1.0.0 / Updated:  3/26/2020 / By:  ZT
#
# Description:  Remove previous version(s) of Maple from /Applications
#
###################################################################################################

echo "*****  Uninstall Maple process:  START  *****"

echo "Searching for existing Maple instances..."
appPaths=$( /usr/bin/find -E /Applications -iregex ".*[/]Maple [0-9]{4}[.]app" -type d -prune -maxdepth 1 )

# Verify that a Maple version was found.
if [[ -z "${appPaths}" ]]; then
	echo "Did not find an instance Maple!"

else
	# If the machine has multiple Maple Applications, loop through them...
	while IFS="\n" read -r appPath; do

		# Get the App Bundle name
		appName=$( echo "${appPath}" | /usr/bin/awk -F "/" '{print $NF}' )

		# Delete the old version
		echo "Uninstalling:  ${appName}"
		/bin/rm -rf "${appPath}"

	done < <(echo "${appPaths}")
fi

echo "*****  Uninstall Maple process:  COMPLETE  *****"

exit 0