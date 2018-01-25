#!/bin/bash

###################################################################################################
# Script Name:  build_Mathematica.sh
# By:  Zack Thompson / Created:  1/10/2018
# Version:  1.1 / Updated:  1/24/2018 / By:  ZT
#
# Description:  This script uses munkipkg to build an Mathematica package.
#
###################################################################################################

/bin/echo "*****  Build Mathematica process:  START  *****"

##################################################
# Define Variables

softwareTitle="Mathematica"

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
usage:  build_Mathematica.sh [-install] [-version] <value> -help

Info:	Uses munkipkg to build a package for use in Jamf.

Actions:
	-install	Builds a package to install a new version
			Example:  build_Mathematica.sh -install -version 2017.0

	-help	Displays this help text.
			Example:  build_Mathematica.sh -help
"
}

function munkiBuild {
	/usr/libexec/PlistBuddy -c "set identifier edu.asu.pkg.${softwareTitle}" "${scriptDirectory}"/build-info.plist
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

/bin/echo "Build Type:  $switch1"
/bin/echo "Version:  $switch3"

case $switch1 in
	-install )
		/bin/cp "${scriptDirectory}"/install_Mathematica.sh "${scriptDirectory}"/scripts/postinstall
		/bin/mv "${scriptDirectory}"/build/$switch3/* "${scriptDirectory}"/scripts/

		# Function munkiBuild
		munkiBuild
	;;
	-help | * )
		# Function getHelp
		getHelp
	;;
esac

/bin/echo "*****  Build Mathematica process:  COMPLETE  *****"
exit 0