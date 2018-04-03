#!/bin/bash

###################################################################################################
# Script Name:  license_Parallels.sh
# By:  Zack Thompson / Created:  8/17/2017
# Version:  1.5.2 / Updated:  3/30/2018 / By:  ZT
#
# Description:  This script will apply a Parallels License provided as a Script Parameter.
#
###################################################################################################

echo "*****  license_Parallels Process:  START  *****"

##################################################
# Define Variables
licenseKey="${4}"
Parallels="/Applications/Parallels Desktop.app/Contents/MacOS/prlsrvctl"
serviceParallels="/Applications/Parallels Desktop.app/Contents/MacOS/Parallels Service.app/Contents/MacOS/prl_disp_service"

##################################################
# Bits staged...

# First, check to make sure that the prlsrvctl binary exists and is executable.
if [[ ! -x "${Parallels}" ]]; then
	echo "Error:  Parallels is not properly installed."
	echo "*****  license_Parallels Process:  FAILED  *****"
	exit 1
else
	# Second, check if the Parallels Service is running, if not, start it.
	if $(! $(/usr/bin/pgrep -xq prl_disp_service)); then
		echo "The Parallels Service is not running -- Starting it now..."
		"${serviceParallels}" &

		# If needed, waiting for the service to start...
		until [[ $(/usr/bin/pkill -0 -ix prl_disp_service -q 2>/dev/null) -eq 0 ]]; do
			echo "Waiting for the Parallels Service to start..."
			/bin/sleep 1
		done
	fi

	# On clean installs, I was still getting the prl_disp_service not started errors on both prlsrvctl commands...adding in a sleep seems to help.
	/bin/sleep 5

	# Third, check the current license status.
	status=$("${Parallels}" info --license | /usr/bin/awk -F "status=" '{print $2}' | /usr/bin/xargs)

	# Fourth, if the current status is active, we'll need to deactivate it, before activating a new license.
	if [[ $status == "ACTIVE" ]]; then
		echo "Machine currently has an active license."
		echo "Deactivating old license..."
		"${Parallels}" deactivate-license
	fi

	# Fifth, install new license.
	echo "Applying the provided license..."
	"${Parallels}" install-license --key "${licenseKey}"
	exitCode=$?

	# Sixth, check the result of installing the license.
	if [[ $exitCode = 0 ]]; then
		echo "Parallels has been licensed!"
		echo "*****  license_Parallels Process:  COMPLETE  *****"
	else
		echo "Error:  License was likely invalid."
		echo "*****  license_Parallels Process:  FAILED  *****"
		exit 2
	fi
fi

exit 0