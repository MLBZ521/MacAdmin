macOS.Software
======

In this repository are various scripts that I have written to maintain macOS Software.


#### com.apple.Safari ####

Description:  This `.plist` file sets the exceptions or permissions to allow a specified website to run Java and Flash plug-ins in Safari -- used it in a MDM to deploy to devices.  It is similar to the config_FirefoxPermissions.ps1 script in the Windows.Software repository.  (Dumb and strong approach, dropping it in will override any current settings...I planned to script this, just never got around to it...maybe with time I can get to this as well as adopt the Windows Firefox Permissions script for macOS as well.)


#### install_DesktopShortcuts.sh ####

Description:  This is a script to deploy Desktop Shortcuts to the logged in user and default users profiles.


#### install_Fonts.sh ####

Description:  This script copies all the fonts to the System Fonts folder.  (This was an old script I used with a custom package to provide the files and 'install' them.)


#### license_Parallels.sh ####

Description:  This script licenses Parallels Desktop.  It's written for a Jamf environment, but the license key is only expected to be provide as an argument, so this can be used in any environment.

Items that I ran into when attempting to license Parallels in a more 'Enterprise' way:
  * The Parallels CLI management utility `prlsrvctl` is symlinked on the first launch of Parallels, so need to point to the source as we're assuming Parallels has not been launched.
  * So, [Parallels Documentation](http://download.parallels.com/desktop/v13/docs/en_US/Parallels%20Desktop%20Pro%20Edition%20Command-Line%20Reference.pdf) implies, at least to me, that the `--deferred` option will take the provide license and wait to attempt activation until the first launch of Parallels.
    * _Stores the license for deferred installation. The license will be activated the next time Parallels Desktop is started._
  * However, if the required service (`prl_disp_service`) is running for licensing tasks is not started, this will fail.  The only documentation I could find for this service is this [KB Article](http://kb.parallels.com/en/8089).
  * Again, however, running the command supplied, fails to do anything.  The LaunchDaemon is not in a normal, expect path.  And running it from where it _is_ located, still fails to launch the service.
  * Locations:
  	* `prlsrvctl` symlinked to `/usr/local/bin/prlsrvctl`
  	* `prlsrvctl` source = `/Applications/Parallels Desktop.app/Contents/MacOS/prlsrvctl`
    * `prl_disp_service` = `/Applications/Parallels Desktop.app/Contents/MacOS/Parallels Service.app/Contents/MacOS/prl_disp_service`
    * LaunchDaemon = `/Applications/Parallels Desktop.app/Contents/Resources/com.parallels.desktop.launchdaemon.plist`

To Use:  Simply enter the license in the format of "XXXXX-XXXXX-XXXXX-XXXXX-XXXXX" (without the quotes) into the parameter field and have it configured to run after the software installation of Parallels.


#### Managing the Java JRE ####

Description:  These configuration files are for managing the Java Runtime Environment on client systems.  I used these files and scripts to whitelist websites and Java applets.


#### uninstall_Fonts.sh ####

Description:  This script deletes all the fonts from the System and Users Fonts folder.  (Dumb and strong approach, no checks.)
