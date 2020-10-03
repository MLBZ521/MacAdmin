#! /bin/bash

###################################################################################################
# Script Name:  uninstall_Matlab.sh
# By:  Zack Thompson / Created:  3/26/2020
# Version:  1.0.0 / Updated:  3/26/2020 / By:  ZT
#
# Description:  Remove previous version(s) of Matlab from /Applications
#
###################################################################################################

echo "*****  Uninstall Matlab process:  START  *****"

echo "Searching for existing Matlab instances..."
appPaths=$( /usr/bin/find -E /Applications -iregex ".*[/]MATLAB_R[0-9]{4}[ab][.]app" -type d -prune -maxdepth 1 )

# Verify that a Matlab version was found.
if [[ -z "${appPaths}" ]]; then
	echo "Did not find an instance Matlab!"

else
	# If the machine has multiple Matlab Applications, loop through them...
	while IFS="\n" read -r appPath; do

		# Get the App Bundle name
		appName=$( echo "${appPath}" | /usr/bin/awk -F "/" '{print $NF}' )

		# Delete the old version
		echo "Uninstalling:  ${appName}"
		/bin/rm -rf "${appPath}"

	done < <(echo "${appPaths}")
fi

echo "*****  Uninstall Matlab process:  COMPLETE  *****"

exit 0