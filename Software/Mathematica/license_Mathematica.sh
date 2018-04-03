#!/bin/bash

###################################################################################################
# Script Name:  license_Mathematica.sh
# By:  Zack Thompson / Created:  1/10/2018
# Version:  1.1.1 / Updated:  4/2/2018 / By:  ZT
#
# Description:  This script applies the license for Mathematica applications.
#
###################################################################################################

echo "*****  License Mathematica process:  START  *****"

##################################################
# Define Variables

licenseDirectory="/Library/Mathematica/Licensing"
licenseFile="${licenseDirectory}/mathpass"

##################################################
# Create the license file.

if [[ ! -d "${licenseDirectory}" ]]; then
	echo "Creating License Directory..."
	/bin/mkdir -p "${licenseDirectory}"
fi

echo "Creating license file..."

/bin/cat > "${licenseFile}" <<licenseContents
!license.server.com

licenseContents

if [[ -e "${licenseFile}" ]]; then
	# Set permissions on the file for everyone to be able to read.
	echo "Applying permissions to license file..."
	/bin/chmod 644 "${licenseFile}"
else
	echo "ERROR:  Failed to create the license file!"
	echo "*****  License Mathematica process:  FAILED  *****"
	exit 1
fi

echo "Mathematica has been activated!"
echo "*****  License Mathematica process:  COMPLETE  *****"

exit 0