Restore Recovery HD
======

If a machine is missing it's recovery partition, there are limited ways to restore it (from what I've been able to find).  In a managed, enterprise environment, the options aren't great (surprise!) for SIP enabled systems (macOS 10.12 Sierra and 10.11 El Capitan).  For macOS 10.9 Mavericks and 10.10 Yosemite, this is pretty simple.


#### Build the Restore Package ####

Four files are needed to build a package.  Each package will be OS dependent; though if you wanted one large (~2GB) package to rule them all, the logic could be added to do it all from one.

  * From each "Install macOS <Version>.app" you will need to extract the following files:
    * `BaseSystem.chunklist`
    * `BaseSystem.dmg`
  * You will need to extract the dmtest binary from Apple’s [Lion Recovery Update Package](http://support.apple.com/kb/DL1464):
  * Then the final piece will be the `postinstall_RecoveryHD.sh` script from this Repo


From here, you can create a "payload-free" package to deploy this.  You can use Greg Neagle's great little utility [munkipkg](https://github.com/munki/munki-pkg) to create this:
  * `munkipkg . --create`
  * Copy the above four files in the "Scripts" directory
  * Rename `postinstall_RecoveryHD.sh` to `postinstall`
  * Edit the `build-info.plist` as desired
  * `munkipkg .`

This will build a nice, neat little package.  Additional details for gathering these files can gathered from sources at the end if exact steps are needed.


#### Deploying Packages ####

For 10.9 and 10.10 systems, you can simple build the package described above and deploy it (via Jamf, Munki, or ARD) to the systems which will automatically recreate the Recovery HD.

For 10.12 and 10.11 though, you have to be in an unbooted state; examples are:
  * Booted into Internet Recovery
    * Installing the pkg via terminal worked without issue:
  	  * `installer -pkg <name_of_pkg> -target </Volumes/Macintosh\ HD>`
  * Target Disk Mode
  * NetBoot Set (i.e. DeployStudio)
    * In my environment, we currently have a pre-existing DeployStudio environment setup for imaging, so I have setup a workflow that techs can use to restore a missing Recovery HD.
    * The workflow goes like this:
  	  * Task 1:  Select Target
  	    * I allow the tech to select the Volume, because who knows if the boot volume is the default "Macintosh HD"
  	  * Task 2:  Run Script:  `install_RecoveryHDpkg.sh` (available in this Repo)
  	    * The following items may need to be accounted for in your DS Environment:
  	      * Set the location of the stored files
  	      * The PlistBuddy Utility needs to be available
        * Notes:
      	  * If I booted to a NetBoot Set of a different version than what I was restoring, then I had strange issues:
            * i.e. If I installed the 10.12 package while booted in a 10.11 NetBoot Set, it would restore the Recovery HD, however the package/workflow would never complete (also the Recovery HD name was set to EFI Boot, which was seen when Option Booting)
      * Task 3:  Message Prompt
        * This seemed to help some weirdness observed where the process would recreate the Recovery HD, but not complete the workflow process.


Sources:  
  * https://managingosx.wordpress.com/2012/08/15/creating-recovery-partitions/
  * https://davidjb.com/blog/2016/12/creating-a-macos-recovery-partition-without-reinstalling-osx-or-re-running-your-installer/
