-- Queries on Unused objects
-- These are formatted for readability, just fyi.

-- Additional related queries:
	-- Unused Groups can be found in the file Query-Group Configurations.sql
	-- Unused Icons can be found in the file Queries-Icon Cleanup.sql
	-- Policies with no scope can be found in the file Queries-Policy Configurations.sql
	-- App Store Apps with no scope can be found in the file Queries-Miscellaneous.sql

-- ##################################################

-- Unused Computer Configuration Profiles
SELECT DISTINCT
	IF(sites.site_name IS NULL, "None", sites.site_name) AS "Site",
	os_x_configuration_profiles.os_x_configuration_profile_id AS "ID",
	os_x_configuration_profiles.display_name AS "Name"
FROM os_x_configuration_profiles
LEFT JOIN site_objects
	ON os_x_configuration_profiles.os_x_configuration_profile_id = site_objects.object_id
		AND site_objects.object_type = "4"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id
WHERE
	os_x_configuration_profiles.os_x_configuration_profile_id NOT IN (
		SELECT os_x_configuration_profile_id FROM os_x_configuration_profile_deployment
	)
	AND os_x_configuration_profiles.deleted = 0
;


-- Unused Mobile Device Configuration Profiles
SELECT DISTINCT
	IF(sites.site_name IS NULL, "None", sites.site_name) AS "Site",
	mobile_device_configuration_profiles.mobile_device_configuration_profile_id AS "ID",
	mobile_device_configuration_profiles.display_name AS "Name"
FROM mobile_device_configuration_profiles
LEFT JOIN site_objects
	ON mobile_device_configuration_profiles.mobile_device_configuration_profile_id = site_objects.object_id
		AND site_objects.object_type = "22"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id
WHERE
	mobile_device_configuration_profiles.mobile_device_configuration_profile_id NOT IN (
		SELECT mobile_device_configuration_profile_id FROM mobile_device_configuration_profile_deployment
	)
	AND mobile_device_configuration_profiles.deleted = 0
;


-- Unused Directory Bindings
SELECT DISTINCT
	directory_bindings.directory_binding_id,
	directory_bindings.display_name
FROM directory_bindings
WHERE directory_bindings.directory_binding_id NOT IN (
	SELECT directory_id FROM policy_directory_bindings
);


-- Unused Dock Items
SELECT DISTINCT
	dock_items.dock_item_id,
	dock_items.name
FROM dock_items
WHERE dock_items.dock_item_id NOT IN (
	SELECT dock_item_id FROM policy_dock_items
);


-- Unused Packages
SELECT DISTINCT
	packages.package_id,
	packages.package_name
FROM packages
WHERE packages.package_id NOT IN (
	SELECT package_id FROM policy_packages
	UNION ALL
	SELECT package_id FROM computer_prestage_custom_packages
);


-- Unused Printers
SELECT DISTINCT
	printer_id,
	display_name,
	device_uri,
	location,
	model,
	info,
	notes
FROM printers
WHERE printers.printer_id NOT IN (
	SELECT printer_id FROM policy_printers
);


-- Unused Scripts
SELECT DISTINCT
	scripts.script_id,
	scripts.file_name
FROM scripts
WHERE scripts.script_id NOT IN (
	SELECT script_id FROM policy_scripts
);
