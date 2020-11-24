#!/bin/bash

###################################################################################################
# Script Name:  install_AutoCAD.sh
# By:  Zack Thompson / Created:  9/2/2020
# Version:  1.1.0 / Updated:  11/24/2020 / By:  ZT
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

# "New" silent install method...that does not work when run in cli installed .pkg (but does seem to work when installing that .pkg via GUI...)
# installResult=$( "${pkgDir}/${AutoCADinstaller}/Contents/Helper/Setup.app/Contents/MacOS/Setup" --silent --install_mode install --hide_eula  )

# Create an array of .pkg's to install
# Credit to Onkston for this install method.
# https://www.jamf.com/jamf-nation/discussions/35944/autocad-2021-deployment-with-network-server
declare -a pkgArray
pkgArray+=( "${pkgDir}/${AutoCADinstaller}/Contents/Helper/ObjToInstall/lib.pkg" )
pkgArray+=( "${pkgDir}/${AutoCADinstaller}/Contents/Helper/Packages/AdSSO/AdSSO-v2.pkg" )
pkgArray+=( "${pkgDir}/${AutoCADinstaller}/Contents/Helper/Packages/Licensing/$( /bin/ls "${pkgDir}/${AutoCADinstaller}/Contents/Helper/Packages/Licensing/" | /usr/bin/grep .pkg )" )
pkgArray+=( "${pkgDir}/${AutoCADinstaller}/Contents/Helper/ObjToInstall/licreg.pkg" )
pkgArray+=( "${pkgDir}/${AutoCADinstaller}/Contents/Helper/ObjToInstall/autocad2021.pkg" )

# Loop through each .pkg in the array.
for pkg in "${pkgArray[@]}"; do

	echo "Installing ${pkg}..."
	installResult=$( /usr/sbin/installer -dumplog -verbose -pkg "${pkg}" -allowUntrusted -target / )
	exitCode=$?

	# Function exitCheck
	exitCheck $exitCode "${pkg}" "${installResult}"

done

echo "All components have been installed."
echo "AutoCAD has been installed!"
echo -e "\n*****  Install AutoCAD Process:  COMPLETE  *****"
exit 0