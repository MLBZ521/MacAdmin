#!/bin/bash

###################################################################################################
# Script Name:  build_AutoCAD.sh
# By:  Zack Thompson / Created:  4/2/2018
# Version:  1.0 / Updated:  4/2/2018 / By:  ZT
#
# Description:  This script uses munkipkg to build an AutoCAD package.
#
###################################################################################################

echo "*****  Build AutoCAD process:  START  *****"

##################################################
# Define Variables

softwareTitle="AutoCAD"

# Switches
	switch1="${1}"  # Build Type
	switch2="${2}"  # Version
	switch3="${3}"  # Version Value

# Set working directory
	scriptDirectory=$(/usr/bin/dirname "$(/usr/bin/stat -f "$0")")

##################################################
# Setup Functions

function getHelp {
echo "
usage:  build_AutoCAD.sh [-update] [-version] <value> -help

Info:	Uses munkipkg to build a package for use in Jamf.

Actions:
	-update	Builds a package to update a new version
			Example:  build_AutoCAD.sh -update -version 2017.0

	-help	Displays this help text.
			Example:  build_AutoCAD.sh -help
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
	/bin/mv "${scriptDirectory}"/scripts/* "${scriptDirectory}"/build/$switch3/
}

##################################################
# Find out what we want to do...

echo "Build Type:  $switch1"
echo "Version:  $switch3"

case $switch1 in
	-update )
		/bin/cp "${scriptDirectory}"/update_AutoCAD.sh "${scriptDirectory}"/scripts/postinstall
		/bin/mv "${scriptDirectory}"/build/$switch3/* "${scriptDirectory}"/scripts/

		# Function munkiBuild
		munkiBuild
	;;
	-help | * )
		# Function getHelp
		getHelp
	;;
esac

echo "*****  Build AutoCAD process:  COMPLETE  *****"
exit 0