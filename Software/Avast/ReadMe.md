# Avast


## Deploying and Licensing ##

So...Avast deploying Avast is different for a number of reasons.

1)  I could not get the latest client from this Web Admin Console for some time.  i.e.  The latest I could get was v12.9 while the latest available was v10.5 or newer.  (This was getting close to a year.)

2)  Another strange one is the licensing.  When you download the installer from the Web Admin Console, it basically created a .dmg with a installer .pkg, an uninstaller .app and a hidden config.tar.  This config.tar file contains all the licensing information that is unique to your organization.  The license in this config file, is a thirty day, Temporary license, which starts from the date of create of the .dmg.  Once that 30 days is up, it will install, but it is expired and immediately alerts the user.

So couple #1 and #2, then that meant that I would have to create a new installer every thirty days, and upload into Jamf.  This seemed silly when I was downloading the same version every time.  So I figured out that I could just pull the license information out of the .dmg and *deploy* it and the installer .pkg separately.

I have two methods documented in the `license_Avast.sh` script.  Either should work...if this is an annoyance for you as well.  All content has been obfuscated.


## Configuration Notes ##

Everything below is configuration details found in plists or configuration files that can be edited to set preferences found in the application GUI.  I use these in a Jamf Extension Attribute to get the status of the local client.  Around the release of version v13, the configuration files for the Shields changed from a traditional `ini` formatted file, to a `JSON` formatted file.

Values
  * 0 = Disabled
  * 1 = Enabled


Shields
  * File
    * Location:  /Library/Application Support/Avast/config/com.avast.fileshield.conf
    * If enabled, the file contains an empty json object `{}`
  * Mail and Web
    * Location:  /Library/Application Support/Avast/config/com.avast.proxy.conf
    * JSON objects for mailshield and webshield
      * The objects do not specify if the shields are enabled, only disabled


Update Config
  * Location:  /Library/Application Support/Avast/config/com.avast.update.conf
  * Virus Definitions
    * VPS_UPDATE_ENABLED=1
  * Program
    * PROGRAM_UPDATE_ENABLED=1
  * Beta Channel
    * BETA_CHANNEL=0


Definition Updates
  * Location: /Library/Application Support/Avast/vps9/defs/aswdefs.ini
  * [Definitions]
    * Latest=18020506


License Info
  * Location:  /Library/Application Support/Avast/config/license.avastlic
  * CustomerName=`<Company Name>`
  * LicenseType=`<value>`
    * 0 = Standard (Premium)
    * 4 = Premium trial
    * 13 = Free, unapproved
    * 14 = Free, approved
    * 16 = Temporary
    * \* = Unknown Type


Popup duration and Menu Bar Icon Configured in
  * Location:  /Users/`<username>`/Library/Preferences/com.avast.helper.plist


Other configurable options, including Audio Notifications
  * Location:  /Library/Application Support/Avast/config/ECFG.conf
