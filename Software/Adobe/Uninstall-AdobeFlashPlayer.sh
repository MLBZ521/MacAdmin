#!/bin/bash

###################################################################################################
# Script Name:  Uninstall-AdobeFlashPlayer.sh
# By:  Zack Thompson / Created:  12/23/2020
# Version:  1.1.0 / Updated:  1/13/2020 / By:  ZT
#
# Description:  This script uninstalls Adobe Flash Player.
#
# Credit to:
#       https://soundmacguy.wordpress.com/2020/01/24/uninstalling-adobe-flash-player-in-a-flash/
#       https://github.com/marckerr/RemoveFlash
#       https://github.com/rtrouton/rtrouton_scripts/tree/master/rtrouton_scripts/uninstallers/adobe_flash_uninstall
#
###################################################################################################

echo -e "*****  Uninstall Adobe Flash Player process:  START  *****\n"

# Attempt to use the built-in uninstall mechanism in the Flash Player Install Manager tool.
FlashManager="/Applications/Utilities/Adobe Flash Player Install Manager.app/Contents/MacOS/Adobe Flash Player Install Manager"

if [[ -e "${FlashManager}" ]]; then

    echo "Running the built-in uninstaller..."
    results=$( "${FlashManager}" -uninstall )
    exitCode=$?

    if [[ $exitCode != 0 ]]; then

        echo "Did not successfully exit."

    fi

    if [[ "${results}" != "" ]]; then

        echo -e "Results: \n ${results}"

    fi

fi

# Kill the Adobe Flash Player Install Manager
echo "Stopping Adobe Flash Install Manager."
/usr/bin/killall "Adobe Flash Player Install Manager"

# Stop the Adobe Flash Player LaunchDaemon
if [[ -f "/Library/LaunchDaemons/com.adobe.fpsaud.plist" ]]; then
   echo "Stopping Adobe Flash update process"
  /bin/launchctl bootout system "/Library/LaunchDaemons/com.adobe.fpsaud.plist"
fi

# Additional files and directories to clean up if they were not removed.
declare -a additional_Items_To_Remove=("/Library/Application Support/Macromedia" \
    "/Library/Application Support/Adobe/Flash Player Install Manager" \
    "/Library/Internet Plug-Ins/Flash Player.plugin" \
    "/Library/Internet Plug-Ins/flashplayer.xpt" \
    "/Library/Internet Plug-Ins/PepperFlashPlayer" \
    "/Library/LaunchDaemons/com.adobe.fpsaud.plist" \
    "/Library/PreferencePanes/Flash Player.prefPane" \
    "/Applications/Utilities/Adobe Flash Player Install Manager.app" \
    "/Library/Application Support/Macromedia/mms.cfg" \
    "/Library/Application Support/Adobe/Flash Player Install Manager/FPSAUConfig.xml" \
    "/Library/Application Support/Adobe/Flash Player Install Manager/fpsaud" \
    "/Library/Internet Plug-Ins/Flash Player Enabler.plugin" \
    "/Library/Internet Plug-Ins/PepperFlashPlayer/PepperFlashPlayer.plugin" \
    "/Library/Internet Plug-Ins/PepperFlashPlayer/manifest.json" )

# Loop through the additional items to remove, checking if they exist, and remove them if so.
for item in "${additional_Items_To_Remove[@]}" ; do

	if [[ -e "${item}" ]]; then

		echo "Deleting:  ${item}"
		/bin/rm -Rf "${item}"

	fi

done

# Remove and forget pkg receipts
/bin/rm -Rf /Library/Receipts/*FlashPlayer*
/usr/sbin/pkgutil --forget "com.adobe.pkg.FlashPlayer" > /dev/null 2>&1
/usr/sbin/pkgutil --forget "com.adobe.pkg.PepperFlashPlayer" > /dev/null 2>&1

# Remove additional content from user directories.
allLocalUsers=$( /usr/bin/dscl . -list /Users UniqueID | /usr/bin/awk '$2>500 {print $1}' )

for userName in "${allLocalUsers[@]}"; do

    # Setup variables
    userHome=$( /usr/bin/dscl . -read "/Users/${userName}" NFSHomeDirectory 2> /dev/null | /usr/bin/sed 's/^[^\/]*//g' )
    userMacromediaDir="${userHome}/Library/Preferences/Macromedia"
    userAdobeFlashPlayerDir="${userHome}/Library/Caches/Adobe/Flash Player"

    # Removing Adobe Flash preference pane settings at user level 
    /usr/bin/defaults delete "${userHome}/Library/Preferences/com.apple.systempreferences.plist" "com.adobe.preferences.flashplayer" 2> /dev/null

    if [[ -e "${userMacromediaDir}" ]]; then

    	echo "Deleting:  ${userMacromediaDir}"
        /bin/rm -Rf "${userMacromediaDir}"

    fi

    if [[ -e "${userAdobeFlashPlayerDir}" ]]; then

    	echo "Deleting:  ${userAdobeFlashPlayerDir}"
        /bin/rm -Rf "${userAdobeFlashPlayerDir}"

    fi

done

echo -e "\n*****  Uninstall Adobe Flash Player process:  COMPLETE  *****"

exit 0
