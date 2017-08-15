#!/bin/bash

###################################################################################################
# Script Name:  install_JavaCert.sh
# By:  Zack Thompson / Created:  8/11/2015
# Version:  1.4 / Updated:  8/14/2017 / By:  ZT
#
# Description:  This script imports a certificate into the default Java cacerts keystore.  This certificate 
# was used to sign the DeploymentRuleSet.jar package to whitelist Java applets that are pre-approved.
#
# Note:  (* This has to be applied AFTER every Java update. *)
#
###################################################################################################

keytool=/Library/Internet\ Plug-Ins/JavaAppletPlugin.plugin/Contents/Home/Bin/keytool

# Check if the cert has been installed and assign output to variable.
# If cert is already installed, it will return the unique MD5 Cert FingerPrint.
CheckKeyStore=$("$keytool" -list -storepass changeit -keystore /Library/Internet\ Plug-Ins/JavaAppletPlugin.plugin/Contents/Home/lib/security/cacerts -alias CodeSigningCert)

# If the cert is not installed, it will return a string that contains "does not exist".
NotImported="does not exist"

# If the Cert FingerPrint isn't found, then the cert is not installed, if it is found, it is already installed. 
if [[ $CheckKeyStore == *"$NotImported"* ]]; then
	Echo "Certificate has not been installed; installing now..."
	"$keytool" -importcert -keystore /Library/Internet\ Plug-Ins/JavaAppletPlugin.plugin/Contents/Home/lib/security/cacerts -storepass changeit -alias CodeSigningCert -file /path/to/CodeSignCert.cer -noprompt
	Echo 'Certificate installed!'
else
	Echo "Certificate has already been installed"
fi

exit 0