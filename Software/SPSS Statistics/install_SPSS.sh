#! /bin/bash

###################################################################################################
# Script Name:  install_SPSS.sh
# By:  Zack Thompson / Created:  11/1/2017
# Version:  1.3 / Updated:  1/25/2018 / By:  ZT
#
# Description:  This script silently installs SPSS.
#
###################################################################################################

/bin/echo "*****  Install SPSS process:  START  *****"

##################################################
# Define Variables

# Set working directory
	pkgDir=$(/usr/bin/dirname $0)
# Java JDK Directory
	jdkDir="/Library/Java/JavaVirtualMachines"
# Version that's being updated (this will be set by the build_SPSS.sh script)
	version=
	majorVersion=$(/bin/echo $version | /usr/bin/awk -F "." '{print $1}')

##################################################
# Bits staged...

if [[ -d $(/usr/bin/find "/Library/Java/JavaVirtualMachines" -iname "*.jdk" -type d) ]]; then
	# Install prerequisite:  Java JDK
	/bin/echo "Installing prerequisite Java JDK from Jamf..."
	/usr/local/bin/jamf policy -id 721 -forceNoRecon
fi

# Make sure the Installer.bin file is executable
	/bin/chmod +x "${pkgDir}/SPSS_Statistics_Installer.bin"

# Silent install using information in the installer.properties file
/bin/echo "Installing SPSS..."
	exitStatus=$("${pkgDir}/SPSS_Statistics_Installer.bin" -f "${pkgDir}/installer.properties")
	exitCode=$?

if [[ ! -d "/Applications/SPSS Statistics ${majorVersion}/SPSSStatistics.app" ]]; then
	/bin/echo "ERROR:  Install failed!"
	/bin/echo "Exit Code:  ${exitCode}"
	/bin/echo "ERROR Content:  ${exitStatus}"
	/bin/echo "*****  Install SPSS process:  FAILED  *****"
	exit 1
fi

/bin/echo "Install complete!"
/bin/echo "*****  Install SPSS process:  COMPLETE  *****"

exit 0