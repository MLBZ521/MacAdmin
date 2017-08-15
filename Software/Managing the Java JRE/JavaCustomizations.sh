#!/bin/bash

###################################################################################################
# Script Name:  JavaCustomizations.sh
# By:  Zack Thompson / Created:  8/11/2015
# Version:  1.3 / Updated:  9/11/2015 / By:  ZT
#
# Description:  This script installs the Java Customizations used by the Organization.
#
###################################################################################################

# ======================================================================
# Import Code Signing Cert into the Java cacerts store
# ======================================================================

keytool=/Library/Internet\ Plug-Ins/JavaAppletPlugin.plugin/Contents/Home/Bin/keytool

# Check if the cert has been installed and assign output to variable.
CheckKeyStore=$("$keytool" -list -storepass changeit -keystore /Library/Internet\ Plug-Ins/JavaAppletPlugin.plugin/Contents/Home/lib/security/cacerts -alias CodeSigningCert)

# Assigning the unique MD5 Cert FingerPrint to a varaible.
NotImported="does not exist"

# If the Cert FingerPrint isn't found, then the cert is not installed, if it is found, it is already installed. 
if [[ $CheckKeyStore == *"$NotImported"* ]]; then
	Echo "Certificate has not been installed; installing now..."
	mkdir /Volumes/Policies
	mount -t smbfs "//user:password@domain.org/SysVol/domain.org/Policies/" /Volumes/Policies
	"$keytool" -importcert -keystore /Library/Internet\ Plug-Ins/JavaAppletPlugin.plugin/Contents/Home/lib/security/cacerts -storepass changeit -alias CodeSigningCert -file /Volumes/Policies/{7AFF61C7-4480-443E-A0CC-7DC96C0BD7D7}/Machine/Scripts/Startup/CodeSignCert.cer -noprompt
	Echo 'Certificate installed!'
	umount /Volumes/Policies
else
	Echo "Certificate has already been installed"
fi

# ======================================================================

# Copy over the Java Deployment Rule Set and Deployment Configuration files
sudo mkdir /Library/Application\ Support/Oracle/Java/Deployment/
sudo cp /Library/IT_Staging/DeploymentRuleSet.jar /Library/Application\ Support/Oracle/Java/Deployment/DeploymentRuleSet.jar
sudo cp /Library/IT_Staging/deployment.config /Library/Application\ Support/Oracle/Java/Deployment/deployment.config
sudo cp /Library/IT_Staging/deployment.properties /Library/Application\ Support/Oracle/Java/Deployment/deployment.properties
sudo cp /Library/IT_Staging/exception.sites /Library/Application\ Support/Oracle/Java/Deployment/exception.sites

# Set the permissions on the files so Java can read them.
sudo chmod 644 /Library/Application\ Support/Oracle/Java/Deployment/DeploymentRuleSet.jar
sudo chmod 644 /Library/Application\ Support/Oracle/Java/Deployment/deployment.config
sudo chmod 644 /Library/Application\ Support/Oracle/Java/Deployment/deployment.properties
sudo chmod 644 /Library/Application\ Support/Oracle/Java/Deployment/exception.sites

# Delete all staging files.
rm /Library/IT_Staging/*

# Disable Java Updater
sudo defaults write /Library/Preferences/com.oracle.java.Java-Updater JavaAutoUpdateEnabled -bool false

exit 0