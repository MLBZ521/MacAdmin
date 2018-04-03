#!/bin/bash

###################################################################################################
# Script Name:  update_AutoCAD.sh
# By:  Zack Thompson / Created:  4/2/2018
# Version:  1.0 / Updated:  4/2/2018 / By:  ZT
#
# Description:  This script will update an AutoCAD install.
#
###################################################################################################

echo "*****  Update AutoCAD process:  START  *****"

##################################################
# Define Variables

# Set working directory
	pkgDir=$(/usr/bin/dirname "${0}")
# Get Configuration details...
	targetAppName=$(/usr/bin/defaults read "${pkgDir}/VerTarget.plist" TargetAppName)
	newVersion=$(/usr/bin/defaults read "${pkgDir}/VerTarget.plist" UpdateVersion)
	versionsToPatch=$(/bin/cat "${pkgDir}/VerTarget.plist" | /usr/bin/xmllint --format - | /usr/bin/xpath '/plist/dict/array/string' 2>/dev/null | LANG=C /usr/bin/sed -e 's/<[^/>]*>//g' | LANG=C /usr/bin/sed -e 's/<[^>]*>/\'$'\n/g')
	compatible=1
# Find the AutoCAD version being updated...
	echo "Searching for ${targetAppName}..."
	appPath=$(/usr/bin/find -E /Applications -iregex ".*[/]${targetAppName}[.]app" -type d -prune)

if [[ -z "${appPath}" ]]; then
	echo "A version of AutoCAD was not found in the expected location!"
	echo "*****  Update AutoCAD process:  FAILED  *****"
	exit 1
else
	# Get the App Bundle name...
		appName=$(echo "${appPath}" | /usr/bin/awk -F "/" '{print $NF}')
	# Get only the install path...
		installPath=$(echo "${appPath}" | /usr/bin/awk -F "/${appName}" '{print $1}')
	# Get the Current Version CFBundleVersion...
		oldBundleVersion=$(/usr/bin/defaults read "${appPath}/Contents/Info.plist" CFBundleVersion)
fi

##################################################
# Bits staged...

# Check if patch version is the current version.
if [[ "${newVersion}" == "${oldBundleVersion}" ]]; then
	echo "AutoCAD is already up to date!"
	echo "*****  Update AutoCAD process:  FAILED  *****"
	exit 2
fi

echo "App Path:  ${appPath}"
echo "Current Version:  ${oldBundleVersion}"
echo "Patch Version:  ${newVersion}"

# Verify that this patch is compatible with this version.
while IFS=\n read -r versionPatch; do
	if [[ "${versionPatch}" == "${oldBundleVersion}" ]]; then
		echo "${newVersion} is a valid patch for:  ${oldBundleVersion}"
		compatible=0
	fi
done < <(/usr/bin/printf '%s\n' "${versionsToPatch}")

# If compatible, install, if not error out.
if [[ $compatible -eq true ]]; then
	echo "Installing patch..."
	exitStatus=$("${pkgDir}/BinaryDelta" apply "${installPath}" "${pkgDir}/product.delta")
	exitCode=$?
else
	echo "ERROR:  This patch is not compatible with the installed version!"
	echo "*****  Update AutoCAD process:  FAILED  *****"
	exit 3
fi

# Check the exit code.
if [[ $exitCode != 0 ]]; then
	echo "ERROR:  Update failed!"
	echo "Exit Code:  ${exitCode}"
	echo "Exit status was:  ${exitStatus}"
	echo "*****  Update AutoCAD process:  FAILED  *****"
	exit 4
else
	# Get the new CFBundleVersion...
	newBundleVersion=$(/usr/bin/defaults read "${appPath}/Contents/Info.plist" CFBundleVersion)

	# Confirm that the CFBundleVersion is the expected value.
	if [[ "${newVersion}" == "${newBundleVersion}" ]]; then
		echo "Update complete!"
	else
		echo "ERROR:  Update failed!"
		echo "AutoCAD was not properly updated!"
		echo "*****  Update AutoCAD process:  FAILED  *****"
		exit 5
	fi
fi

echo "*****  Update AutoCAD process:  COMPLETE  *****"
exit 0