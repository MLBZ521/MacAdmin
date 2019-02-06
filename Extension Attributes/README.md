Extension Attributes
======

##### jamf_ea_AvastStatus.sh #####

Checks the current configuration of Avast.  The following are what is checked and what files these settings are found in:
* Values
  * 0 = Disabled
  * 1 = Enabled
* Mail and Web Shields:  /Library/Application Support/Avast/config/com.avast.proxy.conf
* File Shield:  /Library/Application Support/Avast/config/com.avast.fileshield.conf
* Updates:  /Library/Application Support/Avast/config/com.avast.update.conf
  * Virus Definitions
  * Program
  * Beta Channel
* Definition Updates:  /Library/Application Support/Avast/vps9/defs/aswdefs.ini
* License Info:  /Library/Application Support/Avast/config/license.avastlic
  * CustomerName
  * LicenseType
    * 0=Standard (Premium)
    * 4=Premium trial
    * 13=Free, unapproved
    * 14=Free, approved
    * 16=Temporary


##### jamf_ea_GetSSID.sh ####

Checks and returns one of the following:
* the SSID of the currently connected WiFi Network
* Not Connected
* Off (If WiFi is off)


##### jamf_ea_LatestOSSupported.sh ####

Checks the latest compatible version of macOS that a device's current state supports.  i.e. current HW and OS Version can be upgraded to.  Supports:
* High Sierra
* Sierra
* El Capitan


##### jamf_ea_SMBProtocol.sh ####

Check if the SMB Protocol is configured.  This is available for use with the config_SMBProtocol.sh script above.

