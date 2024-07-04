-- Queries on Miscellaneous Configurations

-- ##################################################
-- Size of the jamfsoftware database
SELECT
    table_schema AS "Database",
    ROUND(SUM(data_length + index_length) / 1024 / 1024 / 1024, 2) AS "Size in GB"
FROM information_schema.TABLES
WHERE table_schema = "jamfsoftware";


-- Get all tables larger than <500MB> in the jamfsoftware database
SELECT
    table_name,
    Round(( ( index_length ) / 1024 / 1024 ), 2) AS "Index Size (MB)",
    Round(( ( data_length + index_length ) / 1024 / 1024 ), 2) AS "Table Size (MB)",
    Round(( data_free / 1024 / 1024 ), 2) AS "Data Free (MB)",
    table_rows
FROM information_schema.tables
WHERE 
    table_schema = "jamfsoftware"
    AND Round(( ( data_length + index_length ) / 1024 / 1024 ), 2) > 500
ORDER BY 3
DESC;


-- ##################################################
-- Custom DB Settings

-- Get currently configured custom Jamf Pro settings
SELECT * FROM jss_custom_settings;


-- Disable icon migration when enabling the Cloud Services in Jamf Pro
INSERT INTO jss_custom_settings
	(settings_key, value) 
	VALUES("com.jamfsoftware.jss.core.ics.migrate.enabled", "false")
;


-- Enable Basic Auth for the Jamf Pro API
INSERT INTO jss_custom_settings
	(settings_key, value) 
	VALUES("com.jamfsoftware.api.security.basicAuthEnabled", "true")
;


-- Fix:  Browser fails to load images in Jamf Pro WebUI due to violating Content Security Policy (CSP)
-- Clear current settings
DELETE FROM jss_custom_settings
WHERE settings_key IN (
	"com.jamfsoftware.http.servlet.response.csp.enforcement.mode",
	"com.jamfsoftware.http.servlet.response.csp.allow.list"
);

-- Enable enforcement mode:
INSERT INTO jss_custom_settings
	(settings_key, value) 
	VALUES("com.jamfsoftware.http.servlet.response.csp.enforcement.mode", "true")
;

INSERT INTO jss_custom_settings
	(settings_key, value) 
	VALUES(
		"com.jamfsoftware.http.servlet.response.csp.allow.list",
		"default-src 'self' 'unsafe-inline' 'unsafe-eval' data: *.jamf.net *.jamf.build *.jamfcloud.com *.jamf.com *.amazonaws.com *.mzstatic.com *.googleapis.com *.gstatic.com *.googletmanager.com *.zoominsoftware.io *.nr-data.net https://js-agent.newrelic.com *.pendo.io *<insert.company.domain>:*; frame-ancestors 'self' *.jamf.net *.jamf.build *.jamfcloud.com app.pendo.io"
	)
;


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
HAVING "Inventory Reports" > 1
ORDER BY "Inventory Reports"
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

-- Mac Apps with
	-- No Scope
	-- (Not) using VPP Devices Based Licenses
SELECT DISTINCT
	IF(sites.site_name IS NULL, "None", sites.site_name) AS "Site",
	mac_apps.mac_app_id AS "ID",
	mac_apps.app_name AS "Name",
	IF(mac_apps.mac_app_id NOT IN (
		SELECT mac_app_id FROM mac_app_deployment
		), "True", "False"
	) AS "No Scope",
	IF(mac_apps.assign_vpp_device_based_licenses = 1, "True", "False") AS "VPP Licenses"
FROM mac_apps
LEFT JOIN site_objects
	ON mac_apps.mac_app_id = site_objects.object_id
		AND site_objects.object_type = "350"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id
WHERE
	mac_apps.deleted = 0
;


-- Mobile Device Apps with
	-- No Scope
	-- (Not) using VPP Devices Based Licenses
SELECT DISTINCT
	IF(sites.site_name IS NULL, "None", sites.site_name) AS "Site",
	mobile_device_apps.mobile_device_app_id AS "ID",
	mobile_device_apps.app_name AS "Name",
	IF(mobile_device_apps.mobile_device_app_id NOT IN (
		SELECT mobile_device_app_id FROM mobile_device_app_deployment
		), "True", "False"
	) AS "No Scope",
	IF(mobile_device_apps.assign_vpp_device_based_licenses = 1, "True", "False") AS "VPP Licenses"
FROM mobile_device_apps
LEFT JOIN site_objects
	ON mobile_device_apps.mobile_device_app_id = site_objects.object_id
		AND site_objects.object_type = "23"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id
WHERE
	mobile_device_apps.deleted = 0
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
	AND username = "<username>"
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


-- ##################################################
-- Get devices with multiple attachments
SELECT 
	object_id AS "JSS ID",
	object_type AS "Device Type",
	attachments.attachment_id AS "Attachment ID",
	filename AS "Filename",
	file_type AS "File Type",
	file_size AS "File Size"
FROM attachments
LEFT OUTER JOIN attachment_assignments
	ON attachment_assignments.attachment_id = attachments.attachment_id
WHERE 
	-- Optionally limit by file type
	-- file_type IN ( "application/zip", "application/octet-stream" )
	-- AND 
	attachments.attachment_id IN (
	SELECT attachment_id
	FROM attachment_assignments 
	WHERE object_id IN (
		SELECT object_id
		FROM attachment_assignments 
		GROUP BY object_id, object_type
		HAVING COUNT(object_id) > 1
	)
)
ORDER BY object_id
;


-- ##################################################
-- Get where a script is used
SELECT policy_id
FROM policy_scripts
WHERE script_id = (
	SELECT scripts.script_id
	FROM scripts
	WHERE scripts.file_name = "<name of script>" 
);
