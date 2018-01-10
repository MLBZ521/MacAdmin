#!/bin/bash

###################################################################################################
# Script Name:  build_SPSS.sh
# By:  Zack Thompson / Created:  1/5/2018
# Version:  1.1 / Updated:  1/8/2018 / By:  ZT
#
# Description:  This script uses munkpkg to build an SPSS package.
#
###################################################################################################

/bin/echo "*****  Build SPSS process:  START  *****"

##################################################
# Define Variables

softwareTitle="SPSSStatistics"

# Switches
	switch1="${1}"  # Build Type
	switch2="${2}"  # Version
	switch3="${3}"  # Version Value

# Set working directory
	scriptDirectory=$(/usr/bin/dirname "$(/usr/bin/stat -f "$0")")

# Get the Major Version
	majorVersion=$(/bin/echo "${switch3}" | /usr/bin/awk -F "." '{print $1}')

##################################################
# Setup Functions

function getHelp {
/bin/echo "
usage:  build_SPSS.sh [-install] [-update] [-version] <value> -help

Info:	Uses munkipkg to build a package for use in Jamf.

Actions:
	-install	Builds a package to install a new version
			Example:  build_SPSS.sh -install -version 25.0.0.0

	-update		Builds a package to install a patch
			Example:  build_SPSS.sh  -update -version 24.0.0.2

	-help	Displays this help text.
			Example:  build_SPSS.sh -help
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
	/bin/rm -Rf "${scriptDirectory}"/scripts/*
}

##################################################
# Find out what we want to do...

/bin/echo "Build Type:  $switch1"
/bin/echo "Version:  $switch3"

case $switch1 in
	-install )
		/bin/cp "${scriptDirectory}"/uninstall_SPSS.sh "${scriptDirectory}"/scripts/preinstall
		/bin/cp "${scriptDirectory}"/install_SPSS.sh "${scriptDirectory}"/scripts/postinstall
		/bin/cp "${scriptDirectory}"/build/$switch3/* "${scriptDirectory}"/scripts/

		# Set the desired install directory
		/usr/bin/sed -i '' 's,USER_INSTALL_DIR=,'"USER_INSTALL_DIR=/Applications/SPSS Statistics ${majorVersion}/"',' "${scriptDirectory}"/scripts/installer.properties

		# Function munkiBuild
		munkiBuild
	;;
	-update )
		/bin/cp "${scriptDirectory}"/update_SPSS.sh "${scriptDirectory}"/scripts/postinstall
		/bin/cp "${scriptDirectory}"/build/$switch3/* "${scriptDirectory}"/scripts/

		# Set the version in the update_SPSS.sh script
		/usr/bin/sed -i '' 's/version=/'"version=${majorVersion}"'/' "${scriptDirectory}"/scripts/postinstall

		# Function munkiBuild
		munkiBuild
	;;
	-help | * )
		# Function getHelp
		getHelp
	;;
esac

/bin/echo "*****  Build SPSS process:  COMPLETE  *****"
exit 0