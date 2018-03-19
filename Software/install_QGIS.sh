#!/bin/bash

###################################################################################################
# Script Name:  install_QGIS.sh
# By:  Zack Thompson / Created:  7/26/2017
# Version:  1.2 / Updated:  3/19/2018 / By:  ZT
#
# Description:  This script installs all the packages that are contained in this package.
#
###################################################################################################

echo "*****  Install QGIS Process:  START  *****"

##################################################
# Define Variables

# Set working directory
	pkgDir=$(/usr/bin/dirname $0)
# Get the filename of the .dmg file
	QGISdmg=$(/bin/ls "${pkgDir}" | /usr/bin/grep .dmg)

##################################################
# Define Functions

exitCheck() {
	if [[ $1 != 0 ]]; then
		echo "Failed to install:  ${2}"
		echo "Exit Code:  ${1}"
		echo "*****  Install QGIS process:  FAILED  *****"

		# Ejecting the .dmg...
		/usr/bin/hdiutil eject /Volumes/"${QGISMount}"

		exit 2
	else
		echo "${2} has been installed!"
	fi
}

##################################################
# Bits staged...

# Check the installation target.
if [[ $3 != "/" ]]; then
	/bin/echo "ERROR:  Target disk is not the startup disk."
	/bin/echo "*****  Install QGIS process:  FAILED  *****"
	exit 1
fi

# Check if QGIS is currently installed...
if [[ -e /Applications/QGIS.app ]]; then
	echo "QGIS is currently installed; removing this instance before continuing..."
	rm -rf /Applications/QGIS.app
	echo "QGIS has been removed."
fi

# Mounting the .dmg found...
	echo "Mounting ${QGISdmg}..."
	/usr/bin/hdiutil attach "${pkgDir}/${QGISdmg}" -nobrowse -noverify -noautoopen
	/bin/sleep 2

# Get the name of the mount.
	QGISMount=$(/bin/ls /Volumes/ | /usr/bin/grep QGIS)

# Get all of the pkgs.
	echo "Gathering packages that need to be installed for QGIS..."
	packages=$(/bin/ls "/Volumes/${QGISMount}/" | /usr/bin/grep .pkg)

# Loop through each .pkg in the directory...
while IFS=.pkg read pkg; do
	echo "Installing ${pkg}..."
	/usr/sbin/installer -dumplog -verbose -pkg "/Volumes/${QGISMount}/${pkg}" -allowUntrusted -target /
	exitCode=$?

	# Function exitCheck
	exitCheck $exitCode "${pkg}"
done < <(echo "${packages}")

echo "All packages have been installed!"

# Ejecting the .dmg...
	/usr/bin/hdiutil eject /Volumes/"${QGISMount}"

# Disable version check (this is done because the version compared is not always the latest available for macOS).
echo "Disabling version check on launch..."
/usr/bin/defaults write org.qgis.QGIS2.plist qgis.checkVersion -boolean false

echo "${QGISMount} has been installed!"
echo "*****  Install QGIS Process:  COMPLETE  *****"

exit 0