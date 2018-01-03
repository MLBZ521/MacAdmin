#! /bin/sh

###################################################################################################
# Script Name:  uninstall_SPSS.sh
# By:  Zack Thompson / Created:  11/1/2017
# Version:  1.0 / Updated:  11/1/2017 / By:  ZT
#
# Description:  Remove previous version(s) of SPSS from /Applications
#
###################################################################################################

/bin/echo "**************************************************"
/bin/echo 'Starting PreInstall Script'
/bin/echo "**************************************************"

oldVersions=$(ls /Applications | grep "SPSS")

for oldVersion in $oldVersions; do
   /bin/rm -rf "/Applications/${oldVersion}"
done

/bin/echo "**************************************************"
/bin/echo 'PreInstall Script Finished'
/bin/echo "**************************************************"

exit 0
