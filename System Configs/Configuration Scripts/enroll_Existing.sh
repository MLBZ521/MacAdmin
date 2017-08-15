#!/bin/bash

###################################################################################################
# Script Name:  Enroll_Existing.sh
# By:  Zack Thompson / Created:  5/20/2015
# Version:  1.1 / Updated:  8/13/2015 / By:  ZT
#
# Description:  This script installs the MDM Profiles to enroll existing OS X devices.
#
###################################################################################################

# Install the Trust Profile then the enrollment profile.
sudo /usr/bin/profiles -I -F /Library/IT_Staging/Trust_Profile_for_Organization.mobileconfig
sudo /usr/bin/profiles -I -F /Library/IT_Staging/Organization_Enrollment_Profile.mobileconfig

# Delete all staging files.
rm /Library/IT_Staging/*

# Call Deployment Script
./Enroll_Staff.sh

exit 0