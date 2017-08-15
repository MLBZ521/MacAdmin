#!/bin/sh

###########################################################
# Script Name:  Config_Staff.sh
# By:  Zack Thompson / Created:  5/14/2015
# Version:  2.3 / Updated:  9/4/2015 / By:  ZT
#
# Description:  This is an configuration script to configure existing Macs in the environment.
#
###########################################################

# ==================================================
# Define Variables
# ==================================================
user=$(logname)
userHome=$(eval echo ~$(echo $user))

# ==================================================
# Script Body
# ==================================================

# Clear ARD Settings
Echo "Clearing ARD Settings..."
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -deactivate -uninstall -settings -prefs -configure -privs -none -computerinfo -set1 -1 "" -computerinfo -set2 -2 "" -computerinfo -set3 -3 "" -computerinfo -set4 -4 "" -clientopts -setreqperm -reqperm no -clientopts -setvnclegacy -vnclegacy no -restart -agent

# Configure ARD Settings
Echo "Configuring ARD Settings..."
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -activate -configure -access -on -privs -all -users ard_admin -allowAccessFor -specifiedUsers -clientopts -setdirlogins -dirlogins yes -setvnclegacy -vnclegacy  yes -setvncpw -vncpw 'VNCPassword!' -restart -agent

# Add Domain Admins AD Group to local admin Group.
Echo "Adding Domain Admins AD Group to local admin Group..."
sudo dseditgroup -o edit -a "Domain Admins" -t group admin

# Add Domain Users AD Group to local lpadmin Group -- this is the "Print Admin" group.
Echo "Adding Domain Users AD Group to local lpadmin Group..."
sudo dseditgroup -o edit -a "Domain Users" -t group lpadmin

# Connect to currently logged in (console) user with VNC.
Echo "Setting VNC option to connect to currently logged in (console) user..."
sudo defaults write /Library/Preferences/com.apple.RemoteManagement VNCAlwaysStartOnConsole -bool true

# Turn off DS_Store file creation on network volumes
Echo "Turnning off DS_Store file creation on network volumes..."
sudo defaults write /Library/Preferences/com.apple.desktopservices DSDontWriteNetworkStores true
sudo defaults write /System/Library/User\ Template/English.lproj/Library/Preferences/com.apple.desktopservices DSDontWriteNetworkStores true

# Disable default file sharing for guest
Echo "Disabling file sharing for guest..."
sudo defaults write /Library/Preferences/com.apple.AppleFileServer guestAccess -bool false

# Disable iCloud & Apple Assistant Popup for new user creation
Echo "Disabling iCloud & Apple Assistant popup for new user creation..."
sudo defaults write /System/Library/User\ Template/Library/Preferences/com.apple.SetupAssistant DidSeeCloudSetup -bool TRUE
sudo defaults write /System/Library/User\ Template/Library/Preferences/com.apple.SetupAssistant GestureMovieSeen none
sudo defaults write /System/Library/User\ Template/Library/Preferences/com.apple.SetupAssistant LastSeenCloudProductVersion 10.10
sudo mv /System/Library/CoreServices/Setup\ Assistant.app/Contents/SharedSupport/MiniLauncher /System/Library/CoreServices/Setup\ Assistant.app/Contents/SharedSupport/MiniLauncher.backup
sudo defaults write /System/Library/User\ Template/English.lproj/Library/Preferences/com.apple.finder.plist ProhibitGoToiDisk -bool YES

# Disable Time Machine's & pop-up message whenever an external drive is plugged in
Echo "Disabling Time Machine's pop-up message whenever an external drive is plugged in..."
sudo defaults write /System/Library/User\ Template/Library/Preferences/com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true
sudo defaults write /Library/Preferences/com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true
# sudo defaults write /Library/Preferences/com.apple.TimeMachine AutoBackup -boolean NO

# Configure Munki Repo
Echo "Configuring Munki Repo..."
sudo defaults write /Library/Preferences/ManagedInstalls SoftwareRepoURL "https://osxserver.domain.org/Munki_Repo"
sudo defaults write /Library/Preferences/ManagedInstalls ClientIdentifier "Staff"
sudo defaults write /Library/Preferences/ManagedInstalls InstallAppleSoftwareUpdates -bool True
# sudo defaults write /Library/Preferences/ManagedInstalls SoftwareUpdateServerURL ""

# Bootstrap Munki; creates file that the Munki deamon checks to see if it exits on start and if it does, will check the repo for software updates.
Echo "Bootstraping Munki..."
touch /Users/Shared/.com.googlecode.munki.checkandinstallatstartup

Echo "Configuration Complete!"
exit 0
