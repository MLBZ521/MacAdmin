#!/bin/bash

###################################################################################################
# Script Name:  license_VMwareFusion.sh
# By:  Zack Thompson / Created:  12/14/2017
# Version:  1.0 / Updated:  12/14/2017 / By:  ZT
#
# Description:  This script will apply a VMware Fusion License provided as a JSS Script Parameter.
#		- Supports VMware Fusion 4.x and later.
#		- See:  https://kb.vmware.com/s/article/1009244 and the "Initialize VMware Fusion.tool" script
#
###################################################################################################

/bin/echo "*****  license_VMwareFusion Process:  START  *****"

# Define Variables
FusionApp="/Applications/VMware Fusion.app"

if [[ ! -x $FusionApp ]]; then
	/bin/echo "Error:  VMware Fusion is not properly installed."
	/bin/echo "*****  license_VMwareFusion Process:  FAILED  *****"
	exit 1
else
	/bin/echo "Applying the VMware Fusion license..."
	"${FusionApp}/Contents/Library/Initialize VMware Fusion.tool" set "" "" $4
	exitCode=$?

	if [[ $exitCode = 0 ]]; then
		/bin/echo "VMware Fusion has been licensed!"
		/bin/echo "*****  license_VMwareFusion Process:  COMPLETE  *****"
	else
		/bin/echo "Error:  License was likely invalid."
		/bin/echo "*****  license_VMwareFusion Process:  FAILED  *****"
		exit 2
fi

exit 0