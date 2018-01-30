#! /bin/bash

###################################################################################################
# Script Name:  uninstall_SPSS.sh
# By:  Zack Thompson / Created:  11/1/2017
# Version:  1.2 / Updated:  1/25/2018 / By:  ZT
#
# Description:  Remove previous version(s) of SPSS from /Applications
#
###################################################################################################

/bin/echo "*****  Uninstall SPSS process:  START  *****"

/bin/echo "Searching for existing SPSS instances..."
appPaths=$(/usr/bin/find -E /Applications -iregex ".*[/](SPSS) ?(Statistics) ?([0-9]{2})?[.]app" -type d -prune)

# Verify that a SPSS version was found.
if [[ -z "${appPaths}" ]]; then
	/bin/echo "Did not find an instance SPSS!"
else
	# If the machine has multiple SPSS Applications, loop through them...
	while IFS="\n" read -r appPath; do
		# Get the App Bundle name
			appName=$(/bin/echo $appPath | /usr/bin/awk -F "/" '{print $NF}')
		# Get only the install path
			installPath=$(/bin/echo $appPath | /usr/bin/awk -F "/$appName" '{print $1}')
		# Delete the old version
			/bin/echo "Uninstalling:  ${appPath}"
			/bin/rm -rf "${installPath}"
	done < <(/bin/echo "${appPaths}")
fi

/bin/echo "*****  Uninstall SPSS process:  COMPLETE  *****"

exit 0
