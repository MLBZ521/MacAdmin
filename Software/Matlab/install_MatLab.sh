#!/bin/sh

###################################################################################################
# Script Name:  install_MatLab.sh
# By:  Zack Thompson / Created:  3/6/2017
# Version:  1.2.1 / Updated:  12/6/2017 / By:  ZT
#
# Description:  This script is used to install and activate MatLab with a Network License Server.
#
###################################################################################################

/bin/echo "**************************************************"
/bin/echo "*****        Install process:  START         *****"
/bin/echo "**************************************************"

# Set working directory
	pkgDir=$(/usr/bin/dirname $0)

# Install MatLab via built-in script and option file.
	/bin/echo "Installing MatLab..."
	./Matlab_2017b_Mac/InstallForMacOSX.app/Contents/MacOS/InstallForMacOSX -inputFile ./installer_input.txt
	exitStatus=$?

if [[ $exitStatus == 0 ]]; then
	/bin/echo "Install completed successfully!"
	/bin/echo "Copying over the license..."
		/bin/cp ${pkgDir}/network.lic /Applications/MATLAB_R2017b.app/licenses/
	/bin/echo "License copied."
else
	/bin/echo "Install failed!"
	/bin/echo "**************************************************"
	/bin/echo "*****        Install process:  FAILED        *****"
	/bin/echo "**************************************************"

	exit 1
fi

/bin/echo "**************************************************"
/bin/echo "*****       Install process:  COMPLETE       *****"
/bin/echo "**************************************************"

exit 0
