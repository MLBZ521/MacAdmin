#! /bin/sh

###################################################################################################
# Script Name:  uninstall_SPSS.sh
# By:  Zack Thompson / Created:  11/1/2017
# Version:  1.1 / Updated:  1/18/2018 / By:  ZT
#
# Description:  Remove previous version(s) of SPSS from /Applications
#
###################################################################################################

/bin/echo "*****  Uninstall SPSS process:  START  *****"

# If the machine has multiple SPSS Applications, loop through them...
/usr/bin/find -E /Applications -iregex ".*[/](SPSS) ?(Statistics) ?(\d\d)?[.]app" -type d -prune | while IFS="\n" read -r appPath; do

	# Get the App Bundle name
		appName=$(/bin/echo $appPath | /usr/bin/awk -F "/" '{print $NF}')
	# Get only the install path
		installPath=$(/bin/echo $appPath | /usr/bin/awk -F "/$appName" '{print $1}')
	# Delete the old version
		/bin/echo "Uninstalling:  ${appPath}"
		/bin/rm -rf "${installPath}"

done

/bin/echo "*****  Uninstall SPSS process:  COMPLETE  *****"

exit 0
