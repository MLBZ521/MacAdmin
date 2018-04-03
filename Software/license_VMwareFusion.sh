#!/bin/bash

###################################################################################################
# Script Name:  license_VMwareFusion.sh
# By:  Zack Thompson / Created:  12/14/2017
# Version:  1.0.2 / Updated:  3/30/2018 / By:  ZT
#
# Description:  This script will apply a VMware Fusion License provided as a JSS Script Parameter.
#		- Supports VMware Fusion 4.x and later.
#		- See:  https://kb.vmware.com/s/article/1009244 and the "Initialize VMware Fusion.tool" script
#
###################################################################################################

echo "*****  license_VMwareFusion Process:  START  *****"

# Define Variables
FusionApp="/Applications/VMware Fusion.app"

if [[ ! -x "${FusionApp}" ]]; then
	echo "Error:  VMware Fusion is not properly installed."
	echo "*****  license_VMwareFusion Process:  FAILED  *****"
	exit 1
else
	echo "Applying the VMware Fusion license..."
	"${FusionApp}/Contents/Library/Initialize VMware Fusion.tool" set "" "" $4
	exitCode=$?

	if [[ $exitCode = 0 ]]; then
		echo "VMware Fusion has been licensed!"
		echo "*****  license_VMwareFusion Process:  COMPLETE  *****"
	else
		echo "Error:  License was likely invalid."
		echo "*****  license_VMwareFusion Process:  FAILED  *****"
		exit 2
	fi
fi

exit 0