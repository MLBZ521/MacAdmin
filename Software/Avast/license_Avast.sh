#!/bin/bash

###################################################################################################
# Script Name:  license_Avast.sh
# By:  Zack Thompson / Created:  6/27/2018
# Version:  1.0.0 / Updated:  6/27/2018 / By:  ZT
#
# Description:  This script will license Avast.
#
###################################################################################################

##################################################
# Define Variables
	scriptDirectory=$(dirname "${0}")
	stageDirectory="/tmp/avastInstaller/config/EDAT"

##################################################
# Bits staged...

# Extract the config.tar file to the location Avast is expecting.
# tar -xv -C "${stageDirectory}/config" -f "${scriptDirectory}/config.tar"

# OR....


if [[ ! -d "${stageDirectory}" ]]; then
	echo "Creating directory structure..."
	/bin/mkdir -p "${stageDirectory}"
fi

# Create 
echo "Creating the EBCF file..."

/bin/cat > "${stageDirectory}/EBCF" <<EOF
[bc]
base=bcons-core.ff.avast.com:80
registrator=http://{}/register
handler=http://{}/handle
install_id=86c2g1v7xvmqqanqqc3nagpj3ax8etn3fc9lxgpunihw78ram4s6lr6s2xpryyhl
use_proxy=0
EOF



# Create 
echo "Creating the EBPK file..."

/bin/cat > "${stageDirectory}/EBPK" <<EOF
-----BEGIN PUBLIC KEY-----
WH8a6zYTQw5+lYJDYTiTiysyNUoFtkE6LkiaJyS2kAi5DWA1ERjeO6XEi5sOpD40
LGY2YZeAJsIc4YHgg4QhTj7Gft4yafa51rzfsNjAMaN0doEnmR8J0eHLQR3NTmwT
bqt9yOb37sLCve4ljYA+ZwqAtqgWxlMtlDrGt1ORumYFmQ15UmsOu6NXTfYt9Lnr
1gkhtkT0SIVbvbDvSCrg1DnOQTHU26Dqq1nTEYywp0Ovgk2vN8vCIbakVHnu5hUq
3gIvXrhhXETkqSUWFOMGH1dE4He0oNo9vlIUF3CNQbeQ+JimGZWD7th9k5w8bJNB
4ab7ibgFGKvVeNGbC7B0cRo7OQRNZ5E4mFvAMHWFjuvo+f0K8anSOcoFind1k6dU
0boxS5Bt
-----END PUBLIC KEY-----
EOF



# Create 
echo "Creating the ECFG file..."

/bin/cat > "${stageDirectory}/ECFG" <<EOF
[Properties]
avastcfg://avast5/Common/SoundsEnabled=0
avastcfg://avast5/Common/SoundsVoiceover=0
avastcfg://avast5/Common/SoundsVirus=0
avastcfg://avast5/Common/SoundsSuspic=0
avastcfg://avast5/Common/SoundsPUP=0
avastcfg://avast5/Common/SoundsScan=0
avastcfg://avast5/Common/SoundsUpdate=0
avastcfg://avast5/Common/SoundsFirewall=0

[OffersCheckboxDefault]
GoogleChrome=0
GoogleToolbar=0
GoogleDrive=0
Dropbox=0

[Groups]
ais_gen_bcc=1
ais_cmp_core=1
ais_cmp_webrep=0


[Options]
silent=0


[Signature]
ASWSig2A6h03hi35vcpvgrv3s1tc7r4f5lbixb2lvbptm27inr3x0lm2zu924lc8miuh0s5892tfil86szgfml4kw475va4h5na4uqb83461lhfwihtkfj1h94u9i3swvywlrxalASWSig2A
EOF



# Create 
echo "Creating the ELIC file..."

/bin/cat > "${stageDirectory}/ELIC" <<EOF
[Certificates]

#
# Customer name (license holder)
#
CustomerName=My Organization

#
# Customer number
#
CustomerNumber=1234567890

#
# Number of licensed products (covered by this file)
#
CertificateCount=1

#
# Section for licensed product 1
#
[Certificate0]

#
# Name of product: Avast business security
#
Feature=AV_MACC


#
# An identifier of a requester
#
LicenseOrigin=AvastBusiness

#
# License creation date: Jun 14 2018, 12:00 AM GMT
#
Issued=1528934400

#
# Update license expiry date: Jul 14 2018, 12:00 AM GMT
#
UpdateValidThru=1531526400

#
# Number of licensed items
#
LicenseCount=1

#
# License Identifier
#
LicenseId=eowugxfr-i111-up7x-ma27-7wxbeullwxhe

#
# Correlation Identifier
#
CorrelationIds=eowugxfr-i111-up7x-ma27-7wxbeullwxhe

#
# License type
#   0 = Standard (Premium)
#   4 = Premium trial
#   13 = Free, unapproved
#   14 = Free, approved
#   16 = Temporary
LicenseType=16

#
# License Family
#
LicenseFamily=AvBusiness

[Signature]
Signature=ASWSig2Aqbs59omoge9gktgpta3s36owkewkmn0btj4m4gg9vh79enn9ruoyaaxnc5darusspotl4i8omexz9mb1ruzrmjiisiiaa2ehdjhwb4q1h82ezgb93bkd94xto4n9jozbd8jw3b0tkjwv66e6ASWSig2A
EOF


echo "All configurations files created!"

exit 0