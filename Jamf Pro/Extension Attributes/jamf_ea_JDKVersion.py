#!/usr/bin/python

###################################################################################################
# Script Name:  jamf_ea_JDKVersion.py
# By:  Zack Thompson / Created:  3/12/2019
# Version:  1.0.0 / Updated:  3/12/2019 / By:  ZT
#
# Description:  A Jamf Extension Attribute to check the latest JDK version installed.
#
###################################################################################################

import os
import sys
try:
    from plistlib import load as plist_Reader  # For Python 3
except ImportError:
    from plistlib import readPlist as plist_Reader  # For Python 2

def main():

    # Define Variables
    jdk_Directory = '/Library/Java/JavaVirtualMachines'
    installed_JDKs = []
    installed_JDK_Versions = []
    
    # Verify if the path exists.
    if os.path.exists(jdk_Directory):
        installed_JDKs = os.listdir(jdk_Directory)
        
        # Verify at least one JDK is present.
        if len(installed_JDKs) > 0:

            # Loop through each JDK.
            for jdk in installed_JDKs:
                # print('Testing JDK:  {}'.format(jdk))

                # Get the contents of the plist file.
                try:
                    # print('Location:  {}/{}/Contents/Info.plist'.format(jdk_Directory, jdk))
                    plist_contents = plist_Reader('{}/{}/Contents/Info.plist'.format(jdk_Directory, jdk))
                except Exception:
                    print ('Unable to locate the specified plist file.')
                    sys.exit('<result>Error</result>')

                # Get the JVM Version for this JDK.
                jvm_version=plist_contents.get('JavaVM').get('JVMVersion')
                installed_JDK_Versions.append(jvm_version)

            # Get the latest version.
            newest_JDK = sorted(installed_JDK_Versions)[-1]

            if newest_JDK:
                print("<result>{}</result>".format(newest_JDK))
            else:
                print("<result>Unknown</result>")
        
        else:
            print("<result>Not installed</result>")

    else:
        print("<result>Not installed</result>")

if __name__ == "__main__":
    main()
