#!/bin/sh

###################################################################################################
# Script Name:  config_SMBProtocol.sh
# By:  Zack Thompson / Created:  7/3/2017
# Version:  1.0 / Updated:  7/3/2017 / By:  ZT
#
# Description:  This script configures the SMB Protocol on a Mac.  Configured to disable SMBv1.
#
###################################################################################################

echo "Configuring the SMB Protocols allowed on this Mac..."

# Check if file exists.
if [[ -e /etc/nsmb.conf ]]; then

    # If it exists, check if the SMB Protocol is already set.
    nsmbSMBProtocol=$(cat /etc/nsmb.conf | /usr/bin/grep "sprotocol_vers_map")

    # Check if Protocol is currently configured.
    if [[ -n $nsmbSMBProtocol ]]; then
        # If it is currently configured...

        # Backup file.
        mv /etc/nsmb.conf /etc/nsmb.conf.orig
        # Remove configuration from original file and redirect the output to proper file.
        awk '!/sprotocol_vers_map/' /etc/nsmb.conf.orig > /etc/nsmb.conf
    fi

    # If/once the Protocol is not configured....

    # Check if default section is defined.
    nsmbContents=$(cat /etc/nsmb.conf | /usr/bin/grep "default")

    # Does default section exist?
    if [[ $nsmbContents == "[default]" ]]; then
        # If it is empty...

        # Backup file.
        mv /etc/nsmb.conf /etc/nsmb.conf.bak
        # Insert configuration into contents of backup file and redirect the output to proper file.
        awk '/default/ {print; print "sprotocol_vers_map=6";next}1' /etc/nsmb.conf.bak > /etc/nsmb.conf

    else
        # If the defaults section does not exist...

        # Insert the defaults section and the configuration.
        echo '[default]' >> /etc/nsmb.conf
        echo 'sprotocol_vers_map=6' >> /etc/nsmb.conf
    fi
else
    # If the file does not exist...

    # Create the file.
    touch /etc/nsmb.conf

    # Insert the defaults section and the configuration.
    echo '[default]' >> /etc/nsmb.conf
    echo 'sprotocol_vers_map=6' >> /etc/nsmb.conf
fi

echo "Configuration Complete!"

exit 0