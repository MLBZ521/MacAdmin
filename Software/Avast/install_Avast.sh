#!/bin/bash

###################################################################################################
# Script Name:  install_Avast.sh
# By:  Zack Thompson / Created:  2/9/2018
# Version:  1.1 / Updated:  2/12/2018 / By:  ZT
#
# Description:  This script installs Avast.
#
###################################################################################################

/bin/echo "*****  Install Avast Process:  START  *****"

##################################################
# Define Variables

# Set working directory
	pkgDir=$(/usr/bin/dirname $0)
# Get the filename of the .dmg file
	AvastDMG=$(/bin/ls "${pkgDir}" | /usr/bin/grep .dmg)

##################################################
# Bits staged...

# Mounting the .dmg found...
	/bin/echo "Mounting ${AvastDMG}..."
	/usr/bin/hdiutil attach "${AvastDMG}" -nobrowse -noverify -noautoopen
	/bin/sleep 2

# Get the name of the mount.
	AvastMount=$(/bin/ls /Volumes/ | /usr/bin/grep Avast)
# Get the name of the pkg
	AvastPKG=$(/bin/ls Volumes/${AvastMount}/ | /usr/bin/grep Avast)

# Install Avast
	/bin/echo "Installing ${AvastMount}..."
	/usr/sbin/installer -dumplog -verbose -pkg "/Volumes/${AvastMount}/${AvastPKG}" -target /
	exitCode=$?
	/bin/sleep 2

# Ejecting the .dmg...
	/usr/bin/hdiutil eject /Volumes/"${AvastMount}"

if [[ $exitCode != 0 ]]; then
	/bin/echo "ERROR:  Install failed!"
	/bin/echo "Exit Code:  ${exitCode}"
	/bin/echo "*****  Install Avast process:  FAILED  *****"
	exit 1
fi

/bin/echo "${AvastMount} has been installed!"
/bin/echo "*****  Install Avast Process:  COMPLETE  *****"

exit 0
