JAMF Scripts
======

This repo will contain scripts I have written for a JAMF environment.


## Scripts ##


#### assign_Mac2User.sh ####

This script assigns a Mac to a User in JAMF Inventory records for a specific device.  I had a request for a way to tie users to machines where users were not using directory accounts to sign in.  This was as quick script that I threw together to accomplish this.  I later converted this to an application using Swift and Cocoa.



#### config_SMBProtocol.sh ####

This script uses Script Parameters to configure the SMB Protocol on a Mac.  There is also an Extension Attribute that can be used for scoping.

**macOS Sierra 10.12**

For macOS Sierra, set the JSS Script Parameter 6 to your desired configuration.
* ex:  To enable SMBv2/v3 only; Script Parameter 6 = 6

From the nsmb.conf man page:
* Key = protocol_vers_map
* Default Value = 7
* Comment = Bitmap of SMB Versions that are enabled

"Bitmap of SMB Versions that are enabled" can be one of:
* 7 = SMB 1/2/3 should be enabled
* 6 = SMB 2/3 should be enabled
* 4 = SMB 3 should be enabled
* 2 = SMB 2 should be enabled
* 1 - SMB 1 should be enabled

**Mac OS X El Capitan 10.11 and Yosemite 10.10**

For OS X El Capitan and Yosemite, set the JSS Script Parameter 5 to your desired configuration.
* ex:  To enable SMBv3 only; Script Parameter 5 = smb3_only

From the nsmb.conf man page:
* Key = smb_neg
* Default Value = normal
* Comment = How to negotiate SMB 1/2/3

"How to negotiate SMB 1/2/3" can be one of:
* normal = Negotiate with SMB 1 and attempt to negotiate to SMB 2/3.
* smb1_only = Negotiate with only SMB 1.
* smb2_only = Negotiate with only SMB 2. This also will set no_netbios.
* smb3_only = Negotiate with only SMB 3. This also will set no_netbios.

**Mac OS Mavericks 10.9**

For OS X Mavericks or earlier, set the JSS Script Parameter 4 to your desired configuration.
* ex:  To enable SMBv3 only; Script Parameter 4 = smb2_only

From the nsmb.conf man page:
* Key = smb_neg
* Default Value = normal
* Comment = How to negotiate SMB 2.x

"How to negotiate SMB 2.x" can be one of:
* normal = Negotiate with SMB 1.x and attempt to negotiate to SMB 2.x.
* smb1_only = Negotiate with only SMB 1.x.
* smb2_only = Negotiate with only SMB 2.x. This also will set no_netbios.



#### install_ParallelsLicense.sh ####

This script will allow the installation of the Parallels License.  Simply enter the license in the format of "XXXXX-XXXXX-XXXXX-XXXXX-XXXXX" (without the quotes) into the parameter field and have it configured to run after the software installation of Parallels.



#### set_DefaultApplications.sh ####

For additional information, also see:  info_DefaultApplication.md

This script set default applications using Script Parameters.  This script will allow you to set the default application for both URL Schemes and Content Types (i.e. File Extensions).  There are eight parameters available for use with this script.  First we'll review the pre-configured ones to go over how to use the script.

There are two pre-configured parameters to make it easy to set the default Mail/Calendar and Browser applications.  To use a pre-configured option, enter the name into the field exactly how it appears bolded below, or it will not work.
* For the 'Set Web Browser' parameter, there are three built-in script options as well as a custom option:
  * **Chrome**
  * **Firefox**
  * **Safari**
  * (custom)
* The same is done for the 'Set Mail/Calendar Application' parameter:
  * **Outlook (Outlook for Mac)**
  * **Parallels Outlook**
  * **Apple Mail** (with Apple Calendar)
  * (custom)

For custom parameters, you will need to supply the values for the Application's CFBundleIdentifier and the URL Scheme or Content Type.

In the first box in the parameter fields, you would enter the type of content/service that is accessed and the second field you would enter the application that will be assigned.  URL Schemes are a little more self-explanatory than the Extension fields or ContentType.  You will will have to gather the type of content for a file (it's not the '.extension' unfortunately).  This will take a bit of field work to figure out; you can use the `mdls` command to assist in getting this info.  To assign to an application, you will need to enter that applications 'CFBundleIdentifier'.  For most applications, you can easily pull that with the `defaults` command.
* `mdls myFile.txt`
* `defaults read /Applications/Microsoft\ Outlook.app/Contents/Info.plist CFBundleIdentifier`

For an example, to set a custom 'ftp' application, you would need to use the Custom URL Scheme 1 and Custom URL App 1.  These two fields are linked as are the Custom [Extension|App] [1|2] or Content Type fields.

Going back to the pre-configured parameters, to use an application that is not pre-configured, you would just need to enter the applications CFBundleIdentifier.  And yes, if there is a Parallels instance (with Windows) installed on the machine, it (should)/will find the CFBundleIdentifier for the Windows instance of Microsoft Outlook and set it as the default application.

This parameters script is a little more complicated so if you have any questions or need help, feel free to let me know.

(I highly recommend testing this before deploying -- there is not an 'undo' option!)



## Extension Attributes ##


##### jamf_ea_SMBProtocol.sh ####

Check if the SMB Protocol is configured.  This is available for use with the config_SMBProtocol.sh script above.





