#!/bin/bash

###################################################################################################
# Script Name:  license_NVivo.sh
# By:  Zack Thompson / Created:  3/14/2018
# Version:  1.0 / Updated:  3/14/2018 / By:  ZT
#
# Description:  This script applies the license for NVivo.
#
# Details:  http://techcenter.qsrinternational.com/desktop/nm11/nm11_mass_deployment.htm
#
###################################################################################################

echo "*****  License NVivo process:  START  *****"

##################################################
# Define Variables
licenseKey="12345-67891-01234-56789-10123"
NVivoPath="/Applications/NVivo.app/Contents/MacOS"
NVivoBinary="${NVivoPath}/NVivo"
licenseFile="${NVivoPath}/license.xml"

##################################################
# Define Functions

# Initialize license.
initialize() {
    echo "Initializing the license..."
    exitStatus=$("${NVivoBinary}" -initialize "${licenseKey}")

    if [[ "${exitStatus}" != *"Your license key has been successfully initialized"* ]]; then
        echo "ERROR:  Failed to initialize key."
        echo "ERROR Contents:  ${exitStatus}"
        echo "*****  License NVivo Process:  FAILED  *****"
        exit 3
    fi
}

# Activate license.
activate() {
    # Function createLicense
    createLicense 

    echo "Activating the license..."
    exitStatus=$("${NVivoBinary}" -activate "${licenseFile}")

    if [[ "${exitStatus}" != *"Your NVivo license has been activated"* ]]; then
        echo "ERROR:  Failed to activate key."
        echo "ERROR Contents:  ${exitStatus}"
        echo "*****  License NVivo Process:  FAILED  *****"
        exit 4
    fi
}

# Extend license.
extend() {
    echo "Extending the license..."
    exitStatus=$("${NVivoBinary}" -extend "${licenseFile}")

    if [[ "${exitStatus}" != *"Your NVivo license has been extended"* ]]; then
        echo "ERROR:  Failed to extend key."
        echo "ERROR Contents:  ${exitStatus}"
        echo "*****  License NVivo Process:  FAILED  *****"
        exit 5
    fi

    # Function activate
    activate
}

# Replace license.
replace() {
    echo "Replacing the license..."
    # Function deactivate
    deactivate
    # Function initialize
    initialize
    # Function activate
    activate
 }

# Deactivate license.
deactivate() {
    echo "Deactivating the license..."
    exitStatus=$("${NVivoBinary}" -deactivate)

    if [[ "${exitStatus}" != *"Your NVivo license has been deactivated"* ]]; then
        echo "ERROR:  Failed to deactivate key."
        echo "ERROR Contents:  ${exitStatus}"
        echo "*****  License NVivo Process:  FAILED  *****"
        exit 6
    fi
}

# Create the License File.
createLicense() {
    echo "Creating the license file..."
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
}

##################################################
# Bits staged, license software...

if [[ ! -x $NVivoBinary ]]; then
    echo "Error:  NVivo is not properly installed."
    echo "*****  License NVivo Process:  FAILED  *****"
    exit 1
else
    # Turn on case-insensitive pattern matching
    shopt -s nocasematch

    # Determine requested task.
    case "${4}" in
        "Activate" | "Activation" )
            initialize
            activate
            echo "NVivo has been activated!"
            ;;
        "Extend" | "Extension" )
            extend
            echo "NVivo has been extended!"
            ;;
        "Replace" | "Replacement" )
            replace
            echo "NVivo has been replaced!"
            ;;
        "Deactivate" | "Deactivation" )
            deactivate
            echo "NVivo has been deactivated!"
            ;;
        * )
            echo "ERROR:  Requested task is invalid"
            echo "*****  License NVivo Process:  FAILED  *****"
            exit 2
            ;;
    esac

    # Turn off case-insensitive pattern matching
    shopt -u nocasematch
fi

echo "*****  License NVivo process:  COMPLETE  *****"
exit 0