#!/bin/bash

###################################################################################################
# Script Name:  uninstall_QGIS.sh
# By:  Zack Thompson / Created:  7/29/2019
# Version:  1.0.0 / Updated:  7/29/2019 / By:  ZT
#
# Description:  This script installs all the packages that are contained in the QGIS dmg.
#
###################################################################################################

echo "*****  Uninstall QGIS Process:  START  *****"

# Check if QGIS is currently installed...
appPaths=$(/usr/bin/find -E /Applications -iregex ".*[/]QGIS\s?([0-9.]*)?[.]app" -type d -maxdepth 1 -prune)

if [[ ! -z "${appPaths}" ]]; then
	echo "QGIS is currently installed; removing this instance before continuing..."

	# If the machine has multiple QGIS Applications, loop through them...
	while IFS="\n" read -r appPath; do
		echo "Deleting:  ${appPath}"
		/bin/rm -rf "${appPath}"
	done < <(echo "${appPaths}")

	echo "QGIS has been removed."
fi

echo "*****  Uninstall QGIS Process:  COMPLETE  *****"

exit 0