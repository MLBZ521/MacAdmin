#!/bin/bash

###################################################################################################
# Script Name:  Set-DefaultApplications.sh
# By:  Zack Thompson / Created:  8/17/2017
# Version:  1.1.0 / Updated:  3/17/2022 / By:  ZT
#
# Description:  This script will aid in setting the default applications on a Mac.
#
# Inspired by:
#	@thoule & @scheb - https://www.jamf.com/jamf-nation/discussions/15472/set-outlook-2016-as-default-without-having-to-open-mail-app)
#	@miketaylr - https://gist.github.com/miketaylr/5969656
#
###################################################################################################

echo -e "\nConfiguring Default Applications on this machine...\n"
echo "***** Staging Configurations *****"

##################################################
# Define JSS Variables
jssURLScheme1=${4}
jssURLApp1=${5}
jssExt1=${6}
jssExtApp1=${7}
jssExt2=${8}
jssExtApp2=${9}
jssBrowser=${10}
jssMailApp=${11}

# Predefined URLs and Extensions
mailURLs=(mailto mail ical webcal)
mailExts=(com.apple.ical.ics)
webURLs=(https http)
webExts=(public.html)

# Get the current user
currentUser=$( /usr/sbin/scutil <<< "show State:/Users/ConsoleUser" | /usr/bin/awk '/Name :/ && ! /loginwindow/ { print $3 }' )

# Set custom Python binary path
python_binary="/opt/ManagedFrameworks/Python.framework/Versions/Current/bin/python3"

# Declare an array to add each Python scriptlet
pythonScripts=()

##################################################
# Staging predefined Mail and Calendar identifiers
# First make sure the variable is not empty.
if [[ -n "$jssMailApp" ]]; then
	echo "Staging Mail URL Schemes and Calendar extensions..."
	if [[ "${jssMailApp}" == "Outlook" ]]; then
		echo "Outlook for Mac was selected."
		mailApp="com.microsoft.Outlook"
		calApp="com.microsoft.Outlook"
	elif [[ "${jssMailApp}" == "Parallels Outlook" ]]; then
		echo "A Parallels instance of Outlook was selected."
		# This will build the Parallels instance to get the identifier.
			# Set the base location
			parallelsDir="/Users/${currentUser}/Applications \(Parallels\)"
			# Get the Parallels Instance Identifier 
			parallelsInstance=$(/bin/ls "${parallelsDir}" | /usr/bin/grep "Applications")
			# Get the Application Bundle ID
			parallelsOutlook="${parallelsDir}/${parallelsInstance}/Microsoft Outlook.app/Contents/Info.plist CFBundleIdentifier"

		mailApp="${parallelsOutlook}"
		calApp="${parallelsOutlook}"

	elif [[ "${jssMailApp}" == "Apple Mail" ]]; then
		echo "Apple Mail was selected."
		mailApp="com.apple.mail"
		calApp="com.apple.ical"
	else
		echo "A custom mail application was selected."
		mailApp="${jssMailApp}"
		calApp="${jssMailApp}"
	fi

	# Staging Mail and Calendar Applications Scriptlets
	# Set default application for a "URL://" scheme
	for mailURL in "${mailURLs[@]}"; do
		py_mailURL="print(\"Configuring Mail URL Schemes\")
from LaunchServices import LSSetDefaultHandlerForURLScheme
LSSetDefaultHandlerForURLScheme(\"${mailURL}\", \"${mailApp}\")"
		pythonScripts+=("${py_mailURL}")
	done

	# Set default application for ".extension"
	for mailExt in "${mailExts[@]}"; do
		py_mailExt="print(\"Configuring Mail and Calendar extensions\")
from LaunchServices import LSSetDefaultRoleHandlerForContentType
LSSetDefaultRoleHandlerForContentType(\"${mailExt}\", 0xFFFFFFFF, \"${calApp}\")"
		pythonScripts+=("${py_mailExt}")
	done
fi

##################################################
# Staging predefine Web Browser identifiers
# First make sure the variable is not empty.
if [[ -n "${jssBrowser}" ]]; then
	echo "Staging Web Browser URL Schemes and Calendar extensions..."
	if [[ "${jssBrowser}" == "Chrome" ]]; then
		echo "Chrome was selected."
		browser="com.google.Chrome"
	elif [[ "${jssBrowser}" == "Firefox" ]]; then
		echo "Firefox was selected."
		browser="org.mozilla.firefox"
	elif [[ "${jssBrowser}" == "Safari" ]]; then
		echo "Safari was selected."
		browser="com.apple.Safari"
	else
		echo "A custom browser was selected."
		browser="${jssBrowser}"
	fi

	# Staging Web Browser Scriptlets
	# Set default application for a "URL://" scheme
	for webURL in "${webURLs[@]}"; do
		py_webURL="print(\"Configuring Web Browser URL Schemes\")
from LaunchServices import LSSetDefaultHandlerForURLScheme
LSSetDefaultHandlerForURLScheme(\"${webURL}\", \"${browser}\")"
		pythonScripts+=("${py_webURL}")
	done

	# Set default application for ".extension"
	for webExt in "${webExts[@]}"; do
		py_webExt="print(\"Configuring Web Browser extensions\")
from LaunchServices import LSSetDefaultRoleHandlerForContentType
LSSetDefaultRoleHandlerForContentType(\"${webExt}\", 0xFFFFFFFF, \"${browser}\")"
		pythonScripts+=("${py_webExt}")
	done
fi

##################################################
# Staging Custom Application Scriptlets

if [[ -n "${jssURLScheme1}" || -n "${jssURLApp1}" ]]; then
	# Set default application for a "URL://" scheme
	echo "Staging custom URL Scheme 1..."
	py_customURL="print(\"Configuring custom URL Scheme 1\")
from LaunchServices import LSSetDefaultHandlerForURLScheme
LSSetDefaultHandlerForURLScheme(\"${jssURLScheme1}\", \"${jssURLApp1}\")"
	pythonScripts+=("${py_customURL}")
fi

if [[ -n "${jssExt1}" || -n "${jssExtApp1}" ]]; then
	# Set default application for ".extension"
	echo "Staging custom extensions 1..."
	py_customExt1="print(\"Configuring custom extensions 1\")
from LaunchServices import LSSetDefaultRoleHandlerForContentType
LSSetDefaultRoleHandlerForContentType(\"${jssExt1}\", 0xFFFFFFFF, \"${jssExtApp1}\")"
	pythonScripts+=("${py_customExt1}")
fi


if [[ -n "${jssExt2}" || -n "${jssExtApp2}" ]]; then
	# Set default application for ".extension"
	echo "Staging custom extensions 2..."
	py_customExt2="print(\"Configuring custom extensions 2\")
from LaunchServices import LSSetDefaultRoleHandlerForContentType
LSSetDefaultRoleHandlerForContentType(\"${jssExt2}\", 0xFFFFFFFF, \"${jssExtApp2}\")"
	pythonScripts+=("${py_customExt2}")
fi

##################################################
# Now do the work...

echo "***** Applying configurations... *****"

for pythonScript in "${pythonScripts[@]}"; do
	/usr/bin/sudo -u "${currentUser}" -H "${python_binary}" -c "${pythonScript}"
done

echo "Script Complete!"
exit 0