#!/bin/bash

###################################################################################################
# Script Name:  license_NVivo.sh
# By:  Zack Thompson / Created:  3/14/2018
# Version:  0.1 / Updated:  3/14/2018 / By:  ZT
#
# Description:  This script applies the license for NVivo.
#
###################################################################################################

echo "*****  License NVivo process:  START  *****"

##################################################
# Define Variables
NVivoPath="/Applications/NVivo.app/Contents/MacOS/"
NVivoBinary="${NVivoPath}/NVivo"
licenseFile="${NVivoPath}/license.xml"

##################################################
# Bits staged, license software...

if [[ ! -x $NVivoBinary ]]; then
    echo "Error:  NVivo is not properly installed."
    echo "*****  License NVivo Process:  FAILED  *****"
    exit 1
else

    # Create the License File.
    /bin/cat > "${licenseFile}" <<licenseContents
<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<Activation>
<Request>
<FirstName>First</FirstName>
<LastName>Last</LastName>
<Email>email@domain.com</Email>
<Phone></Phone>
<Fax></Fax>
<JobTitle></JobTitle>
<Sector></Sector>
<Industry></Industry>
<Role></Role>
<Department></Department>
<Organization></Organization>
<City>Tempe</City>
<Country>USA</Country>
<State>Arizona</State>
</Request>
</Activation>
licenseContents

    # Activate NVivo.
    echo "Applying the NVivo license..."
    "${NVivoBinary}" -initialize "12345-67891-01234-56789-10123" -activate "${licenseFile}"
    exitCode=$?

    # Check the 
    if [[ $exitCode = 0 ]]; then
        echo "NVivo has been licensed!"
        echo "*****  License NVivo Process:  COMPLETE  *****"
    else
        echo "Exit Code:  ${exitCode}"
        echo "ERROR:  Failed to activate NVivo."
        echo "*****  License NVivo Process:  FAILED  *****"
        exit 2
    fi
fi

exit 0