#!/bin/bash

###################################################################################################
# Script Name:  postinstall_RecoveryHD.sh
# By:  Zack Thompson / Created:  3/13/2018
# Version:  1.0 / Updated:  3/13/2018 / By:  ZT
#
# Description:  This script creates a missing Recovery HD Partition.
#
###################################################################################################

echo "*****  Install RecoveryHD process:  START  *****"

##################################################
# Define Variables
pkgDir=$(/usr/bin/dirname "${0}")  # Set working directory
targetVOL="${3}"
dmtestBinary=$(echo "${pkgDir}/$(/bin/ls "${pkgDir}" | /usr/bin/grep dmtest)")
BaseSystemDMG=$(echo "${pkgDir}/$(/bin/ls "${pkgDir}" | /usr/bin/grep .dmg)")
BaseSystemChunkList=$(echo "${pkgDir}/$(/bin/ls "${pkgDir}" | /usr/bin/grep .chunklist)")

##################################################
# Bits staged...

echo "Creating the missing Recovery HD...."
# Create the Recovery HD Partition
"${dmtestBinary}" ensureRecoveryPartition "${targetVOL}" "${BaseSystemDMG}" 0 0 "${BaseSystemChunkList}"

# Get the Exit Code
exitCode=$?

if [[ $exitCode != 0 ]]; then
	echo "ERROR:  Install failed!"
	echo "Exit Code:  ${exitCode}"
	echo "*****  Install RecoveryHD process:  FAILED  *****"
	exit 1
fi

echo "Install complete!"
echo "*****  Install RecoveryHD process:  COMPLETE  *****"
exit 0