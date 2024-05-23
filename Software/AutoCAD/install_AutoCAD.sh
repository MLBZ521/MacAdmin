#!/bin/bash

###################################################################################################
# Script Name:  install_AutoCAD.sh
# By:  Zack Thompson / Created:  9/2/2020
# Version:  1.2.0 / Updated:  8/24/2021 / By:  ZT
#
# Description:  This script silently installs AutoCAD 2021 and newer.
#
###################################################################################################

echo -e "*****  Install AutoCAD Process:  START  *****\n"

# Check the installation target.
if [[ $3 != "/" ]]; then
	echo "ERROR:  Target disk is not the startup disk."
	echo "*****  Install AutoCAD process:  FAILED  *****"
	exit 1
fi

##################################################
# Define Variables

# Set working directory
pkgDir=$( /usr/bin/dirname "${0}" )

# Get the filename of the .app file
AutoCADinstaller=$( /bin/ls "${pkgDir}" | /usr/bin/grep .app )

##################################################
# Define Functions

exitCheck() {
	if [[ $1 != 0 ]]; then

		echo "Failed to install:  ${2}"
		echo "Exit Code:  ${1}"
		echo "Reason:  ${3}"
		echo "*****  Install AutoCAD process:  FAILED  *****"
		exit 2

	else

		echo "${2} has been installed!"

	fi
}

##################################################
# Bits staged...

# "New" silent install method...that does not work when run in a cli installed .pkg (but does seem to work when installing that .pkg via GUI...)
# installResult=$( "${pkgDir}/${AutoCADinstaller}/Contents/Helper/Setup.app/Contents/MacOS/Setup" --silent --install_mode install --hide_eula  )

# Credit to Onkston for this install method.
# https://www.jamf.com/jamf-nation/discussions/35944/autocad-2021-deployment-with-network-server
pkgArray=$( /usr/bin/find -E "${pkgDir}/${AutoCADinstaller}/Contents/Helper" -iregex ".*[/].*[.]pkg" -prune )

# Verify at least one version of SPSS was found.
if [[ -z "${pkgArray}" ]]; then

	exitCheck 3 "ERROR:  Unable to locate .pkgs in the expected location!"

else

	# Loop through each .pkg in the array.
	while IFS=$'\n' read -r pkg; do

		echo "Installing ${pkg}..."
		installResult=$( /usr/sbin/installer -dumplog -verbose -pkg "${pkg}" -allowUntrusted -target / )
		exitCode=$?

		# Function exitCheck
		exitCheck $exitCode "${pkg}" "${installResult}"

	done < <( echo "${pkgArray}" )

fi

echo "All components have been installed."
echo "AutoCAD has been installed!"
echo -e "\n*****  Install AutoCAD Process:  COMPLETE  *****"
exit 0