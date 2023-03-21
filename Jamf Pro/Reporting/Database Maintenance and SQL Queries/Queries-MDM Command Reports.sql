-- MDM Command Reports

-- ##################################################
-- Each MDM Command type and the total of each result/status
SELECT
    command AS "Command",
    COUNT(*) AS "Total",
    SUM(IF(apns_result_status = "", 1, 0)) AS "Pending",
    SUM(IF(apns_result_status = "Error", 1, 0)) AS "Error",
    SUM(IF(apns_result_status = "Acknowledged", 1, 0)) AS "Acknowledged",
    SUM(IF(apns_result_status = "NotNow", 1, 0)) AS "Not Now"
FROM mobile_device_management_commands
GROUP BY command
ORDER BY Total
DESC;


-- ##################################################
-- Count of MDM Commands result/status by client type for the last 24 hours
SELECT
    COUNT(mdm_cmds.apns_result_status) AS "Total",
    mdm_c.client_type AS "Client Type",
    SUM(IF(apns_result_status = "", 1, 0)) AS "Pending",
    SUM(IF(apns_result_status = "Error", 1, 0)) AS "Error",
    SUM(IF(apns_result_status = "Acknowledged", 1, 0)) AS "Acknowledged",
    SUM(IF(apns_result_status = "NotNow", 1, 0)) AS "Not Now"
FROM mobile_device_management_commands AS mdm_cmds
LEFT OUTER JOIN computers_denormalized AS mac_denorm
    ON mdm_cmds.client_management_id = mac_denorm.management_id
LEFT OUTER JOIN computer_user_pushtokens AS cupt
    ON mdm_cmds.client_management_id = cupt.management_id
LEFT OUTER JOIN mobile_devices_denormalized AS mobile_denorm
    ON mdm_cmds.client_management_id = mobile_denorm.management_id
LEFT OUTER JOIN mdm_client AS mdm_c
    ON mdm_cmds.client_management_id = mdm_c.management_id
WHERE
    mdm_cmds.date_completed_epoch > unix_timestamp(date_sub(now(), INTERVAL 24 HOUR))*1000
GROUP BY mdm_c.client_type
ORDER BY COUNT(mdm_cmds.apns_result_status)
DESC;


-- ##################################################
-- Devices being sent numerous MDM Commands
-- Per-device MDM count and details for the last 24 hours where count is greater than five
SELECT
    COUNT(client_management_id) AS "Total",
    mdm_cmds.command AS "Command",
    mdm_cmds.apns_result_status AS "Result",
	CASE
       WHEN (
            mdm_c.client_type in ("COMPUTER", "COMPUTER_USER")
            AND sites_mac.site_name IS NOT NULL
        ) THEN sites_mac.site_name
       WHEN (
            mdm_c.client_type in ("MOBILE_DEVICE", "MOBILE_DEVICE_USER", "TV")
            AND sites_mobile.site_name IS NOT NULL
        ) THEN sites_mobile.site_name
        ELSE "None"
    END AS "Site",
    mdm_c.client_type AS "Client Type",
    CASE
        WHEN mdm_c.client_type = "COMPUTER" THEN mac_denorm.computer_id
        WHEN mdm_c.client_type in ("MOBILE_DEVICE", "TV") THEN mobile_denorm.mobile_device_id
        WHEN mdm_c.client_type = "COMPUTER_USER" THEN cupt.computer_id
        WHEN mdm_c.client_type = "MOBILE_DEVICE_USER" THEN pushtoken.device_management_id
    END AS "Device ID",
    CASE
        WHEN mdm_c.client_type = "COMPUTER_USER" THEN cupt.computer_user_pushtoken_id
        WHEN mdm_c.client_type = "MOBILE_DEVICE_USER" THEN pushtoken.user_short_name
    END AS "User ID",
    mdm_cmds.profile_id AS "ID",
    CASE
        WHEN (
            mdm_c.client_type in ("COMPUTER", "COMPUTER_USER") AND
            mdm_cmds.command REGEXP "^(Install|Remove)Profile$"
        ) THEN mac_cp.display_name
		WHEN (
            mdm_c.client_type in ("MOBILE_DEVICE", "MOBILE_DEVICE_USER", "TV") AND
            mdm_cmds.command REGEXP "^(Install|Remove)Profile$"
        ) THEN mobile_cp.display_name
        WHEN (
            mdm_c.client_type in ("COMPUTER", "COMPUTER_USER") AND
            mdm_cmds.command REGEXP "^(Install|Remove)Application$"
        ) THEN mac_apps.app_name
        WHEN (
            mdm_c.client_type in ("MOBILE_DEVICE", "MOBILE_DEVICE_USER", "TV") AND
            mdm_cmds.command REGEXP "^(Install|Remove)Application$"
        ) THEN mobile_apps.app_name
    END AS "Name"
FROM mobile_device_management_commands AS mdm_cmds
LEFT OUTER JOIN computer_user_pushtokens AS cupt
    ON mdm_cmds.client_management_id = cupt.management_id
LEFT OUTER JOIN computers_denormalized AS mac_denorm
    ON mdm_cmds.client_management_id = mac_denorm.management_id
LEFT OUTER JOIN mobile_devices_denormalized AS mobile_denorm
    ON mdm_cmds.client_management_id = mobile_denorm.management_id
LEFT OUTER JOIN mdm_client AS mdm_c
    ON mdm_cmds.client_management_id = mdm_c.management_id
LEFT OUTER JOIN mobile_user_pushtoken AS pushtoken
    ON mdm_cmds.client_management_id = pushtoken.management_id
LEFT OUTER JOIN os_x_configuration_profiles AS mac_cp
    ON mdm_cmds.profile_udid = mac_cp.payload_identifier
LEFT OUTER JOIN mobile_device_configuration_profiles AS mobile_cp
    ON mdm_cmds.profile_udid = mobile_cp.payload_identifier
LEFT OUTER JOIN mobile_device_apps AS mobile_apps
    ON mdm_cmds.profile_id = mobile_apps.mobile_device_app_id
LEFT OUTER JOIN mac_apps
    ON mdm_cmds.profile_id = mac_apps.mac_app_id
LEFT JOIN site_objects as site_objs_mac
    ON mac_cp.os_x_configuration_profile_id = site_objs_mac.object_id
        AND site_objs_mac.object_type = "4"
LEFT JOIN site_objects as site_objs_mobile
    ON mobile_cp.mobile_device_configuration_profile_id = site_objs_mobile.object_id
        AND site_objs_mobile.object_type = "22"
LEFT JOIN site_objects as site_objs_mac_apps
    ON mac_apps.mac_app_id = site_objs_mac_apps.object_id
        AND site_objs_mac_apps.object_type = "350"
LEFT JOIN site_objects as site_objs_mobile_apps
    ON mobile_apps.mobile_device_app_id = site_objs_mobile_apps.object_id
        AND site_objs_mobile_apps.object_type = "23"
LEFT JOIN sites as sites_mac
    ON sites_mac.site_id = site_objs_mac.site_id
LEFT JOIN sites as sites_mobile
    ON sites_mobile.site_id = site_objs_mobile.site_id
LEFT JOIN sites as sites_mac_apps
    ON sites_mac_apps.site_id = site_objs_mac_apps.site_id
LEFT JOIN sites as sites_mobile_apps
    ON sites_mobile_apps.site_id = site_objs_mobile_apps.site_id
WHERE
    date_completed_epoch > unix_timestamp(date_sub(now(), INTERVAL 24 HOUR))*1000
GROUP BY
    mdm_cmds.apns_result_status,
    mdm_cmds.command,
    mdm_cmds.profile_id,
    mdm_c.client_type,
    cupt.computer_id,
    cupt.computer_user_pushtoken_id,
    pushtoken.device_management_id,
    pushtoken.user_short_name,
    mac_denorm.computer_id,
    mobile_denorm.mobile_device_id,
    mdm_cmds.apns_result_status,
    mdm_cmds.error_localized_description,
    mac_cp.display_name,
    mobile_cp.display_name,
    Site
HAVING COUNT(client_management_id) > 5
ORDER BY COUNT(client_management_id)
DESC;


-- ##################################################
-- MDM Commands that result in an Error
-- Count and results for MDM Commmands that resulted in an Error in last 24 hours
SELECT
    COUNT(mdm_cmds.apns_result_status) AS "Total",
    mdm_cmds.command AS "Command",
    mdm_cmds.error_localized_description AS "Description",
    CASE
       WHEN (
            mdm_c.client_type in ("COMPUTER", "COMPUTER_USER")
            AND sites_mac.site_name IS NOT NULL
        ) THEN sites_mac.site_name
       WHEN (
            mdm_c.client_type in ("MOBILE_DEVICE", "MOBILE_DEVICE_USER", "TV")
            AND sites_mobile.site_name IS NOT NULL
        ) THEN sites_mobile.site_name
        ELSE "None"
    END AS "Site",
    mdm_c.client_type AS "Client Type",
    mdm_cmds.profile_id AS "ID",
    CASE
        WHEN (
            mdm_c.client_type in ("COMPUTER", "COMPUTER_USER") AND
            mdm_cmds.command REGEXP "^(Install|Remove)Profile$"
        ) THEN mac_cp.display_name
		WHEN (
            mdm_c.client_type in ("MOBILE_DEVICE", "MOBILE_DEVICE_USER", "TV") AND
            mdm_cmds.command REGEXP "^(Install|Remove)Profile$"
        ) THEN mobile_cp.display_name
        WHEN (
            mdm_c.client_type in ("COMPUTER", "COMPUTER_USER") AND
            mdm_cmds.command REGEXP "^(Install|Remove)Application$"
        ) THEN mac_apps.app_name
        WHEN (
            mdm_c.client_type in ("MOBILE_DEVICE", "MOBILE_DEVICE_USER", "TV") AND
            mdm_cmds.command REGEXP "^(Install|Remove)Application$"
        ) THEN mobile_apps.app_name
    END AS "Name"
FROM mobile_device_management_commands AS mdm_cmds
LEFT OUTER JOIN computers_denormalized AS mac_denorm
    ON mdm_cmds.client_management_id = mac_denorm.management_id
LEFT OUTER JOIN computer_user_pushtokens AS cupt
    ON mdm_cmds.client_management_id = cupt.management_id
LEFT OUTER JOIN mobile_devices_denormalized AS mobile_denorm
    ON mdm_cmds.client_management_id = mobile_denorm.management_id
LEFT OUTER JOIN mdm_client AS mdm_c
    ON mdm_cmds.client_management_id = mdm_c.management_id
LEFT OUTER JOIN os_x_configuration_profiles AS mac_cp
    ON mdm_cmds.profile_udid = mac_cp.payload_identifier
LEFT OUTER JOIN mobile_device_configuration_profiles AS mobile_cp
    ON mdm_cmds.profile_udid = mobile_cp.payload_identifier
LEFT OUTER JOIN mobile_device_apps AS mobile_apps
    ON mdm_cmds.profile_id = mobile_apps.mobile_device_app_id
LEFT OUTER JOIN mac_apps
    ON mdm_cmds.profile_id = mac_apps.mac_app_id
LEFT JOIN site_objects as site_objs_mac
    ON mac_cp.os_x_configuration_profile_id = site_objs_mac.object_id
        AND site_objs_mac.object_type = "4"
LEFT JOIN site_objects as site_objs_mobile
    ON mobile_cp.mobile_device_configuration_profile_id = site_objs_mobile.object_id
        AND site_objs_mobile.object_type = "22"
LEFT JOIN site_objects as site_objs_mac_apps
    ON mac_apps.mac_app_id = site_objs_mac_apps.object_id
        AND site_objs_mac_apps.object_type = "350"
LEFT JOIN site_objects as site_objs_mobile_apps
    ON mobile_apps.mobile_device_app_id = site_objs_mobile_apps.object_id
        AND site_objs_mobile_apps.object_type = "23"
LEFT JOIN sites as sites_mac
    ON sites_mac.site_id = site_objs_mac.site_id
LEFT JOIN sites as sites_mobile
    ON sites_mobile.site_id = site_objs_mobile.site_id
LEFT JOIN sites as sites_mac_apps
    ON sites_mac_apps.site_id = site_objs_mac_apps.site_id
LEFT JOIN sites as sites_mobile_apps
    ON sites_mobile_apps.site_id = site_objs_mobile_apps.site_id
WHERE
    mdm_cmds.apns_result_status = "Error"
    AND mdm_cmds.date_completed_epoch > unix_timestamp(date_sub(now(), INTERVAL 24 HOUR))*1000
GROUP BY
    mdm_cmds.profile_udid,
    mdm_cmds.profile_id,
    mdm_cmds.command,
    mdm_cmds.apns_result_status,
    mdm_c.client_type,
    mdm_cmds.error_localized_description,
    mac_cp.display_name,
    mobile_cp.display_name,
    Site
ORDER BY COUNT(*)
DESC;


-- ##################################################
-- Looping App installs on devices
-- Count and details on InstallApplication MDM Commands within last 24 hours when count is greater than one
-- Devices looping InstallApplication command (PI-004429)
SELECT
    COUNT(*),
    mdm_cmds.command,
    CASE
       WHEN (
            mdm_c.client_type in ("COMPUTER", "COMPUTER_USER")
            AND sites_mac_apps.site_name IS NOT NULL
        ) THEN sites_mac_apps.site_name
       WHEN (
            mdm_c.client_type in ("MOBILE_DEVICE", "MOBILE_DEVICE_USER", "TV")
            AND sites_mobile_apps.site_name IS NOT NULL
        ) THEN sites_mobile_apps.site_name
        ELSE "None"
    END AS "Site",
    mdm_c.client_type,
    CASE
        WHEN mdm_c.client_type in ("COMPUTER", "COMPUTER_USER") THEN mac_denorm.computer_id
        WHEN mdm_c.client_type in ("MOBILE_DEVICE", "MOBILE_DEVICE_USER", "TV") THEN mobile_denorm.mobile_device_id
    END AS "Device ID",
    mdm_cmds.profile_id AS "app id",
    CASE
        WHEN (
            mdm_c.client_type in ("COMPUTER", "COMPUTER_USER") AND
            mdm_cmds.command REGEXP "^(Install|Remove)Application$"
        ) THEN mac_apps.app_name
        WHEN (
            mdm_c.client_type in ("MOBILE_DEVICE", "MOBILE_DEVICE_USER", "TV") AND
            mdm_cmds.command REGEXP "^(Install|Remove)Application$"
        ) THEN mobile_apps.app_name
    END AS "Name",
    mdm_cmds.apns_result_status AS "Result",
    mdm_cmds.error_localized_description AS "Description"
FROM mobile_device_management_commands AS mdm_cmds
LEFT OUTER JOIN computers_denormalized AS mac_denorm
    ON mdm_cmds.client_management_id = mac_denorm.management_id
LEFT OUTER JOIN computer_user_pushtokens AS cupt
    ON mdm_cmds.client_management_id = cupt.management_id
LEFT OUTER JOIN mobile_devices_denormalized AS mobile_denorm
    ON mdm_cmds.client_management_id = mobile_denorm.management_id
LEFT OUTER JOIN mdm_client AS mdm_c
    ON mdm_cmds.client_management_id = mdm_c.management_id
LEFT OUTER JOIN mobile_device_apps AS mobile_apps
    ON mdm_cmds.profile_id = mobile_apps.mobile_device_app_id
LEFT OUTER JOIN mac_apps
    ON mdm_cmds.profile_id = mac_apps.mac_app_id
LEFT JOIN site_objects as site_objs_mac_apps
    ON mac_apps.mac_app_id = site_objs_mac_apps.object_id
        AND site_objs_mac_apps.object_type = "350"
LEFT JOIN site_objects as site_objs_mobile_apps
    ON mobile_apps.mobile_device_app_id = site_objs_mobile_apps.object_id
        AND site_objs_mobile_apps.object_type = "23"
LEFT JOIN sites as sites_mac_apps
    ON sites_mac_apps.site_id = site_objs_mac_apps.site_id
LEFT JOIN sites as sites_mobile_apps
    ON sites_mobile_apps.site_id = site_objs_mobile_apps.site_id
WHERE
    mdm_cmds.command = "InstallApplication"
    AND mdm_cmds.date_completed_epoch > unix_timestamp(date_sub(now(), INTERVAL 24 HOUR))*1000
GROUP BY
    mdm_c.client_type,
    mdm_cmds.profile_id,
    mobile_denorm.mobile_device_id,
    mac_denorm.computer_id,
    mdm_cmds.apns_result_status,
    mdm_cmds.error_localized_description,
    Site
HAVING COUNT(*) > 1
ORDER BY COUNT(*)
DESC;


-- ##################################################
-- Check if a Config Profile is being pushed to a device multiple times within thirty days

SELECT
    COUNT(*) AS "Total",
    IF(sites.site_name IS NULL, "None", sites.site_name) AS "Site",
    computers_denormalized.computer_id AS "Computer ID",
    -- os_x_installed_configuration_profiles.username,
    computer_name AS "Computer Name",
    os_x_configuration_profile_id AS "Configuration Profile ID",
    display_name AS "Configuration Profile Name"
    -- last_install_epoch
FROM os_x_installed_configuration_profiles
LEFT OUTER JOIN computers_denormalized
    ON os_x_installed_configuration_profiles.computer_id = computers_denormalized.computer_id
LEFT JOIN site_objects
    ON os_x_installed_configuration_profiles.os_x_configuration_profile_id = site_objects.object_id
        AND site_objects.object_type = "4"
LEFT JOIN sites
    ON sites.site_id = site_objects.site_id
WHERE
    last_install_epoch > unix_timestamp(date_sub(now(), INTERVAL 24 HOUR))*1000
GROUP BY
    computers_denormalized.computer_id,
    -- os_x_installed_configuration_profiles.username,
    os_x_configuration_profile_id,
    display_name,
    -- last_install_epoch
    Site
HAVING COUNT(*) > 1
ORDER BY COUNT(*)
DESC;
