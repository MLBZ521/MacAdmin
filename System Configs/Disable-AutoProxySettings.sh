#!/bin/bash

###################################################################################################
# Script Name:  Disable-AutoProxySettings.sh
# By:  Zack Thompson / Created:  3/31/2024
# Version:  1.0.0 / Updated:  3/31/2024 / By:  ZT
#
# Description:  This script disables Auto proxy settings for each network service interface.
#
###################################################################################################

##################################################
# Functions

logger() {

	# Arguments
	# $1 = (str) Message that will be written to a log file
	# $2 = (str) Append time stamp to string; Default:  true
	# $3 = (str) Include a new line before time stamp; Default:  false
	# $4 = (str) Include a new line after string; Default:  true

	local message="${1}"
	local append_time_stamp="${2}"
	local new_line_before="${3}"
	local new_line_after="${4}"
	local time_stamp

	if [[ "${append_time_stamp}" != "false" ]]; then
		time_stamp="$( /bin/date +%Y-%m-%d\ %H:%M:%S ):  "
	fi

	if [[ "${new_line_before}" == "true" ]]; then
		message="\n${time_stamp}${message}"
	fi

	if [[ "${new_line_after}" == "false" ]]; then
		echo -en "${message}"
	else
		echo -e "${message}"
	fi

}

##################################################
# Bits staged...

logger "***** Disable-AutoProxySettings:  START *****"

# Detect network hardware & create services for any newly found interfaces
/usr/sbin/networksetup -detectnewhardware > /dev/null

# Get all available network service interfaces
network_services=$( /usr/sbin/networksetup -listallnetworkservices | /usr/bin/tail +2 )

logger "Checking proxy configurations..." "true" "true"

# Loop through the network service interfaces
while IFS=$'\n' read -r network_service; do

	auto_proxy_config=$( /usr/sbin/networksetup -getautoproxyurl "${network_service}" )
	auto_proxy_discovery=$( /usr/sbin/networksetup -getproxyautodiscovery "${network_service}" )
	auto_proxy_url=$( echo "${auto_proxy_config}" | /usr/bin/awk -F 'URL: ' '{print $2}' | /usr/bin/xargs )

	logger \
		"${network_service} Automatic proxy configuration:\n${auto_proxy_config}\n${auto_proxy_discovery}" \
		"true" "true"

	if [[ -n "${auto_proxy_url}" && "${auto_proxy_url}" != "(null)" ]]; then

		logger "Removing configured proxy address for ${network_service}"
		/usr/sbin/networksetup -setautoproxyurl "${network_service}" " "
		reset_auto_proxy_config_url="true"

	fi

	if [[
		$( echo "${auto_proxy_config}" | /usr/bin/awk -F 'Enabled: ' '{print $2}' | /usr/bin/xargs ) == "Yes"
		|| "${reset_auto_proxy_config_url}" == "true"
	]]; then

		logger "Disabling auto proxy for interface ${network_service}"
		/usr/sbin/networksetup -setautoproxystate "${network_service}" off

	fi

	if [[
		$( echo "${auto_proxy_discovery}" | /usr/bin/awk -F 'Auto Proxy Discovery: ' '{print $2}' | /usr/bin/xargs ) == "On"
	]]; then

		logger "Disabling Auto proxy discovery for ${network_service}"
		/usr/sbin/networksetup -setproxyautodiscovery "${network_service}" off

	fi

done < <(echo "${network_services}")

logger "Checking hosts file definitions..." "true" "true"
hosts_file="/private/etc/hosts"

declare -a add_to_hosts_file
add_to_hosts_file=(
	"255.255.255.255 wpad # WPAD Mitigation" \
	"255.255.255.255 wpad.ad # WPAD Mitigation"
)

# Loop through the host file definitions to add
for add_def in "${add_to_hosts_file[@]}"; do

	if /usr/bin/grep --ignore-case --quiet "${add_def}" "${hosts_file}"; then
		echo "WPAD definition already added to hosts file"
	else
		echo "Adding:  ${add_def}"
		echo "${add_def}" >> "${hosts_file}"
	fi

done

logger "***** Disable-AutoProxySettings:  COMPLETE *****" "true" "true"
exit 0