#!/bin/bash

###################################################################################################
# Script Name:  license_NVivo.sh
# By:  Zack Thompson / Created:  3/14/2018
# Version:  1.1 / Updated:  9/20/2018 / By:  ZT
#
# Description:  This script applies the license for NVivo.
#
# Details:  http://techcenter.qsrinternational.com/desktop/welcome/toc_welcome.htm
#
###################################################################################################

echo "*****  License NVivo process:  START  *****"

##################################################
# Define Variables
licenseKey11="NVT11-12345-67891-01234-56789"
licenseKey12="NVT12-12345-67891-01234-56789"

##################################################
# Define Functions

# Initialize license.
initialize() {
	echo "Initializing the license..."

	# Get the version of NVivo that will be licensed.
	NVivoVersion=$(/usr/bin/defaults read "${appPath}/Contents/Info.plist" CFBundleShortVersionString | /usr/bin/awk -F "." '{print $1}')

	# Determine the license key to use.
	case "${NVivoVersion}" in
		"11" )
			licenseKey="${licenseKey11}"
		;;
		"12" )
			licenseKey="${licenseKey12}"
		;;
	esac

	exitStatus=$("${NVivoPath}/${NVivoBinary}" -initialize "${licenseKey}")

	if [[ "${exitStatus}" != *"Your license key has been successfully initialized"* && "${exitStatus}" != *"The specified license key has already been initialized."* ]]; then
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
	exitStatus=$("${NVivoPath}/${NVivoBinary}" -activate "${licenseFile}")

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
	exitStatus=$("${NVivoPath}/${NVivoBinary}" -extend "${licenseFile}")

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
	exitStatus=$("${NVivoPath}/${NVivoBinary}" -deactivate)

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

# Find installs of NVivo
appPaths=$(/usr/bin/find -E /Applications -iregex ".*/NVivo(.*)?[.]app" -type d -prune)

# Verify that a NVivo version was found.
if [[ -z "${appPaths}" ]]; then
	echo "A version of NVivo was not found in the expected location!"
	echo "*****  License NVivo process:  FAILED  *****"
	exit 1
else
	# If the machine has multiple NVivo Applications, loop through them...
	while IFS="\n" read -r appPath; do

		NVivoPath="${appPath}/Contents/MacOS"
		NVivoBinary=$(/usr/bin/defaults read "${appPath}/Contents/Info.plist" CFBundleExecutable)
		licenseFile="${NVivoPath}/license.xml"

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

	done < <(echo "${appPaths}")
fi

echo "*****  License NVivo process:  COMPLETE  *****"
exit 0