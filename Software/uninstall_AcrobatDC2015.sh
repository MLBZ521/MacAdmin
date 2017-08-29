#!/bin/bash

###################################################################################################
# Script Name:  uninstall_AcrobatDC2015.sh
# By:  Zack Thompson / Created:  6/30/2017
# Version:  1.0 / Updated:  6/30/2017 / By:  ZT
#
# Description:  This script uninstalls Acrobat DC v2015.
#
###################################################################################################

# Call the built-in uninstall mechanism if the application is currently installed.
/bin/echo "Checking if Acrobat DC v2015 is currently installed..."

if [[ -e "/Applications/Adobe Acrobat DC/Adobe Acrobat.app" ]]; then
	/bin/echo "Uninstalling Acrobat DC v2015..."
		"/Applications/Adobe Acrobat DC/Adobe Acrobat.app/Contents/Helpers/Acrobat Uninstaller.app/Contents/MacOS/RemoverTool" "/Applications/Adobe Acrobat DC/Adobe Acrobat.app/Contents/Helpers/Acrobat Uninstaller.app/Contents/MacOS/RemoverTool" "/Applications/Adobe Acrobat DC/Adobe Acrobat.app"
	/bin/echo "Uninstall Complete!"
else
	/bin/echo "Acrobat DC v2015 is not installed."
fi

exit 0