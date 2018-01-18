#! /bin/sh

###################################################################################################
# Script Name:  install_SPSS.sh
# By:  Zack Thompson / Created:  11/1/2017
# Version:  1.2 / Updated:  1/17/2018 / By:  ZT
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

##################################################
# Bits staged...

if [[ -n $(/usr/bin/find $jdkDir -iname *.jdk) ]]; then
	# Install prerequisite:  Java JDK
	/bin/echo "Installing prerequisite Java JDK from Jamf..."
	/usr/local/bin/jamf policy -id 721
fi

# Silent install using information in the installer.properties file
/bin/echo "Installing SPSS..."
	"${pkgDir}/SPSS_Statistics_Installer.bin" -f "${pkgDir}/installer.properties"
	exitStatus=$?
/bin/echo "Exit Status:  ${exitStatus}"

if [[ $exitStatus != 0 ]]; then
	/bin/echo "ERROR:  Install failed!"
	/bin/echo "*****  Install SPSS process:  FAILED  *****"
	exit 1
fi

/bin/echo "Install complete!"
/bin/echo "*****  Install SPSS process:  COMPLETE  *****"

exit 0