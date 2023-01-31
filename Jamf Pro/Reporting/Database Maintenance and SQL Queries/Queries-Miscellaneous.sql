-- Queries on Miscellaneous Configurations
-- Most of these should be working, but some may still be a work in progress.
-- These are formatted for readability, just fyi.

-- ##################################################
-- Computer Inventory Submissions

-- Count the number inventory submissions per day per computer
SELECT
	DATE(date_sub(from_unixtime(reports.date_entered_epoch/1000), INTERVAL 1 DAY)) AS "Date",
	computer_id AS "Computer ID",
	COUNT(*) AS "Inventory Reports"
FROM reports
WHERE
	reports.date_entered_epoch > unix_timestamp(date_sub(now(), INTERVAL 1 DAY))*1000
	AND computer_id != 0
GROUP BY DATE(date_sub(from_unixtime(reports.date_entered_epoch/1000), INTERVAL 1 DAY)), computer_id
ORDER BY COUNT(*) DESC


-- Count the number of inventory submissions per day
	DATE(date_sub(from_unixtime(reports.date_entered_epoch/1000), INTERVAL 1 DAY)) AS "Date",
	COUNT(*) AS "Inventory Reports"
FROM reports
WHERE computer_id != 0
GROUP BY DATE(date_sub(from_unixtime(reports.date_entered_epoch/1000), INTERVAL 1 DAY))
ORDER BY DATE(date_sub(from_unixtime(reports.date_entered_epoch/1000), INTERVAL 1 DAY)) DESC


-- Count the number of inventory submissions per day in the last 7 days
SELECT
	DATE(date_sub(from_unixtime(reports.date_entered_epoch/1000), INTERVAL 1 DAY)) AS "Date",
	COUNT(*) AS "Inventory Reports"
FROM reports
WHERE
	reports.date_entered_epoch > unix_timestamp(date_sub(now(), INTERVAL 7 DAY))*1000
	AND computer_id != 0
GROUP BY DATE(date_sub(from_unixtime(reports.date_entered_epoch/1000), INTERVAL 1 DAY))
ORDER BY DATE(date_sub(from_unixtime(reports.date_entered_epoch/1000), INTERVAL 1 DAY)) DESC


-- ##################################################
-- Queries for App Store Apps

-- Mac Apps with No Scope
SELECT DISTINCT
	IF(sites.site_name IS NULL, "none", sites.site_name) AS "Site",
	mac_apps.mac_app_id AS "ID",
	mac_apps.app_name AS "Name"
FROM mac_apps
LEFT JOIN site_objects
	ON mac_apps.mac_app_id = site_objects.object_id
		AND site_objects.object_type = "350"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id
WHERE mac_apps.mac_app_id NOT IN (
	SELECT mac_app_id FROM mac_app_deployment
)
AND mac_apps.deleted = 0;


-- Mac Apps not using VPP Devices Based Licenses
SELECT DISTINCT
	IF(sites.site_name IS NULL, "none", sites.site_name) AS "Site",
	mac_apps.mac_app_id AS "ID",
	mac_apps.app_name AS "Name"
FROM mac_apps
LEFT JOIN site_objects
	ON mac_apps.mac_app_id = site_objects.object_id
		AND site_objects.object_type = "350"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id
WHERE mac_apps.assign_vpp_device_based_licenses = 0
AND mac_apps.deleted = 0;


-- Mobile Device Apps with No Scope
SELECT DISTINCT
	IF(sites.site_name IS NULL, "none", sites.site_name) AS "Site",
	mobile_device_apps.mobile_device_app_id AS "ID",
	mobile_device_apps.app_name AS "Name"
FROM mobile_device_apps
LEFT JOIN site_objects
	ON mobile_device_apps.mobile_device_app_id = site_objects.object_id
		AND site_objects.object_type = "23"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id
WHERE mobile_device_apps.mobile_device_app_id NOT IN (
	SELECT mobile_device_app_id FROM mobile_device_app_deployment
)
AND mobile_device_apps.deleted = 0;


-- Mobile Device Apps not using VPP Devices Based Licenses
SELECT DISTINCT
	IF(sites.site_name IS NULL, "none", sites.site_name) AS "Site",
	mobile_device_apps.mobile_device_app_id AS "ID",
	mobile_device_apps.app_name AS "Name"
FROM mobile_device_apps
LEFT JOIN site_objects
	ON mobile_device_apps.mobile_device_app_id = site_objects.object_id
		AND site_objects.object_type = "23"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id
WHERE mobile_device_apps.assign_vpp_device_based_licenses = 0
AND mobile_device_apps.deleted = 0;


-- ##################################################
-- Queries to check configuration profiles health would likely be useful



-- ##################################################
-- Clean up orphaned records in the log_actions table

-- Get total count
SELECT COUNT(*) FROM log_actions;

-- Get number of orphaned records
SELECT COUNT(*) FROM log_actions
WHERE log_id NOT IN ( SELECT log_id FROM logs );

-- Rename the original table
RENAME TABLE log_actions TO log_actions_original;

-- Create new table like the old table
CREATE TABLE log_actions LIKE log_actions_original;

-- Select the non-orphaned records from the original table
INSERT INTO log_actions
SELECT * FROM log_actions_original
WHERE log_id IN ( SELECT log_id FROM logs );

-- Verify no orphaned records
SELECT COUNT(*) FROM log_actions
WHERE log_id NOT IN ( SELECT log_id FROM logs );


-- ##################################################
-- Clean up orphaned records in the mobile_device_extension_attribute_values table

-- Get total count
SELECT COUNT(*) FROM mobile_device_extension_attribute_values;

-- Get number of orphaned records
SELECT COUNT(*) FROM mobile_device_extension_attribute_values
WHERE report_id NOT IN (
	SELECT report_id FROM reports WHERE mobile_device_id > 0 );

-- Rename the original table
RENAME TABLE mobile_device_extension_attribute_values TO mobile_device_extension_attribute_values_original;

-- Create new table like the old table
CREATE TABLE mobile_device_extension_attribute_values LIKE mobile_device_extension_attribute_values_original;

-- Select the non-orphaned records from the original table
INSERT INTO mobile_device_extension_attribute_values
SELECT * FROM mobile_device_extension_attribute_values_original
WHERE report_id IN (
	SELECT report_id FROM reports WHERE mobile_device_id > 0 );

-- Verify no orphaned records
SELECT COUNT(*) FROM mobile_device_extension_attribute_values
WHERE report_id NOT IN (
	SELECT report_id FROM reports WHERE mobile_device_id > 0 );

-- Get new total count
SELECT COUNT(*) FROM mobile_device_extension_attribute_values;
