# Avast

## Configuration Notes ##

Everything below is configuration details found in plists or configuration files that can be edited to set preferences found in the application GUI.  I use these in a Jamf Extension Attribute to get the status of the local client.


0 = Disabled
1 = Enabled


Shields
 * Mail and Web
  * Location:  /Library/Application Support/Avast/config/com.avast.proxy.conf
  * [mail]
   * ENABLED=1
  * [web]
   * ENABLED=1
 * File
  * Location:  /Library/Application Support/Avast/config/com.avast.fileshield.conf
  * ENABLED=1


Updates Enabled
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
 * CustomerName=<Company Name>
 * LicenseType=<value>
  * 0 = Standard (Premium)
  * 4 = Premium trial
  * 13 = Free, unapproved
  * 14 = Free, approved
  * 16 = Temporary
  * \* = Unknown Type


Popup duration and Menu Bar Icon Configured in
 * Location:  /Users/<username>/Library/Preferences/com.avast.helper.plist


Other configurable options, including Audio Notifications
 * Location:  /Library/Application Support/Avast/config/ECFG.conf
