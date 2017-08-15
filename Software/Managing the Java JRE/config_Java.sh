#!/bin/bash

###################################################################################################
# Script Name:  config_Java.sh
# By:  Zack Thompson / Created:  8/11/2015
# Version:  1.0 / Updated:  8/14/2017 / By:  ZT
#
# Description:  This script installs the Java customizations used by the organization.
#
###################################################################################################

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