#!/bin/sh

###################################################################################################
# Script Name:  license_Fetch.sh
# By:  Zack Thompson / Created:  6/28/2017
# Version:  1.0 / Updated:  6/28/2017 / By:  ZT
#
# Description:  This script will license Fetch with ASU's License.
#
###################################################################################################

plist="/Library/Preferences/com.fetchsoftworks.Fetch.License"
registrantName="Customer Name"
serialNumber="FETCH12345-6789-0123-4567-8910-1112"

/usr/bin/defaults write $plist SerialNumber "$serialNumber"
/usr/bin/defaults write $plist RegistrantName "$registrantName"