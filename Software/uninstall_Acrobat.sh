#!/bin/bash

###################################################################################################
# Script Name:  uninstall_Acrobat.sh
# By:  Zack Thompson / Created:  6/30/2017
# Version:  1.1 / Updated:  9/7/2018 / By:  ZT
#
# Description:  This script uninstalls Acrobat DC versions.
#
###################################################################################################

echo "*****  Uninstall Adobe Acrobat process:  START  *****"

##################################################
# Define Variables
exit="0"
args="$@"
echo "Provided arguments:  ${args}"

# Turn on case-insensitive pattern matching
shopt -s nocasematch

# Determine what was requested to uninstall
for arg in $args; do
	case $arg in
		"2015" | "v12" )
			toRemove+=("12")
		;;
		"2017" | "v17" )
			toRemove+=("17")
		;;
		"2018" | "v18" )
			toRemove+=("18")
		;;
		"All" )
			toRemove+=("12")
			toRemove+=("17")
			toRemove+=("18")
		;;
	esac
done

# Turn off case-insensitive pattern matching
shopt -u nocasematch

echo "${#toRemove[@]} versions to remove:  ${toRemove[@]}"

##################################################
# Bits staged...

echo "Searching for existing Adobe Acrobat instances..."
appPaths=$(/usr/bin/find -E /Applications -iregex ".*[/]Adobe Acrobat[.]app" -type d -prune)

# Verify that a Adobe Acrobat version was found.
if [[ -z "${appPaths}" ]]; then
	echo "Did not find an instance of Adobe Acrobat!"
else
	# If the machine has multiple Adobe Acrobat Applications, loop through them...
	while IFS="\n" read -r appPath; do
		# Get the Acrobat version string
		appVersion=$(/usr/bin/defaults read "${appPath}/Contents/Info.plist" CFBundleShortVersionString | /usr/bin/awk -F '.' '{print $1}')

		if [[ "${toRemove[@]}" =~ "${appVersion}" ]]; then
			echo "Uninstalling:  Adobe Acrobat v${appVersion}"

			case $appVersion in
				"12" )
					exitOutput=$("${appPath}/Contents/Helpers/Acrobat Uninstaller.app/Contents/MacOS/RemoverTool" "${appPath}/Contents/Helpers/Acrobat Uninstaller.app/Contents/MacOS/RemoverTool" "${appPath}")
				;;
				"17" | "18" )
					exitOutput=$("${appPath}/Contents/Helpers/Acrobat Uninstaller.app/Contents/Library/LaunchServices/com.adobe.Acrobat.RemoverTool" "${appPath}")
				;;
			esac

			if [[ $exitOutput != *"because you don’t have permission to access"* ]]; then
				echo " -> Success"
			else
				echo " -> Failed"
				exit="1"
			fi
		fi
	done < <(echo "${appPaths}")
fi

echo "*****  Uninstall Adobe Acrobat process:  COMPLETE  *****"
exit $exit