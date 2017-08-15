macOS.Software
======

In this repository are various scripts that I have written to maintain macOS Software.


#### com.apple.Safari ####

Description:  This `.plist` file sets the exceptions or permissions to allow a specified website to run Java and Flash plug-ins in Safari -- used it in a MDM to deploy to devices.  It is similar to the config_FirefoxPermissions.ps1 script in the Windows.Software repository.  (Dumb and strong approach, dropping it in will override any current settings...I planned to script this, just never got around to it...maybe with time I can get to this as well as adopt the Windows Firefox Permissions script for macOS as well.)


#### install_DesktopShortcuts.sh ####

Description:  This is a script to deploy Desktop Shortcuts to the logged in user and default users profiles.


#### install_Fonts.sh ####

Description:  This script copies all the fonts to the System Fonts folder.  (This was an old script I used with a custom package to provide the files and 'install' them.)


#### Managing the Java JRE ####

Description:  These configuration files are for managing the Java Runtime Environment on client systems.  I used these files and scripts to whitelist websites and Java applets.


#### uninstall_Fonts.sh ####

Description:  This script deletes all the fonts from the System and Users Fonts folder.  (Dumb and strong approach, no checks.)
