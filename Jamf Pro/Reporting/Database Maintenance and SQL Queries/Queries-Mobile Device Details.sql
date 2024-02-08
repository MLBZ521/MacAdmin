-- Queries on Mobile Device Details

-- Total number of Managed Mobile Devices
SELECT count(*) AS "Total Managed Mobile Devices"
FROM mobile_devices_denormalized
WHERE is_managed=1;

-- ##################################################
-- Software Details
SELECT
	mobile_devices.mobile_device_id,
	IF(sites.site_name IS NULL, "None", sites.site_name) AS "Site",
	mobile_devices.display_name AS "Mobile Device Name",
	mobile_devices.serial_number AS "Serial Number",
	mobile_devices.asset_tag AS "PCN",
	mobile_devices_denormalized.os_version AS "Operating System Version",
	mobile_devices_denormalized.os_build AS "Operating System Build",
	CASE
		WHEN mobile_devices_denormalized.model_identifier REGEXP "^(iPod[1-4],[0-9]|iPad1,[0-9]|iPad2,[0-4]|iPhone[1-3],[0-9])$" THEN "Model Not Supported"
		WHEN mobile_devices_denormalized.model_identifier REGEXP "^(iPod5,[0-9]|iPad2,[5-6]|iPad3,[0-9]|iPhone4,[0-9])$" THEN "iOS 9"
		WHEN mobile_devices_denormalized.model_identifier REGEXP "^iPhone5,[0-9]$" THEN "iOS 10"
		WHEN mobile_devices_denormalized.model_identifier REGEXP "^(iPad4,[0-7]|iPhone[6-7],[0-9])$" THEN "iOS 12"
		WHEN mobile_devices_denormalized.model_identifier REGEXP "^(iPod9,[0-9]|iPad4,[8-9]|iPad5,[0-9]|iPhone[8-9],[0-9])$" THEN "iOS 15"
		WHEN mobile_devices_denormalized.model_identifier REGEXP "^(iPad6,[0-9]|iPhone10,[0-9])$" THEN "iOS 16"
		ELSE "iOS 17"
	END AS "Latest Major OS Supported",
	CASE
		WHEN (
			mobile_devices_denormalized.model_identifier REGEXP "^(iPod5,[0-9]|iPad2,[5-6]|iPad3,[0-9]|iPhone4,[0-9])$"
			AND mobile_devices_denormalized.os_version LIKE "9.%"
			OR
				mobile_devices_denormalized.model_identifier REGEXP "^iPhone5,[0-9]$"
				AND mobile_devices_denormalized.os_version LIKE "10.%"
			OR
				mobile_devices_denormalized.model_identifier REGEXP "^(iPad4,[0-7]|iPhone[6-7],[0-9])$"
				AND mobile_devices_denormalized.os_version LIKE "12.%"
			OR
				mobile_devices_denormalized.model_identifier REGEXP "^(iPod9,[0-9]|iPad4,[8-9]|iPad5,[0-9]|iPhone[8-9],[0-9])$"
				AND mobile_devices_denormalized.os_version LIKE "15.%"
			OR
				mobile_devices_denormalized.model_identifier REGEXP "^(iPad6,[0-9]|iPhone10,[0-9])$"
				AND mobile_devices_denormalized.os_version LIKE "17.%"
			OR
				mobile_devices_denormalized.os_version LIKE "17.%"
		) THEN "True"
		ELSE "False"
	END AS "Running Latest Major OS",
	IF(
		mobile_devices_denormalized.last_report_date_epoch = 0, "Never",
		DATE(date_sub(FROM_unixtime(mobile_devices_denormalized.last_report_date_epoch/1000), INTERVAL 1 DAY))
	) AS "Last Inventory Update",
	ea.unit AS "Unit",
	mobile_devices_denormalized.department_name AS "Department",
	ea.internal_department AS "Internal Department",
	mobile_devices_denormalized.realname AS "Assigned User",
	mobile_devices_denormalized.username AS "Username",
	mobile_devices_denormalized.position AS "Position",
	ea.device_type AS "Device Type",
	ea.primary_location AS "Primary Location",
	mobile_devices_denormalized.building_name AS "Building",
	mobile_devices_denormalized.room AS "Room"
FROM mobile_devices
LEFT JOIN mobile_devices_denormalized
	ON mobile_devices_denormalized.mobile_device_id = mobile_devices.mobile_device_id
LEFT JOIN (
		SELECT mobile_device_id, MAX(report_id) AS report_id, MAX(date_entered_epoch) AS date_entered_epoch
		FROM reports
		GROUP BY reports.mobile_device_id
	) AS r
	ON r.mobile_device_id = mobile_devices.mobile_device_id
LEFT JOIN (
		SELECT
			report_id,
			MAX(CASE WHEN mobile_device_extension_attribute_id = 5 THEN value_on_client END) AS "unit",
			MAX(CASE WHEN mobile_device_extension_attribute_id = 3 THEN value_on_client END) AS "device_type",
			MAX(CASE WHEN mobile_device_extension_attribute_id = 4 THEN value_on_client END) AS "internal_department",
			MAX(CASE WHEN mobile_device_extension_attribute_id = 2 THEN value_on_client END) AS "primary_location"
		FROM mobile_device_extension_attribute_values
		WHERE mobile_device_extension_attribute_id in (5, 3, 4, 2)
		GROUP BY report_id
	) AS ea
	ON ea.report_id = r.report_id
LEFT JOIN site_objects
	ON mobile_devices.mobile_device_id = site_objects.object_id
		AND site_objects.object_type = "21"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id
WHERE mobile_devices_denormalized.is_managed = 1
;


-- ##################################################
-- Running latest patch
-- TO DO


-- ##################################################
-- Hardware Details
SELECT
	mobile_devices.mobile_device_id,
	IF(sites.site_name IS NULL, "None", sites.site_name) AS "Site",
	mobile_devices.display_name AS "Mobile Device Name",
	mobile_devices.serial_number AS "Serial Number",
	mobile_devices.asset_tag AS "PCN",
	mobile_devices_denormalized.model AS "Model",
	mobile_devices_denormalized.model_identifier AS "Model Identifier",
	IF(
		mobile_devices_denormalized.warranty_date_epoch = 0, "Unknown",
		DATE(date_sub(FROM_unixtime(mobile_devices_denormalized.warranty_date_epoch/1000), INTERVAL 1 DAY))
	) AS "Warranty Expiration",
	mobile_devices_denormalized.disk_percent_full AS "Storage Percentage Full",
	IF(
		mobile_devices_denormalized.last_report_date_epoch = 0, "Never",
		DATE(date_sub(FROM_unixtime(mobile_devices_denormalized.last_report_date_epoch/1000), INTERVAL 1 DAY))
	) AS "Last Inventory Update"
FROM mobile_devices
LEFT JOIN mobile_devices_denormalized
	ON mobile_devices_denormalized.mobile_device_id = mobile_devices.mobile_device_id
LEFT JOIN site_objects
	ON mobile_devices.mobile_device_id = site_objects.object_id
		AND site_objects.object_type = "21"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id
WHERE mobile_devices_denormalized.is_managed = 1
;


-- Count of each model family
SELECT
    SUM(IF(model LIKE "iPad%", 1, 0)) AS "iPad",
    SUM(IF(model LIKE "iPhone%", 1, 0)) AS "iPhone",
    SUM(IF(model LIKE "iPod%", 1, 0)) AS "iPod",
    SUM(IF(model LIKE "%Apple%TV%", 1, 0)) AS "AppleTV"
FROM mobile_devices_denormalized
WHERE is_managed = 1;


-- Count of individual models
SELECT
	COUNT(*) AS "Total",
	model AS "Model"
FROM mobile_devices_denormalized
WHERE is_managed = 1
GROUP BY model
ORDER BY "Total"
DESC;


-- ##################################################
-- Management Health
SELECT
	mobile_devices.mobile_device_id,
	IF(sites.site_name IS NULL, "None", sites.site_name) AS "Site",
	mobile_devices.display_name AS "Mobile Device Name",
	mobile_devices.serial_number AS "Serial Number",
	mobile_devices.asset_tag AS "PCN",
	IF(mobile_devices.serial_number IS NULL, "True", "False") AS "Missing Serial Number",
	IF(mobile_devices.serial_number IN (
				SELECT serial_number
				FROM mobile_devices
				WHERE mobile_devices_denormalized.is_managed = 1 -- When looking for duplicates, only check against managed records
				GROUP BY serial_number
				HAVING COUNT(serial_number) > 1
			), "True", "False") AS "Duplicate Serial Numbers",
	IF(
		mobile_devices_denormalized.last_report_date_epoch = 0, "Never",
		DATE(date_sub(FROM_unixtime(mobile_devices_denormalized.last_report_date_epoch/1000), INTERVAL 1 DAY))
	) AS "Last Inventory Update",
	DATE(date_sub(FROM_unixtime(mobile_devices_denormalized.last_enrolled_date_epoch/1000), INTERVAL 1 DAY)) AS "Last Enrollment",
	DATE(date_sub(FROM_unixtime(mobile_devices.initial_entry_date_epoch/1000), INTERVAL 1 DAY)) AS "Initial Enrollment",
	DATE(date_sub(FROM_unixtime(mobile_devices_denormalized.device_certificate_expiration/1000), INTERVAL 1 DAY)) AS "Device Certificate Expires",
	IF(mobile_devices_denormalized.mobile_device_id IN (
		SELECT mobile_denorm.mobile_device_id
		FROM mobile_device_management_commands AS mdm_cmds
		LEFT OUTER JOIN mobile_devices_denormalized AS mobile_denorm
			ON mdm_cmds.client_management_id = mobile_denorm.management_id
		LEFT OUTER JOIN mdm_client AS mdm_c
			ON mdm_cmds.client_management_id = mdm_c.management_id
		LEFT JOIN site_objects AS site_objs_mobiles
			ON mobile_denorm.mobile_device_id = site_objs_mobiles.object_id
				AND site_objs_mobiles.object_type = "21"
		LEFT JOIN sites AS sites_mobiles
			ON sites_mobiles.site_id = site_objs_mobiles.site_id
		WHERE
			profile_id = -20
			AND
			apns_result_status = "Error"
			AND
			mdm_c.client_type IN ("MOBILE_DEVICE", "MOBILE_DEVICE_USER", "TV")
		), "True", "False"
	) AS "Failed to Renew MDM Profile",
	IF(mobile_devices_denormalized.is_supervised = 1, "True", "False") AS "Supervised",
	IF(
		mobile_devices_denormalized.declarative_device_management_enabled = 1
		and mobile_devices_denormalized.os_version LIKE "16.%",
		"True", "False"
	) AS "Declarative Device Management",
	IF(mobile_devices.user_removed_mdm_profile = 1, "True", "False") AS "Missing MDM Profile",
	IF(mobile_devices_denormalized.mdm_profile_removable = 1, "True", "False") AS "MDM Profile Is Removable"
FROM mobile_devices
LEFT JOIN mobile_devices_denormalized
	ON mobile_devices_denormalized.mobile_device_id = mobile_devices.mobile_device_id
LEFT JOIN site_objects
	ON mobile_devices.mobile_device_id = site_objects.object_id
		AND site_objects.object_type = "21"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id
WHERE
mobile_devices_denormalized.is_managed = 1
;


-- Mobile Devices that have failed to renew their MDM Profile
-- And the MDM Profile has already expired
--   Remove the last two `AND` conditions to see all failed Renew MDM Profile Commands
SELECT
	mobile_denorm.mobile_device_id AS "Device ID",
	IF(sites_mobiles.site_name IS NOT NULL, sites_mobiles.site_name, "None") AS `Site`,
	IF(mobile_denorm.is_managed = 1, "True", "False") AS "Managed",
	error_code AS "Error Code",
	error_domain AS "Error Domain",
	error_localized_description AS "Localized Error Description"
FROM mobile_device_management_commands AS mdm_cmds
LEFT OUTER JOIN mobile_devices_denormalized AS mobile_denorm
	ON mdm_cmds.client_management_id = mobile_denorm.management_id
LEFT OUTER JOIN mdm_client AS mdm_c
	ON mdm_cmds.client_management_id = mdm_c.management_id
LEFT JOIN site_objects as site_objs_mobiles
	ON mobile_denorm.mobile_device_id = site_objs_mobiles.object_id
		AND site_objs_mobiles.object_type = "21"
LEFT JOIN sites as sites_mobiles
	ON sites_mobiles.site_id = site_objs_mobiles.site_id
WHERE
	profile_id = -20
	AND
	apns_result_status = "Error"
	AND
	mdm_c.client_type IN ("MOBILE_DEVICE", "MOBILE_DEVICE_USER", "TV")
	AND
	mobile_denorm.device_certificate_expiration < UNIX_TIMESTAMP(DATE_ADD(CURDATE(), INTERVAL 180 DAY))*1000
	AND
	mobile_denorm.is_managed = 1
;


-- ##################################################
-- Security
SELECT
	mobile_devices.mobile_device_id,
	IF(sites.site_name IS NULL, "None", sites.site_name) AS "Site",
	mobile_devices.display_name AS "Mobile Device Name",
	mobile_devices.serial_number AS "Serial Number",
	mobile_devices.asset_tag AS "PCN",
	CASE
		WHEN mobile_devices_denormalized.system_integrity_state = 0 THEN "No"
		WHEN mobile_devices_denormalized.system_integrity_state = 1 THEN "Yes"
		WHEN mobile_devices_denormalized.system_integrity_state = -1 THEN "Not Reported"
	END AS "Jailbreak Detected",
	IF(mobile_devices_denormalized.passcode_present = 1, "True", "False") AS "Passcode Set",
	IF(mobile_devices_denormalized.passcode_is_compliant = 1, "True", "False") AS "Passcode Compliant",
	IF(mobile_devices_denormalized.passcode_is_compliant_with_profile = 1, "True", "False") AS "Passcode Compliant with Profile",
	IF(mobile_devices_denormalized.data_protection = 1, "True", "False") AS "Data Protection Enabled"
FROM mobile_devices
LEFT JOIN mobile_devices_denormalized
	ON mobile_devices_denormalized.mobile_device_id = mobile_devices.mobile_device_id
LEFT JOIN site_objects
	ON mobile_devices.mobile_device_id = site_objects.object_id
		AND site_objects.object_type = "21"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id
WHERE mobile_devices_denormalized.is_managed = 1
;


-- ##################################################
-- Mobile Devices that have enrolled <recently> and are not managed
SELECT
	mobile_devices.mobile_device_id,
	IF(sites.site_name IS NULL, "None", sites.site_name) AS "Site",
	mobile_devices.display_name AS "Mobile Device Name",
	mobile_devices.serial_number AS "Serial Number",
	mobile_devices.asset_tag AS "PCN",
	DATE(date_sub(FROM_unixtime(mobile_devices_denormalized.last_enrolled_date_epoch/1000), INTERVAL 1 DAY)) AS "Last Enrollment",
	DATE(date_sub(FROM_unixtime(mobile_devices.initial_entry_date_epoch/1000), INTERVAL 1 DAY)) AS "Initial Enrollment"
FROM mobile_devices
LEFT JOIN site_objects
	ON mobile_devices.mobile_device_id = site_objects.object_id
		AND site_objects.object_type = "21"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id
WHERE
	is_managed = 0 AND
	UNIX_TIMESTAMP(NOW() - INTERVAL 365 DAY)*1000 < last_enrolled_date_epoch
;


-- ##################################################
-- Mobile Devices that are not in a Site
SELECT
	mobile_devices.mobile_device_id,
	mobile_devices.display_name AS "Mobile Device Name",
	mobile_devices.serial_number AS "Serial Number",
	mobile_devices.asset_tag AS "PCN",
	DATE(date_sub(FROM_unixtime(mobile_devices.initial_entry_date_epoch/1000), INTERVAL 1 DAY)) AS "Initial Enrollment",
	DATE(date_sub(FROM_unixtime(mobile_devices_denormalized.last_enrolled_date_epoch/1000), INTERVAL 1 DAY)) AS "Last Enrollment",
	IF(
		mobile_devices_denormalized.last_report_date_epoch = 0, "Never",
		DATE(date_sub(FROM_unixtime(mobile_devices_denormalized.last_report_date_epoch/1000), INTERVAL 1 DAY))
	) AS "Last Inventory Update"
FROM mobile_devices
LEFT JOIN mobile_devices_denormalized
	ON mobile_devices_denormalized.mobile_device_id = mobile_devices.mobile_device_id
LEFT JOIN site_objects
	ON mobile_devices.mobile_device_id = site_objects.object_id
		AND site_objects.object_type = "21"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id
WHERE
	mobile_devices.is_managed = 1 AND
	sites.site_name IS NULL
;
