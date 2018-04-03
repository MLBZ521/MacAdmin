#!/bin/bash

###################################################################################################
# Script Name:  build_Maple.sh
# By:  Zack Thompson / Created:  1/8/2018
# Version:  1.1.2 / Updated:  3/30/2018 / By:  ZT
#
# Description:  This script uses munkipkg to build an Maple package.
#
###################################################################################################

echo "*****  Build Maple process:  START  *****"

##################################################
# Define Variables

softwareTitle="Maple"

# Switches
	switch1="${1}"  # Build Type
	switch2="${2}"  # Version
	switch3="${3}"  # Version Value

# Set working directory
	scriptDirectory=$(/usr/bin/dirname "$(/usr/bin/stat -f "$0")")

##################################################
# Setup Functions

function getHelp {
/bin/echo "
usage:  build_Maple.sh [-install] [-update] [-version] <value> -help

Info:	Uses munkipkg to build a package for use in Jamf.

Actions:
	-install	Builds a package to install a new version
			Example:  build_Maple.sh -install -version 2017.0

	-update		Builds a package to install a patch
			Example:  build_Maple.sh  -update -version 2016.2

	-help	Displays this help text.
			Example:  build_Maple.sh -help
"
}

function munkiBuild {
	/usr/libexec/PlistBuddy -c "set identifier com.github.mlbz521.pkg.${softwareTitle}" "${scriptDirectory}"/build-info.plist
	/usr/libexec/PlistBuddy -c "set name ${softwareTitle} Unlicensed-\${version}.pkg" "${scriptDirectory}"/build-info.plist
	/usr/libexec/PlistBuddy -c "set version $switch3" "${scriptDirectory}"/build-info.plist

	munkipkg "${scriptDirectory}" > /dev/null

	# Function cleanUp
	cleanUp
}

function cleanUp {
	/bin/rm "${scriptDirectory}"/scripts/postinstall
	/bin/mv "${scriptDirectory}"/scripts/JavaForOSX.pkg "${scriptDirectory}"/build/
	/bin/mv "${scriptDirectory}"/scripts/* "${scriptDirectory}"/build/$switch3/
}

##################################################
# Find out what we want to do...

echo "Build Type:  $switch1"
echo "Version:  $switch3"

case $switch1 in
	-install )
		/bin/cp "${scriptDirectory}"/install_Maple.sh "${scriptDirectory}"/scripts/postinstall
		/bin/mv "${scriptDirectory}"/build/$switch3/* "${scriptDirectory}"/scripts/
		/bin/mv "${scriptDirectory}"/build/JavaForOSX.pkg "${scriptDirectory}"/scripts/

		# Set the version in the install_Maple.sh script
		/usr/bin/sed -i '' 's/version=.*/'"version=${switch3}"'/' "${scriptDirectory}"/scripts/postinstall

		# Function munkiBuild
		munkiBuild
	;;
	-update )
		/bin/cp "${scriptDirectory}"/update_Maple.sh "${scriptDirectory}"/scripts/postinstall
		/bin/mv "${scriptDirectory}"/build/$switch3/* "${scriptDirectory}"/scripts/

		# Set the version in the update_Maple.sh script
		/usr/bin/sed -i '' 's/version=.*/'"version=${switch3}"'/' "${scriptDirectory}"/scripts/postinstall

		# Function munkiBuild
		munkiBuild
	;;
	-help | * )
		# Function getHelp
		getHelp
	;;
esac

echo "*****  Build Maple process:  COMPLETE  *****"
exit 0