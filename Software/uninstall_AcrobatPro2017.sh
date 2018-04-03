#!/bin/bash

###################################################################################################
# Script Name:  uninstall_AcrobatPro2017.sh
# By:  Zack Thompson / Created:  6/30/2017
# Version:  1.0.1 / Updated:  3/30/2017 / By:  ZT
#
# Description:  This script uninstalls Acrobat Pro v2017.
#
###################################################################################################

# Call the built-in uninstall mechanism if the application is currently installed.
echo "Checking if Acrobat Pro v2017 is currently installed..."

if [[ -e "/Applications/Adobe Acrobat 2017/Adobe Acrobat.app" ]]; then
	echo "Uninstalling Acrobat Pro v2017..."
		"/Applications/Adobe Acrobat 2017/Adobe Acrobat.app/Contents/Helpers/Acrobat Uninstaller.app/Contents/MacOS/RemoverTool" "/Applications/Adobe Acrobat 2017/Adobe Acrobat.app/Contents/Helpers/Acrobat Uninstaller.app/Contents/MacOS/RemoverTool" "/Applications/Adobe Acrobat 2017/Adobe Acrobat.app"
	echo "Uninstall Complete!"
else
	echo "Acrobat Pro v2017 is not installed."
fi

exit 0
