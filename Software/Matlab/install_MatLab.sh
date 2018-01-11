#!/bin/sh

###########################################################
# Script Name:  install_MatLab.sh
# By:  Zack Thompson / Created:  3/6/2017
# Version:  1.0 / Updated:  3/6/2017 / By:  ZT
#
# Description:  This script is used to install and activate MatLab with a Network License Server.
#
###########################################################

# Define working directory
cd /tmp/MatLabR2017a

# Install MatLab via built-in script and option file.
./Matlab_2017a_Mac/install -mode silent -inputFile /tmp/MatLabR2017a/installer_input.txt

Echo 'MatLab has been installed!'

exit 0
