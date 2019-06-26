#!/bin/bash

###################################################################################################
# Script Name:  uninstall_Spirion.sh
# By:  Zack Thompson / Created:  6/3/2019
# Version:  1.1.0 / Updated:  6/26/2019 / By:  ZT
#
# Description:  This script uninstalls Spirion and Identity Finder.
#
# Note:  This is a customzied version of the uninstall script provided by Spirion to be run from 
#					a management solution, such as Jamf Pro.
#
###################################################################################################

# On uninstall ask if user prefs should be preserved or not. If not, then blow away
# license/activation info/all plists/etc  if preserve, then just unload launch agent 
# and blow away everything except any identityfinder.lic, activation dat file, and user 
# prefs/plist.

# UninstallIDF.sh Version 20161017

shopt -s checkhash cmdhist nullglob;

runSilently=0
# answerYes=0
# answerNo=0
askForPassword=0

case "${4}" in
	Yes|yes|YES|Y|y)
		answerYes=1
		answerNo=0
	;;
	No|no|NO|N|n)
		answerYes=0
		answerNo=1
	;;
esac

currentUser=$(/usr/bin/python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");')

UsersSharedPathBase='/Users/Shared/.identityfinder';
UsersSharedPathApp="$UsersSharedPathBase/Application";
UsersSharedPath="$UsersSharedPathApp/{04964656e-7469-7479-2046-696e6465720}";
UsersPrefsPath="/Users/${currentUser}/Library/Preferences";
SystemPrefsPath='/Library/Preferences';
ReceiptsPath='/Library/Receipts';

IDFBaseName='Identity Finder'
IDFReverseDomainRoot='com.identityfinder';
IDFAppName="$IDFBaseName.app";
IDFPKGBuilderPrefsName="$IDFReverseDomainRoot.installerbuilder.plist";
IDFPKGBuilderName="$IDFBaseName Client Custom PKG Builder.app"
IDFUsersAppSupportBase="/Users/${currentUser}/Library/Application Support/$IDFBaseName";
IDFUsersAppSupportFullPath="$IDFUsersAppSupportBase/$IDFBaseName Mac Edition";

IDFSystemAppSupportPath="/Library/Application Support/$IDFBaseName";
IDFSystemLibraryPath="/Library/$IDFBaseName";

IDFPrefsPlistName="$IDFReverseDomainRoot.macedition.plist";
IDFPrefsXMLName="$IDFReverseDomainRoot.macedition.xml";
IDFPrefsFirstRunXMLName="$IDFReverseDomainRoot.macedition.firstrun.xml";

SpirionBaseName='Spirion'
SpirionAppName="$SpirionBaseName.app";
SpirionPKGBuilderName="$SpirionBaseName Client Custom PKG Builder.app"
SpirionUsersAppSupportBase="/Users/${currentUser}/Library/Application Support/$SpirionBaseName";
SpirionUsersAppSupportFullPath="$SpirionUsersAppSupportBase/$SpirionBaseName Mac Edition";

SpirionSystemAppSupportPath="/Library/Application Support/$SpirionBaseName";
SpirionSystemLibraryPath="/Library/$SpirionBaseName";

EndpointServiceExeName='EndpointService'
UserAgentExeName='UserAgent'
LaunchAgent="$IDFReverseDomainRoot.launchagent.plist";
LaunchDaemon="$IDFReverseDomainRoot.launchdaemon.plist";

function printResult { echo $*; }

# Replace this name with the actual name of your installer package.
# See http://support.identityfinder.com/entries/114922 for full instructions.
# Run man pkgutil for additional information.
IDFPackageName='com.identityfinder.pkg';
IDFReceiptName='Identityfinder.pkg';

RemoveFileOrDirectory () {
	# sudoStr="";
	# if (($askForPassword==1)); then
	# 	sudoStr="sudo";
	# fi
  # $sudoStr rm -Rf "$1";
	/bin/rm -Rf "$1"
  rmresult=$?;
  if (($runSilently==0)); then
    if [ $rmresult -eq 0 ]; then
      if [ -e "$1" ]; then
        echo "$1 delete FAILED, try with the password option, -p and enter the admin password.";
      else
        echo "$1 REMOVED.";
      fi
    else
      echo "mv $1 FAILED with error $?, try with the password option, -p and enter the admin password.";
    fi
  fi
}

PrintHelp () {
    echo "NAME";
    echo "    UninstallIDF -- uninstall $IDFBaseName and/or $SpirionBaseName.";
    echo "SYNOPSIS";
    echo "    UninstallIDF [options]"; 
    echo "COPYRIGHT"
    echo "    UninstallIDF Copyright (C) 2017 $SpirionBaseName, LLC.";
    echo "DESCRIPTION"
    echo "    Run this script to uninstall the $IDFBaseName or $SpirionBaseName applications,";
    echo "    launch agents and daemon, data files, preferences files, licenses,";
    echo "    and activation files, optionally running silently and auto-answering";
    echo "    Yes or No to uninstall level.";
    echo "";
    echo "    Answer Yes to the \"Preserve user prefs? (Yes/No)\" prompt to unload";
    echo "    and delete the launch agent, launch daemon, and applications.";
    echo "";
    echo "    Answer No to the \"Preserve user prefs? (Yes/No)\" prompt to unload and";
    echo "    delete the launch agent, launch daemon, applications, and";
    echo "    all licenses, activation files, and preferences files.";
    echo "OPTIONS";
    echo "    -s Run silently.";
    echo "    -y Answer Yes to \"Preserve user prefs? (Yes/No)\" prompt.";
    echo "    -n Answer No to \"Preserve user prefs? (Yes/No)\" prompt.";
    echo "    -p Ask for administrator password to remove system resources.";
    echo "    -h Prints this help message.";
}

UnloadAndDeleteLaunchDaemon () {
	if (($runSilently==0)); then
		echo "Unload and delete launch daemon...";
	fi
	if ! [ -e "/Library/LaunchDaemons/$LaunchDaemon" ]; then
		if (($runSilently==0)); then
			echo "$LaunchDaemon not installed.";
		fi
	else
		# if [ -n "$(sudo launchctl list|grep com.identityfinder.launchdaemon)" ]; then
		if [ -n "$( /bin/launchctl list | /usr/bin/grep com.identityfinder.launchdaemon)" ]; then
			echo "$LaunchDaemon is running, unloading...";
			# sudo /bin/launchctl unload "/Library/LaunchDaemons/$LaunchDaemon";
			/bin/launchctl unload "/Library/LaunchDaemons/$LaunchDaemon";
		else
			echo "$LaunchDaemon is NOT running.";
		fi

		# Before removing, get the name of the current EndpointService binary, it may
		# have been renamed.
		EndpointServiceExeName=$(/usr/bin/basename "$(/usr/bin/grep -A 2 ProgramArguments /Library/LaunchDaemons/$LaunchDaemon | /usr/bin/grep string | /usr/bin/sed -e 's/^[[:space:]]*//;s/<[/]*string>//g')")

		echo "The current EndpointServiceExeName is $EndpointServiceExeName."

		RemoveFileOrDirectory "/Library/LaunchDaemons/$LaunchDaemon";

		if ! [ -e "/Library/LaunchDaemons/$LaunchDaemon" ]; then
			if (($runSilently==0)); then
				echo "SUCCEEDED removing $LaunchDaemon.";
			fi
		fi
	# Remove any other Identity Finder files in this directory.
	RemoveFileOrDirectory "/Library/LaunchDaemons/$IDFReverseDomainRoot.*";
	fi
}

UnloadAndDeleteLaunchAgents () {
  # Look for the old launch agent.
	if (($runSilently==0)); then
		echo "Unload and delete /Users/${currentUser}/Library/LaunchAgents/$LaunchAgent...";
	fi
	if ! [ -e "/Users/${currentUser}/Library/LaunchAgents/$LaunchAgent" ]; then
		if (($runSilently==0)); then
			echo "/Users/${currentUser}/Library/LaunchAgents/$LaunchAgent not installed.";
		fi
	else
		/bin/launchctl unload "/Users/${currentUser}/Library/LaunchAgents/$LaunchAgent";
		RemoveFileOrDirectory "/Users/${currentUser}/Library/LaunchAgents/$LaunchAgent";
		if ! [ -e "/Users/${currentUser}/Library/LaunchAgents/$LaunchAgent" ]; then
			if (($runSilently==0)); then
				echo "SUCCEEDED removing /Users/${currentUser}/Library/LaunchAgents/$LaunchAgent.";
			fi
		fi
	fi
  # And the newer one...
  if (($runSilently==0)); then
		echo "Unload and delete /Library/LaunchAgents/$LaunchAgent...";
	fi
	if ! [ -e "/Library/LaunchAgents/$LaunchAgent" ]; then
		if (($runSilently==0)); then
			echo "/Library/LaunchAgents/$LaunchAgent not installed.";
		fi
	else
		sudo -u $currentUser /bin/launchctl unload -S Aqua "/Library/LaunchAgents/$LaunchAgent";

		# Before removing, get the name of the current UserAgent binary, it may
		# have been renamed.
		UserAgentExeName=$(/usr/bin/basename "$( /usr/bin/grep -A 2 ProgramArguments /Library/LaunchAgents/$LaunchAgent | /usr/bin/grep string | /usr/bin/sed -e 's/^[[:space:]]*//;s/<[/]*string>//g')")

		echo "The current UserAgentExeName is $UserAgentExeName."

		RemoveFileOrDirectory "/Library/LaunchAgents/$LaunchAgent";

		if ! [ -e "/Library/LaunchAgents/$LaunchAgent" ]; then
			if (($runSilently==0)); then
				echo "SUCCEEDED removing /Library/LaunchAgents/$LaunchAgent.";
			fi
		fi
	# Remove any other Identity Finder files in this directory.
	RemoveFileOrDirectory "/Users/${currentUser}/Library/LaunchAgents/$IDFReverseDomainRoot.*";
	fi

	if (($askForPassword==1)); then
		UnloadAndDeleteLaunchDaemon;
	fi
}

# $1 Identity Finder.app or Spirion.app
# $2 Identity Finder Client Custom PKG Builder.app or Spirion Client Custom PKG Builder.app
DeleteApps () {
	if [ -z "$1" ]; then
		echo "DeleteApps: no app name provided, exiting."
		exit 1
	fi

	if [ -z "$2" ]; then
		echo "DeleteApps: no Pkg Builder name provided, exiting."
		exit 1
	fi

#	This find command takes a very long time, but might be useful.
#	echo "Finding and removing all ${IDFAppName}s in $HOME...";
#	find / -type d -name "$IDFAppName" -print -exec rm -Rf {} \; ;

	if (($runSilently==0)); then
		echo "Finding and removing /Applications/$1...";
	fi
	if ! [ -e "/Applications/$1" ]; then
		if (($runSilently==0)); then
			echo "/Applications/$1 not found.";
		fi
	else
		RemoveFileOrDirectory "/Applications/$1";
	fi

	if (($runSilently==0)); then
		echo "Finding and removing /Applications/$2...";
	fi
	if ! [ -e "/Applications/$2" ]; then
		if (($runSilently==0)); then
			echo "/Applications/$2 not found.";
		fi
	else
		RemoveFileOrDirectory "/Applications/$2";
	fi
}

DeleteUsersShared () {
	RemoveFileOrDirectory "$UsersSharedPath/AdminData";
	RemoveFileOrDirectory "$UsersSharedPath/AdminDataBackup";
	RemoveFileOrDirectory "$UsersSharedPath/Actions";
	RemoveFileOrDirectory "$UsersSharedPath/Application";
	RemoveFileOrDirectory "$UsersSharedPath/.DS_Store";
	RemoveFileOrDirectory "$UsersSharedPath/completedtasks.txt";
	RemoveFileOrDirectory "$UsersSharedPath/crashstatus.db";
	RemoveFileOrDirectory "$UsersSharedPath/endpointid.dat";
	RemoveFileOrDirectory "$UsersSharedPath/$EndpointServiceExeName";
	RemoveFileOrDirectory "$UsersSharedPath/epssettings.xml";
	RemoveFileOrDirectory "$UsersSharedPath/hostnames.db";
	RemoveFileOrDirectory "$UsersSharedPath/Installer";
	RemoveFileOrDirectory "$UsersSharedPath/LiveMode";
	RemoveFileOrDirectory "$UsersSharedPath/LocationsActions";
	RemoveFileOrDirectory "$UsersSharedPath/Logs";
	RemoveFileOrDirectory "$UsersSharedPath/MCData";
	RemoveFileOrDirectory "$UsersSharedPath/mclog";
	RemoveFileOrDirectory "$UsersSharedPath/Settings";
	RemoveFileOrDirectory "$UsersSharedPath/Tasks";
	RemoveFileOrDirectory "$UsersSharedPath/TasksCleanup";
	RemoveFileOrDirectory "$UsersSharedPath/TasksMonitor";
	RemoveFileOrDirectory "$UsersSharedPath/Temp";

	# lsOutput=$(ls "$UsersSharedPath");
	lsOutput=$(ls "$UsersSharedPath" 2> /dev/null )

	if [ -n "$lsOutput" ]; then
		echo "$UsersSharedPath is not empty."
	else
		RemoveFileOrDirectory "$UsersSharedPath";
		RemoveFileOrDirectory "$UsersSharedPathApp";
		RemoveFileOrDirectory "$UsersSharedPathBase";
	fi
}

DeleteEndpointService () {
	RemoveFileOrDirectory "$IDFSystemAppSupportPath/$EndpointServiceExeName";
	RemoveFileOrDirectory "$IDFSystemAppSupportPath/$UserAgentExeName";
	RemoveFileOrDirectory "$IDFSystemLibraryPath";
	RemoveFileOrDirectory "/var/log/endpointservice.log";
	RemoveFileOrDirectory "/var/root/Library/Application Support/$IDFBaseName";
}

# $1 IDFUsersAppSupportFullPath or SpirionUsersAppSupportFullPath.
# $2 IDFUsersAppSupportBase or SpirionUsersAppSupportBase.
DeleteEverythingExceptLicensesActivationAndPrefs () {
	if [ -z "$1" ]; then
		echo "DeleteEverythingExceptLicensesActivationAndPrefs: no path provided, exiting."
		exit 1
	fi

	if [ -z "$2" ]; then
		echo "DeleteEverythingExceptLicensesActivationAndPrefs: no base path provided, exiting."
		exit 1
	fi

	DeleteUsersShared
	DeleteEndpointService

	RemoveFileOrDirectory "$1/databases";
	RemoveFileOrDirectory "$1/endpointservice.log";
	RemoveFileOrDirectory "$1/autorecover";
	RemoveFileOrDirectory "$1/identitydb.dat";
	RemoveFileOrDirectory "$1/identityinfo.dat";
	RemoveFileOrDirectory "$1/identityinfo.sqlite";
	RemoveFileOrDirectory "$1/idflogs.dat";
	RemoveFileOrDirectory "$1/logs";
	RemoveFileOrDirectory "$1/logtime.dat";

	# lsOutput=$(ls "$1");
	lsOutput=$( ls "$1" 2> /dev/null )

	if [ -n "$lsOutput" ]; then
		echo "$1 is not empty."
	else
		RemoveFileOrDirectory "$1";
		RemoveFileOrDirectory "$2";
	fi
}

DeleteLicensesActivationAndPrefs () {
	# Remove activation file.
	RemoveFileOrDirectory "$UsersSharedPath/app.dat";
	# Remove license file in ~/Library/Application Support/Identity Finder
	RemoveFileOrDirectory "$IDFUsersAppSupportFullPath/identityfinder.lic";
	RemoveFileOrDirectory "$SpirionUsersAppSupportFullPath/identityfinder.lic";
	# Remove license file in the /Library/Application Support/Identity Finder.
	RemoveFileOrDirectory "$IDFSystemAppSupportPath/identityfinder.lic";
	# Remove Identity Finder.app user plist prefs.
	RemoveFileOrDirectory "$UsersPrefsPath/$IDFPrefsPlistName";
	# Remove Identity Finder.app user plist prefs backup in Identity Finder subdir.
	RemoveFileOrDirectory "$UsersPrefsPath/$IDFBaseName/$IDFPrefsPlistName";
	# Remove Identity Finder.app user xml prefs.
	RemoveFileOrDirectory "$UsersPrefsPath/$IDFBaseName/$IDFPrefsXMLName";
	# Remove Identity Finder Client Custom PKG Builder.app user prefs.
	RemoveFileOrDirectory "$UsersPrefsPath/$IDFPKGBuilderPrefsName";
	# Remove Identity Finder user prefs directory.
	RemoveFileOrDirectory "$UsersPrefsPath/$IDFBaseName";
	RemoveFileOrDirectory "$UsersPrefsPath/$SpirionBaseName";
	# Remove system prefs.
	RemoveFileOrDirectory "$SystemPrefsPath/$IDFPrefsPlistName";
	RemoveFileOrDirectory "$SystemPrefsPath/$IDFPrefsXMLName";
	RemoveFileOrDirectory "$SystemPrefsPath/$IDFPrefsFirstRunXMLName";
	# Remove the remaining directories.
	RemoveFileOrDirectory "$UsersSharedPathBase";
	RemoveFileOrDirectory "$IDFUsersAppSupportBase";
	RemoveFileOrDirectory "$IDFSystemAppSupportPath";
}

CleanPackageMakerDB () {
	# sudoStr="";
	# if (($askForPassword==1)); then
	# 	sudoStr="sudo";
	# fi
	if [ -n "$IDFPackageName" ]; then
		if (($runSilently==0)); then
			echo "Calling pkgutil unlink...";
		fi
		# $sudoStr pkgutil --force --unlink "$IDFPackageName" > /dev/null 2> /dev/null;
		/usr/sbin/pkgutil --force --unlink "$IDFPackageName" > /dev/null 2> /dev/null;
		if (($runSilently==0)); then
			echo "Calling pkgutil forget...";
		fi
		# $sudoStr pkgutil --force --forget "$IDFPackageName" > /dev/null 2> /dev/null;
		/usr/sbin/pkgutil --force --forget "$IDFPackageName" > /dev/null 2> /dev/null;
    if [ -d "$ReceiptsPath/$IDFReceiptName" ]; then
      RemoveFileOrDirectory "$ReceiptsPath/$IDFReceiptName";
    else
      if (($runSilently==0)); then
        echo "$ReceiptsPath/$IDFReceiptName not found.";
      fi
		fi
	else
		if (($runSilently==0)); then
			echo "Shell variable IDFPackageName is empty, no pkgutil operations performed.";
		fi
	fi
}

OPTERR=0;
# while getopts synph opts
# do
#     case $opts in
# 		s) runSilently=1;;
# 		y) answerYes=1; answerNo=0;;
# 		n) answerYes=0; answerNo=1;;
# 		p) askForPassword=1;;
# 		h) PrintHelp; exit 0;;
#     esac;
# done;

if (($runSilently==1)); then
	if (($answerYes==1)); then
		UnloadAndDeleteLaunchAgents; 
		DeleteApps "$IDFAppName" "$IDFPKGBuilderName";
		DeleteApps "$SpirionAppName" "$SpirionPKGBuilderName";
		DeleteEverythingExceptLicensesActivationAndPrefs "$IDFUsersAppSupportFullPath" "$IDFUsersAppSupportBase";
		DeleteEverythingExceptLicensesActivationAndPrefs "$SpirionUsersAppSupportFullPath" "$SpirionUsersAppSupportBase";
		CleanPackageMakerDB;
	else
		if (($answerNo==1)); then
			UnloadAndDeleteLaunchAgents; 
			DeleteApps "$IDFAppName" "$IDFPKGBuilderName";
			DeleteApps "$SpirionAppName" "$SpirionPKGBuilderName";
			DeleteEverythingExceptLicensesActivationAndPrefs "$IDFUsersAppSupportFullPath" "$IDFUsersAppSupportBase";
			DeleteEverythingExceptLicensesActivationAndPrefs "$SpirionUsersAppSupportFullPath" "$SpirionUsersAppSupportBase";
			CleanPackageMakerDB;
			DeleteLicensesActivationAndPrefs;
		else
			echo "Options error: specify -y for YES or -n for NO when running silently.";
			exit 1;
		fi
	fi
else
	echo "Starting $IDFBaseName/$SpirionBaseName $0 script at $(date)";
	# if (($answerYes==0)); then
	# 	read -a answer -p "Preserve user prefs? (Yes/No)";
	# 	theAnswer=${answer[0]};
	# else
	# 	theAnswer='y';
	# fi

	# case "$theAnswer" in
	# 	(Yes|yes|YES|Y|y)
	# 		UnloadAndDeleteLaunchAgents;
	# 		DeleteApps "$IDFAppName" "$IDFPKGBuilderName";
	# 		DeleteApps "$SpirionAppName" "$SpirionPKGBuilderName";
	# 		DeleteEverythingExceptLicensesActivationAndPrefs "$IDFUsersAppSupportFullPath" "$IDFUsersAppSupportBase";
	# 		DeleteEverythingExceptLicensesActivationAndPrefs "$SpirionUsersAppSupportFullPath" "$SpirionUsersAppSupportBase";
	# 		CleanPackageMakerDB;;
	# 	(No|no|NO|N|n)
	# 		UnloadAndDeleteLaunchAgents;
	# 		DeleteApps "$IDFAppName" "$IDFPKGBuilderName";
	# 		DeleteApps "$SpirionAppName" "$SpirionPKGBuilderName";
	# 		DeleteEverythingExceptLicensesActivationAndPrefs "$IDFUsersAppSupportFullPath" "$IDFUsersAppSupportBase";
	# 		DeleteEverythingExceptLicensesActivationAndPrefs "$SpirionUsersAppSupportFullPath" "$SpirionUsersAppSupportBase";
	# 		CleanPackageMakerDB;
	# 		DeleteLicensesActivationAndPrefs;;
	# esac;

		UnloadAndDeleteLaunchAgents
		DeleteApps "${IDFAppName}" "${IDFPKGBuilderName}"
		DeleteApps "${SpirionAppName}" "${SpirionPKGBuilderName}"
		DeleteEverythingExceptLicensesActivationAndPrefs "$IDFUsersAppSupportFullPath" "$IDFUsersAppSupportBase"
		DeleteEverythingExceptLicensesActivationAndPrefs "$SpirionUsersAppSupportFullPath" "$SpirionUsersAppSupportBase"
		CleanPackageMakerDB

	if [[ $answerYes == 0 ]]; then
		echo "Deleting the user preferences..."
		DeleteLicensesActivationAndPrefs
	elif [[ $answerYes == 1 ]]; then
		echo "Preserving the user preferences..."
	else
		echo "*** WARNING:  Did not specify whether to preserve the user preferences... ***"
		echo "Preserving the user preferences..."
	fi

	echo "Completed $IDFBaseName/$SpirionBaseName $0 script at $(date).";
fi

exit 0;
