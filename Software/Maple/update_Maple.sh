#!/bin/sh

###################################################################################################
# Script Name:  update_Maple.sh
# By:  Zack Thompson / Created:  3/2/2017
# Version:  1.2 / Updated:  1/8/2018 / By:  ZT
#
# Description:  This script silently installs a Maple update.
#
###################################################################################################

/bin/echo "*****  Update Maple process:  START  *****"

##################################################
# Define Variables

# Set working directory
	pkgDir=$(/usr/bin/dirname $0)
# Version that's being updated (this will be set by the build_Maple.sh script)
	version=

##################################################
# Bits staged...

# Install Maple
/bin/echo "Installing Maple..."
	"${pkgDir}/Maple${version}MacInstaller.app/Contents/MacOS/installbuilder.sh" --mode unattended
/bin/echo "Install complete!"

# Get the location of Maple.app
	fullPath=$(/usr/bin/find /Applications -name "Maple *.app" | /usr/bin/grep -Ev ".app/")

# Inject the proper version into the Info.plist file -- this may not be required for every version; but was not done in 2016.0X updates
	/usr/bin/sed -i '' 's/2016.00/2016.02/' $fullPath/Contents/Info.plist

/bin/echo "*****  Update Maple process:  COMPLETE  *****"

exit 0