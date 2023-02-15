-- Best Practices/Cleanup Reports

-- ##################################################
-- Unused Computer Configuration Profiles
SELECT DISTINCT
	IF(sites.site_name IS NULL, "none", sites.site_name) AS "Site",
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
AND os_x_configuration_profiles.deleted = 0;


-- ##################################################
-- Unused Mobile Device Configuration Profiles
SELECT DISTINCT
	IF(sites.site_name IS NULL, "none", sites.site_name) AS "Site",
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
AND mobile_device_configuration_profiles.deleted = 0;


-- ##################################################
-- Unused Directory Bindings
SELECT DISTINCT
	directory_bindings.directory_binding_id,
	directory_bindings.display_name
FROM directory_bindings
WHERE directory_bindings.directory_binding_id NOT IN (
	SELECT directory_id FROM policy_directory_bindings
);


-- ##################################################
-- Unused Dock Items
SELECT DISTINCT
	dock_items.dock_item_id,
	dock_items.name
FROM dock_items
WHERE dock_items.dock_item_id NOT IN (
	SELECT dock_item_id FROM policy_dock_items
);


-- ##################################################
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


-- ##################################################
-- Unused Printers
SELECT DISTINCT
	printers.printer_id,
	printers.display_name
FROM printers
WHERE printers.printer_id NOT IN (
	SELECT printer_id FROM policy_printers
);


-- ##################################################
-- Unused Scripts
SELECT DISTINCT
	scripts.script_id,
	scripts.file_name
FROM scripts
WHERE scripts.script_id NOT IN (
	SELECT script_id FROM policy_scripts
);


-- ##################################################
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


-- ##################################################
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


-- ##################################################
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


-- ##################################################
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
-- Computer Groups Overview
SELECT DISTINCT
	IF(sites.site_name IS NULL, "none", sites.site_name) AS "Site",
	computer_groups.computer_group_name AS "Name",
	computer_groups.computer_group_id AS "ID",
	IF(computer_groups.is_smart_group = "1", "Yes", "No") AS "Smart Group",
	IF(
		computer_groups.computer_group_id NOT IN (
			SELECT target_id FROM policy_deployment WHERE target_type = 7
				UNION ALL
			SELECT target_id FROM os_x_configuration_profile_deployment WHERE target_type = 7
				UNION ALL
			SELECT target_id FROM restricted_software_deployment WHERE target_type = 7
				UNION ALL
			SELECT target_id FROM mac_app_deployment WHERE target_type = 7
				UNION ALL
			SELECT target_id FROM patch_deployment WHERE target_type = 7
				UNION ALL
			SELECT target_id FROM ibook_deployment WHERE target_type = 7
				UNION ALL
			SELECT target_id FROM self_service_plugin_deployment WHERE target_type = 7
		)
		AND
		computer_groups.computer_group_name NOT IN (
			SELECT criteria FROM smart_computer_group_criteria WHERE search_field = "Computer Group"
		),
	"True", "False") AS "Not Used",
	IF(computer_groups.computer_group_id NOT IN (
		SELECT computer_group_id
		FROM computer_group_memberships
		),
	"True", "False") AS "No Members",
	CASE
		WHEN computer_groups.is_smart_group = "0" THEN "Static"
		WHEN (
			computer_groups.is_smart_group = "1"
			AND computer_groups.computer_group_id NOT IN (
				SELECT computer_group_id
				FROM smart_computer_group_criteria
			)
		) THEN "True"
		Else "False"
	END AS "No Defined Criteria",
	CASE
		WHEN computer_groups.is_smart_group = "0" THEN "Static"
		WHEN (
			computer_groups.computer_group_id IN (
				SELECT computer_group_id
				FROM smart_computer_group_criteria
				GROUP BY computer_group_id
				HAVING COUNT(computer_group_id) > 10
			)
		) THEN "True"
		Else "False"
	END AS "11+ Criteria",
	CASE
		WHEN computer_groups.is_smart_group = "0" THEN "Static"
		WHEN (
			computer_groups.computer_group_id IN (
				SELECT computer_group_id
				FROM smart_computer_group_criteria
				WHERE search_field = "Computer Group"
				GROUP BY computer_group_id
				HAVING COUNT(computer_group_id) > 4
			)
		) THEN "True"
		Else "False"
	END AS "5+ Nested Groups"
FROM computer_groups
LEFT JOIN site_objects
	ON computer_groups.computer_group_id = site_objects.object_id
		AND site_objects.object_type = "7"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id
LEFT JOIN smart_computer_group_criteria
	ON smart_computer_group_criteria.computer_group_id = computer_groups.computer_group_id
;


-- ##################################################
-- Mobile Device Groups Overview
SELECT DISTINCT
	IF(sites.site_name IS NULL, "none", sites.site_name) AS "Site",
	mobile_device_groups.mobile_device_group_name AS "Name",
	mobile_device_groups.mobile_device_group_id AS "ID",
	IF(mobile_device_groups.is_smart_group = "1", "Yes", "No") AS "Smart Group",
	IF(
		mobile_device_groups.mobile_device_group_id NOT IN (
	SELECT target_id FROM mobile_device_configuration_profile_deployment WHERE target_type = 25
		UNION ALL
	SELECT target_id FROM mobile_device_app_deployment WHERE target_type = 25
		UNION ALL
	SELECT target_id FROM ibook_deployment WHERE target_type = 25
		UNION ALL
	SELECT mobile_device_group_id FROM classroom_mobile_device_group
		)
		AND
		mobile_device_groups.mobile_device_group_name NOT IN (
			SELECT criteria FROM smart_mobile_device_group_criteria WHERE search_field = "Mobile Device Group"
		),
	"True", "False") AS "Not Used",
	IF(mobile_device_groups.mobile_device_group_id NOT IN (
		SELECT mobile_device_group_id
		FROM mobile_device_group_memberships
		),
	"True", "False") AS "No Members",

	CASE
		WHEN mobile_device_groups.is_smart_group = "0" THEN "Static"
		WHEN (
			mobile_device_groups.is_smart_group = "1"
			AND mobile_device_groups.mobile_device_group_id NOT IN (
				SELECT mobile_device_group_id
				FROM smart_mobile_device_group_criteria
			)
		) THEN "True"
		Else "False"
	END AS "No Defined Criteria"

	CASE
		WHEN mobile_device_groups.is_smart_group = "0" THEN "Static"
		WHEN (
			mobile_device_groups.mobile_device_group_id IN (
				SELECT mobile_device_group_id
				FROM smart_mobile_device_group_criteria
				GROUP BY mobile_device_group_id
				HAVING COUNT(mobile_device_group_id) > 10
			)
		) THEN "True"
		Else "False"
	END AS "11+ Criteria"
	CASE
		WHEN mobile_device_groups.is_smart_group = "0" THEN "Static"
		WHEN (
			mobile_device_groups.mobile_device_group_id IN (
				SELECT mobile_device_group_id
				FROM smart_mobile_device_group_criteria
				WHERE search_field = "Mobile Device Group"
				GROUP BY mobile_device_group_id
				HAVING COUNT(mobile_device_group_id) > 4
			)
		) THEN "True"
		Else "False"
	END AS "5+ Nested Groups"
FROM mobile_device_groups
LEFT JOIN site_objects
	ON mobile_device_groups.mobile_device_group_id = site_objects.object_id
		AND site_objects.object_type = "25"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id
LEFT JOIN smart_mobile_device_group_criteria
	ON mobile_device_groups.mobile_device_group_id = smart_mobile_device_group_criteria.mobile_device_group_id
;
