#!/bin/bash

###################################################################################################
# Script Name:  license_Parallels.sh
# By:  Zack Thompson / Created:  8/17/2017
# Version:  1.2 / Updated:  1/18/2018 / By:  ZT
#
# Description:  This script will apply a Parallels License provided as a JSS Script Parameter.
#
###################################################################################################

/bin/echo "*****  license_Parallels Process:  START  *****"

# Define Variables
Parallels="/Applications/Parallels Desktop.app/Contents/MacOS/prlsrvctl"

if [[ ! -x $Parallels ]]; then
	/bin/echo "Error:  Parallels is not properly installed."
	/bin/echo "*****  license_Parallels Process:  FAILED  *****"
	exit 1
else
	/bin/echo "Applying the Parallels license..."
	$Parallels install-license --key $4
	exitCode=$?

	if [[ $exitCode = 0 ]]; then
		/bin/echo "Parallels has been licensed!"
		/bin/echo "*****  license_Parallels Process:  COMPLETE  *****"
	else
		/bin/echo "Error:  License was likely invalid."
		/bin/echo "*****  license_Parallels Process:  FAILED  *****"
		exit 2
	fi
fi

exit 0