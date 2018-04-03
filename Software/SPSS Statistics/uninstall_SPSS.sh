#! /bin/bash

###################################################################################################
# Script Name:  uninstall_SPSS.sh
# By:  Zack Thompson / Created:  11/1/2017
# Version:  1.2.1 / Updated:  4/2/2018 / By:  ZT
#
# Description:  Remove previous version(s) of SPSS from /Applications
#
###################################################################################################

echo "*****  Uninstall SPSS process:  START  *****"

echo "Searching for existing SPSS instances..."
appPaths=$(/usr/bin/find -E /Applications -iregex ".*[/](SPSS) ?(Statistics) ?([0-9]{2})?[.]app" -type d -prune)

# Verify that a SPSS version was found.
if [[ -z "${appPaths}" ]]; then
	echo "Did not find an instance SPSS!"
else
	# If the machine has multiple SPSS Applications, loop through them...
	while IFS="\n" read -r appPath; do
		# Get the App Bundle name
			appName=$(echo $appPath | /usr/bin/awk -F "/" '{print $NF}')
		# Get only the install path
			installPath=$(echo $appPath | /usr/bin/awk -F "/$appName" '{print $1}')
		# Delete the old version
			echo "Uninstalling:  ${appPath}"
			/bin/rm -rf "${installPath}"
	done < <(echo "${appPaths}")
fi

echo "*****  Uninstall SPSS process:  COMPLETE  *****"

exit 0
