#!/bin/bash

###################################################################################################
# Script Name:  install_Mathematica.sh
# By:  Zack Thompson / Created:  1/10/2018
# Version:  1.4.0 / Updated:  9/20/2019 / By:  ZT
#
# Description:  This script silently installs Mathematica.
#
###################################################################################################

echo "*****  Install Mathematica process:  START  *****"

##################################################
# Define Variables

# Set working directory
pkgDir=$(/usr/bin/dirname "${0}")

##################################################
# Define Functions

exitCheck() {
	if [[ $1 != 0 ]]; then
		echo "Failed to install:  ${2}"
		echo "Exit Code:  ${1}"
		echo "*****  Install Mathematica process:  FAILED  *****"
		exit 1
	else
		echo "${2} has been installed!"
	fi
}

##################################################
# Bits staged...

# Check if Mathematic is already installed.
if [[ -e "/Applications/Mathematica.app" ]]; then
	echo "Mathematica is currently installed, removing..."
	/bin/rm -rf "/Applications/Mathematica.app"
fi

echo "Installing Mathematica.app..."

# Install Mathematica
/bin/mv "${pkgDir}/Mathematica.app" /Applications
exitCode1=$?

# Function exitCheck
exitCheck $exitCode1 "Mathematica.app"

# Get all of the pkgs.
packages=$( /bin/ls "${pkgDir}/" | /usr/bin/grep .pkg )

# Loop through each .pkg in the directory...
while IFS=.pkg read pkg; do
	echo "Installing ${pkg}..."
	/usr/sbin/installer -dumplog -verbose -pkg "${pkgDir}/${pkg}" -allowUntrusted -target /
	exitCode2=$?

	# Function exitCheck
	exitCheck $exitCode2 "${pkg}"

done < <(echo "${packages}")

echo "*****  Install Mathematica process:  COMPLETE  *****"

exit 0