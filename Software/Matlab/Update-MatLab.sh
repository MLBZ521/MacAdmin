#!/bin/bash

###################################################################################################
# Script Name:  Update-MatLab.sh
# By:  Zack Thompson / Created:  4/1/202021
# Version:  1.0.0 / Updated:  4/1/202021 / By:  ZT
#
# Description:  This script updates MatLab.
#
###################################################################################################

echo "*****  Update Matlab process:  START  *****"

##################################################
# Define Variables

# Set working directory
pkgDir=$( /usr/bin/dirname "${0}" )
# Version that's being updated (this will be set by the autopkg process)
version=""

##################################################
# Bits staged...

echo "Searching for existing Matlab instances..."
appPaths=$( /usr/bin/find -E /Applications -iregex ".*[/]MATLAB_R[0-9]{4}[ab][.]app" -type d -prune -maxdepth 1 )

# Verify that a Matlab version was found.
if [[ -z "${appPaths}" ]]; then

	echo "Did not find an instance Matlab!"
    exit 1

else

	# If the machine has multiple Matlab Applications, loop through them...
	while IFS=$'\n' read -r appPath; do

        if [[ "${appPath}" == *"${version}"* ]]; then

            echo "Updating Matlab version:  ${version}"
            exit_status=$( "${appPath}/bin/maci64/update_installer" -updatepackage "${pkgDir}/" )
            exit_code=$?

        fi

	done < <(echo "${appPaths}")

fi

if [[ $exit_code != 0 ]]; then
	echo "Exit Code:  ${exit_code}"
fi

if [[ $exit_status == *"End - Unsuccessful"* ]]; then
	echo "ERROR:  Update failed!"
	echo "ERROR Content:  ${exit_status}"
	echo "*****  Update Matlab process:  FAILED  *****"
	exit 2
fi

echo "Update complete!"
echo "*****  Update Matlab process:  COMPLETE  *****"
exit 0