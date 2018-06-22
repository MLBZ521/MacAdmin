#!/bin/bash

###################################################################################################
# Script Name:  install_QGIS.sh
# By:  Zack Thompson / Created:  7/26/2017
# Version:  1.5.1 / Updated:  6/22/2018 / By:  ZT
#
# Description:  This script installs all the packages that are contained in the QGIS dmg.
#
###################################################################################################

echo "*****  Install QGIS Process:  START  *****"

##################################################
# Define Variables

# Set working directory
	pkgDir=$(/usr/bin/dirname "${0}")
# Get the current user
#	currentUser=$(/usr/bin/python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");')
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
	echo "ERROR:  Target disk is not the startup disk."
	echo "*****  Install QGIS process:  FAILED  *****"
	exit 1
fi

if [[ "${QGISdmg}" == "QGIS-3"* ]]; then
	# Check if Python3 is installed
	if [[ -x /usr/local/bin/python3 ]]; then
		getVersion=$(/usr/local/bin/python3 --version | /usr/bin/awk -F "." '{print $2}')
		if [[ $(/usr/bin/bc <<< "${getVersion} >= 6") -eq 1 ]]; then
			echo "Python 3.6+ is installed!"
		else
			echo "ERROR:  Python 3.6+ is not installed!"
			echo "*****  Install QGIS Process:  FAILED  *****"
			exit 1
		fi
	else
		echo "ERROR:  Python 3.6+ is not installed!"
		echo "*****  Install QGIS Process:  FAILED  *****"
		exit 1
	fi
fi

# Check if QGIS is currently installed...
appPaths=$(/usr/bin/find -E /Applications -iregex ".*[/]QGIS ?([0-9]{1})?[.]app" -type d -maxdepth 1 -prune)

if [[ ! -z "${appPaths}" ]]; then
	echo "QGIS is currently installed; removing this instance before continuing..."

	# If the machine has multiple QGIS Applications, loop through them...
	while IFS="\n" read -r appPath; do
		echo "Deleting:  ${appPath}"
		/bin/rm -rf "${appPath}"
	done < <(echo "${appPaths}")

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
if [[ "${QGISdmg}" == "QGIS-3"* ]]; then
	echo "Disabling version check on launch is currently removed from this process for QGIS v3."
	# Disabled this because the .ini file does not exist until the application is launched.
	# echo "Disabling version check on launch..."
	# /usr/bin/sed -Ei '' 's/checkVersion=true/checkVersion=false/g' "/${currentUser}/Library/Application Support/QGIS/QGIS3/profiles/default/qgis.org/QGIS3.ini"
elif [[ "${QGISdmg}" == "QGIS-2"* ]]; then
	echo "Disabling version check on launch..."
	/usr/bin/defaults write org.qgis.QGIS2.plist qgis.checkVersion -boolean false
fi

echo "${QGISMount} has been installed!"
echo "*****  Install QGIS Process:  COMPLETE  *****"

exit 0