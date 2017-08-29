#!/bin/bash

###################################################################################################
# Script Name:  config_SMBProtocol.sh
# By:  Zack Thompson / Created:  7/3/2017
# Version:  2.0 / Updated:  7/19/2017 / By:  ZT
#
# Description:  This script allows the configuration of the SMB Protocol on a Mac.
#
###################################################################################################

/bin/echo "Configuring the SMB Protocols allowed on this Mac..."

##################################################
# Define Variables
OSVersion=$(/usr/bin/sw_vers -productVersion | /usr/bin/awk -F . '{print $1"."$2}')

if [[ $OSVersion == 10\.12 ]]; then
	smbKey="sprotocol_vers_map"
	smbValue="${smbKey}=${6}"
elif [[ $OSVersion == 10\.11 || $OSVersion == 10\.10 ]]; then
	smbKey="smb_neg"
	smbValue="${smbKey}=${5}"
elif [[ $OSVersion == 10\.9 ]]; then
	smbKey="smb_neg"
	smbValue="${smbKey}=${4}"
else
	/bin/echo "This OS only supports SMBv1."
	exit 0
fi
##################################################

# Check if file exists.
if [[ -e /etc/nsmb.conf ]]; then

	# If it exists, check if the SMB Protocol is already set.
	nsmbSMBProtocol=$(/bin/cat /etc/nsmb.conf | /usr/bin/grep $smbKey)

	# Check if Protocol is currently configured.
	if [[ -n $nsmbSMBProtocol ]]; then
		# If it is currently configured...

		# Backup file.
		/bin/mv /etc/nsmb.conf /etc/nsmb.conf.orig
		# Remove configuration from original file and redirect the output to proper file.
		/usr/bin/awk "!/$smbKey/" /etc/nsmb.conf.orig > /etc/nsmb.conf
	fi

	# If/once the Protocol is not configured....

	# Check if default section is defined.
	nsmbContents=$(/bin/cat /etc/nsmb.conf | /usr/bin/grep "default")

	# Does default section exist?
	if [[ $nsmbContents == "[default]" ]]; then
		# If it is not empty...

		# Backup file.
		/bin/mv /etc/nsmb.conf /etc/nsmb.conf.bak
		# Insert configuration into contents of backup file and redirect the output to proper file.
		/usr/bin/awk '/default/ {print; print $smbValue;next}1' /etc/nsmb.conf.bak > /etc/nsmb.conf

	else
		# If the defaults section does not exist...

		# Insert the defaults section and the configuration.
		/bin/echo '[default]' >> /etc/nsmb.conf
		/bin/echo "$smbValue" >> /etc/nsmb.conf
	fi
else
	# If the file does not exist...

	# Create the file.
	/usr/bin/touch /etc/nsmb.conf

	# Insert the defaults section and the configuration.
	/bin/echo '[default]' >> /etc/nsmb.conf
	/bin/echo "$smbValue" >> /etc/nsmb.conf
fi

/bin/echo "Configuration Complete!"

exit 0