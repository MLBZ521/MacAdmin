-- Queries on Miscellaneous Configurations

-- ##################################################
-- Computer Inventory Submissions

-- Count the number inventory submissions in the last 24 hours per computer.
-- Devices with less than two submissions are ignored.
SELECT
	DATE(date_sub(from_unixtime(reports.date_entered_epoch/1000), INTERVAL 1 DAY)) AS "Date",
	computer_id AS "Computer ID",
	COUNT(*) AS "Inventory Reports"
FROM reports
WHERE
	reports.date_entered_epoch > unix_timestamp(date_sub(NOW(), INTERVAL 1 DAY))*1000
	AND computer_id != 0
GROUP BY
	DATE(date_sub(from_unixtime(reports.date_entered_epoch/1000), INTERVAL 1 DAY)),
	computer_id
HAVING `Inventory Reports` > 1
ORDER BY `Inventory Reports`
DESC;


-- Count the number of inventory submissions per day.
-- Removed dates after data has been flushed (>3 months).
SELECT
	DATE(date_sub(from_unixtime(reports.date_entered_epoch/1000), INTERVAL 1 DAY)) AS "Date",
	COUNT(*) AS "Inventory Reports"
FROM reports
WHERE
	reports.date_entered_epoch > unix_timestamp(date_sub(NOW(), INTERVAL 92 DAY))*1000
	AND computer_id != 0
GROUP BY Date
ORDER BY Date
DESC;


-- Count the number of inventory submissions per day in the last seven days.
-- Same as above, just the previous seven days (Recent view).
SELECT
	DATE(date_sub(from_unixtime(reports.date_entered_epoch/1000), INTERVAL 1 DAY)) AS "Date",
	COUNT(*) AS "Inventory Reports"
FROM reports
WHERE
	reports.date_entered_epoch > unix_timestamp(date_sub(NOW(), INTERVAL 7 DAY))*1000
	AND computer_id != 0
GROUP BY Date
ORDER BY Date
DESC;


-- ##################################################
-- Queries for App Store Apps

-- Mac Apps with No Scope
SELECT DISTINCT
	IF(sites.site_name IS NULL, "None", sites.site_name) AS "Site",
	mac_apps.mac_app_id AS "ID",
	mac_apps.app_name AS "Name"
FROM mac_apps
LEFT JOIN site_objects
	ON mac_apps.mac_app_id = site_objects.object_id
		AND site_objects.object_type = "350"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id
WHERE
	mac_apps.mac_app_id NOT IN (
		SELECT mac_app_id FROM mac_app_deployment
	)
	AND mac_apps.deleted = 0
;


-- Mac Apps not using VPP Devices Based Licenses
SELECT DISTINCT
	IF(sites.site_name IS NULL, "None", sites.site_name) AS "Site",
	mac_apps.mac_app_id AS "ID",
	mac_apps.app_name AS "Name"
FROM mac_apps
LEFT JOIN site_objects
	ON mac_apps.mac_app_id = site_objects.object_id
		AND site_objects.object_type = "350"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id
WHERE
	mac_apps.assign_vpp_device_based_licenses = 0
	AND mac_apps.deleted = 0
;


-- Mobile Device Apps with No Scope
SELECT DISTINCT
	IF(sites.site_name IS NULL, "None", sites.site_name) AS "Site",
	mobile_device_apps.mobile_device_app_id AS "ID",
	mobile_device_apps.app_name AS "Name"
FROM mobile_device_apps
LEFT JOIN site_objects
	ON mobile_device_apps.mobile_device_app_id = site_objects.object_id
		AND site_objects.object_type = "23"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id
WHERE
	mobile_device_apps.mobile_device_app_id NOT IN (
		SELECT mobile_device_app_id FROM mobile_device_app_deployment
	)
	AND mobile_device_apps.deleted = 0
;


-- Mobile Device Apps not using VPP Devices Based Licenses
SELECT DISTINCT
	IF(sites.site_name IS NULL, "None", sites.site_name) AS "Site",
	mobile_device_apps.mobile_device_app_id AS "ID",
	mobile_device_apps.app_name AS "Name"
FROM mobile_device_apps
LEFT JOIN site_objects
	ON mobile_device_apps.mobile_device_app_id = site_objects.object_id
		AND site_objects.object_type = "23"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id
WHERE
	mobile_device_apps.assign_vpp_device_based_licenses = 0
	AND mobile_device_apps.deleted = 0
;


-- ##################################################
-- Authentication enabled on PreStages

SELECT
	COUNT(*) AS "Total PreStages",
	(SELECT COUNT(*) FROM computer_dep_prestages WHERE require_authentication = 1) AS "Authentication Enabled"
FROM computer_dep_prestages;


SELECT
	COUNT(*) AS "Total PreStages",
	(SELECT COUNT(*) FROM mobile_device_prestages WHERE require_authentication = 1) AS "Authentication Enabled"
FROM mobile_device_prestages;


-- ##################################################
-- Last selected Site for the given username

SELECT username, key_pair_name, key_pair_value
FROM user_preferences
WHERE
	key_pair_name = "lastSiteID"
	AND username = "zthomps3"
;



-- ##################################################
-- Get devices with attachments

SELECT
	computers.computer_id,
	IF(sites.site_name IS NULL, "None", sites.site_name) AS "Site",
	computers.computer_name AS "Computer Name",
	computers_denormalized.serial_number AS "Serial Number",
	IF(computers_denormalized.is_managed = 1, "True", "False") AS "Managed",
	attachments.attachment_id,
	filename,
	file_size
FROM computers
LEFT JOIN computers_denormalized
	ON computers_denormalized.computer_id = computers.computer_id
LEFT JOIN site_objects
	ON computers.computer_id = site_objects.object_id
		AND site_objects.object_type = "1"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id
LEFT JOIN attachment_assignments
	ON computers.computer_id = attachment_assignments.object_id
		AND attachment_assignments.object_type = "1"
LEFT JOIN attachments
	ON attachments.attachment_id = attachment_assignments.attachment_id
WHERE
	computers.computer_id IN (
		SELECT object_id FROM attachment_assignments
	)
;

