#!/bin/sh

###########################################################
# Script Name:  LoginScript.sh
# By:  Zack Thompson / Created:  5/14/2015
# Version:  1.0 / Updated:  6/1/2015 / By:  ZT
#
# Description:  This is the login script for Macs.
#
###########################################################

# Clear ARD Settings
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -deactivate -uninstall -settings -prefs -configure -privs -none -computerinfo -set1 -1 "" -computerinfo -set2 -2 "" -computerinfo -set3 -3 "" -computerinfo -set4 -4 "" -clientopts -setreqperm -reqperm no -clientopts -setvnclegacy -vnclegacy no -restart -agent

# Configure ARD Settings
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -activate -configure -access -on -privs -all -users -ard_admin -allowAccessFor -specifiedUsers -clientopts -setdirlogins -dirlogins yes -setvnclegacy -vnclegacy  yes -setvncpw -vncpw "VNCPassword!" -restart -agent

# Added Domain Admins AD Group to local admin Group.
sudo dseditgroup -o edit -a "Domain Admins" -t group admin

# Added Domain Users AD Group to local lpadmin Group -- this is the "Print Admin" group.
sudo dseditgroup -o edit -a "Domain Users" -t group lpadmin

# Connect to currently logged in (console) user with VNC.
sudo defaults write /Library/Preferences/com.apple.RemoteManagement VNCAlwaysStartOnConsole -bool true

# Turn off DS_Store file creation on network volumes
sudo defaults write /Library/Preferences/com.apple.desktopservices DSDontWriteNetworkStores true
sudo defaults write /System/Library/User\ Template/English.lproj/Library/Preferences/com.apple.desktopservices DSDontWriteNetworkStores true

# Disable default file sharing for guest
sudo defaults write /Library/Preferences/com.apple.AppleFileServer guestAccess -bool false

# Disable “Application Downloaded from the internet” for the particular applications below
sudo xattr -d -r com.apple.quarantine /Applications/ADPassMon.app

# Configure Settings for ADPassMon
sudo defaults write /Library/Preferences/org.pmbuko.ADPassMon selectedBehaviour -int 2
sudo defaults write /Library/Preferences/org.pmbuko.ADPassMon enableKeychainLockCheck -bool true
sudo defaults write /Library/Preferences/org.pmbuko.ADPassMon enableNotifications -bool true
sudo defaults write /Library/Preferences/org.pmbuko.ADPassMon warningDays -int 14
sudo defaults write /Library/Preferences/org.pmbuko.ADPassMon prefsLocked true

# Create a LaunchAgent for ADPassMon
sudo defaults write /Library/LaunchAgents/org.domain.ADPassMon.plist KeepAlive -bool true
sudo defaults write /Library/LaunchAgents/org.domain.ADPassMon.plist SuccessfulExit -bool false
sudo defaults write /Library/LaunchAgents/org.domain.ADPassMon.plist Label -string ADPassMon
sudo defaults write /Library/LaunchAgents/org.domain.ADPassMon.plist ProgramArguments -array /Applications/ADPassMon.app/Contents/MacOS/ADPassMon
sudo defaults write /Library/LaunchAgents/org.domain.ADPassMon.plist RunAtLoad -bool true

# Copy over Desktop Shortcuts for Existing Users
osascript -e 'mount volume "smb://server/share"'
cp /Volumes/share/GPO\ Files/Shortcut\ Icons/Intranet.webloc ~/Desktop
cp /Volumes/share/GPO\ Files/Shortcut\ Icons/Kronos\ Workforce\ Central.webloc ~/Desktop
cp /Volumes/share/GPO\ Files/Shortcut\ Icons/Support.webloc ~/Desktop
cp /Volumes/share/GPO\ Files/Shortcut\ Icons/Website 1.webloc ~/Desktop
cp /Volumes/share/GPO\ Files/Shortcut\ Icons/Website 2.webloc ~/Desktop
umount /Volumes/share

# Copy over Desktop Shortcuts for New Users
sudo osascript -e 'mount volume "smb://server/share"'
sudo cp /Volumes/share/GPO\ Files/Shortcut\ Icons/Intranet.webloc /System/Library/User\ Template/English.lproj/Desktop/
sudo cp /Volumes/share/GPO\ Files/Shortcut\ Icons/Kronos\ Workforce\ Central.webloc /System/Library/User\ Template/English.lproj/Desktop/
sudo cp /Volumes/share/GPO\ Files/Shortcut\ Icons/Support.webloc /System/Library/User\ Template/English.lproj/Desktop/
sudo cp /Volumes/share/GPO\ Files/Shortcut\ Icons/Website 1.webloc /System/Library/User\ Template/English.lproj/Desktop/
sudo cp /Volumes/share/GPO\ Files/Shortcut\ Icons/Website 2.webloc /System/Library/User\ Template/English.lproj/Desktop/
sudo umount /Volumes/share

# Disable iCloud & Apple Assistant Popup for new user creation
sudo defaults write /System/Library/User\ Template/Library/Preferences/com.apple.SetupAssistant DidSeeCloudSetup -bool TRUE
sudo defaults write /System/Library/User\ Template/Library/Preferences/com.apple.SetupAssistant GestureMovieSeen none
sudo defaults write /System/Library/User\ Template/Library/Preferences/com.apple.SetupAssistant LastSeenCloudProductVersion 10.10
sudo mv /System/Library/CoreServices/Setup\ Assistant.app/Contents/SharedSupport/MiniLauncher /System/Library/CoreServices/Setup\ Assistant.app/Contents/SharedSupport/MiniLauncher.backup
sudo defaults write /System/Library/User\ Template/English.lproj/Library/Preferences/com.apple.finder.plist ProhibitGoToiDisk -bool YES

# Disable Time Machine's & pop-up message whenever an external drive is plugged in
sudo defaults write /System/Library/User\ Template/Library/Preferences/com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true
sudo defaults write /Library/Preferences/com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true
# sudo defaults write /Library/Preferences/com.apple.TimeMachine AutoBackup -boolean NO
