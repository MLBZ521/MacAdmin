-- #############################
-- # Clean up icons in the JSS #
-- #############################

-- These are notes on performing maintenance on the icons table within the Jamf Pro database.
-- Several of the below actions have been incorporated within my jamf_db_maint.sh script.

-- Resources:
	-- jaycohen @ https://www.jamf.com/jamf-nation/feature-requests/1474/manage-self-service-policy-icons
	-- Sample queries originally provided by Jamf Support and have been modified as needed

-- ####################################################################################################
-- Queries for different icons table "issues"

-- Get total count of icons
SELECT COUNT(*) FROM icons;

-- Count the number of icons where the contents contain "%<!DOCTYPE%"
-- My environment had a lot of these for some reason; they resulted in "broken" images in the GUI
SELECT COUNT(*) FROM icons WHERE contents LIKE "%<!DOCTYPE%";

-- Get all icons that are assigned to deleted Mobile Device VPP Apps
SELECT DISTINCT COUNT(*) FROM icons
	INNER JOIN mobile_device_apps ON mobile_device_apps.icon_attachment_id = icons.icon_id
WHERE mobile_device_apps.deleted IS true;

-- Count the number of unused icon_id"s
SELECT COUNT(*) FROM icons WHERE icons.icon_id NOT IN (
	SELECT icon_attachment_id AS id
	FROM ibooks
UNION ALL
	SELECT icon_attachment_id AS id
	FROM mobile_device_apps
UNION ALL
	SELECT icon_attachment_id AS id
	FROM mobile_device_configuration_profiles
UNION ALL
	SELECT icon_attachment_id AS id
	FROM mac_apps
UNION ALL
	SELECT icon_attachment_id AS id
	FROM os_x_configuration_profiles
UNION ALL
	SELECT icon_attachment_id AS id
	FROM self_service_plugins
UNION ALL
	SELECT icon_id AS id
	FROM vpp_mobile_device_app_license_app
UNION ALL
	SELECT icon_id AS id
	FROM vpp_assets
UNION ALL
	SELECT self_service_icon_id AS id
	FROM os_x_configuration_profiles
UNION ALL
	SELECT self_service_icon_id AS id
	FROM patch_policies
UNION ALL
	SELECT self_service_icon_id AS id
	FROM policies
UNION ALL
	SELECT profile_id AS id
	FROM mobile_device_management_commands
	WHERE command="Wallpaper"
UNION ALL
	SELECT deprecated_branding_icon_id AS id
	FROM self_service
UNION ALL
	SELECT deprecated_branding_image_id AS id
	FROM self_service
UNION ALL
	SELECT icon_id AS id
	FROM ss_ios_branding_settings
UNION ALL
	SELECT icon_id AS id
	FROM ss_macos_branding_settings
);

-- Count the number of unused icon_id's that are from VPP Apps
SELECT COUNT(*) FROM icons WHERE icons.icon_id NOT IN (
	SELECT icon_attachment_id AS id
	FROM ibooks
UNION ALL
	SELECT icon_attachment_id AS id
	FROM mobile_device_apps
UNION ALL
	SELECT icon_attachment_id AS id
	FROM mobile_device_configuration_profiles
UNION ALL
	SELECT icon_attachment_id AS id
	FROM mac_apps
UNION ALL
	SELECT icon_attachment_id AS id
	FROM os_x_configuration_profiles
UNION ALL
	SELECT icon_attachment_id AS id
	FROM self_service_plugins
UNION ALL
	SELECT icon_id AS id
	FROM vpp_mobile_device_app_license_app
UNION ALL
	SELECT icon_id AS id
	FROM vpp_assets
UNION ALL
	SELECT self_service_icon_id AS id
	FROM os_x_configuration_profiles
UNION ALL
	SELECT self_service_icon_id AS id
	FROM patch_policies
UNION ALL
	SELECT self_service_icon_id AS id
	FROM policies
UNION ALL
	SELECT profile_id AS id
	FROM mobile_device_management_commands
	WHERE command="Wallpaper"
UNION ALL
	SELECT deprecated_branding_icon_id AS id
	FROM self_service
UNION ALL
	SELECT deprecated_branding_image_id AS id
	FROM self_service
UNION ALL
	SELECT icon_id AS id
	FROM ss_ios_branding_settings
UNION ALL
	SELECT icon_id AS id
	FROM ss_macos_branding_settings
)
AND ( icons.filename REGEXP "^([0-9]+x[0-9]+bb|[0-9]+)[.](png|jpg)$");

-- Above regex matches or could be substituded with:
-- AND ( filename IN ( 100x100bb.jpg, 100x100bb.png, 1024x1024bb.png, 512x512bb.png ) OR filename REGEXP "^[0-9]+.(png|jpg)$");

-- ####################################################################################################
--  Creating back ups of the icon tables and similar actions

-- Create a backup of the icon table
CREATE TABLE icons_backup LIKE icons;
INSERT icons_backup SELECT * FROM icons;

-- Drop the backup table
DROP TABLE icons_backup;

-- Create table of icons that are in use, but not including -1 and 0 IDs
CREATE TABLE icons_ids_inuse (
	icon_Id int(11)
);

INSERT INTO icons_ids_inuse SELECT id FROM icons WHERE icons.icon_id IN
	(
		SELECT icon_attachment_id AS id
		FROM ibooks
	UNION ALL
		SELECT icon_attachment_id AS id
		FROM mobile_device_apps
	UNION ALL
		SELECT icon_attachment_id AS id
		FROM mobile_device_configuration_profiles
	UNION ALL
		SELECT icon_attachment_id AS id
		FROM mac_apps
	UNION ALL
		SELECT icon_attachment_id AS id
		FROM os_x_configuration_profiles
	UNION ALL
		SELECT icon_attachment_id AS id
		FROM self_service_plugins
	UNION ALL
		SELECT icon_id AS id
		FROM vpp_mobile_device_app_license_app
	UNION ALL
		SELECT icon_id AS id
		FROM vpp_assets
	UNION ALL
		SELECT self_service_icon_id AS id
		FROM os_x_configuration_profiles
	UNION ALL
		SELECT self_service_icon_id AS id
		FROM patch_policies
	UNION ALL
		SELECT self_service_icon_id AS id
		FROM policies
	UNION ALL
		SELECT profile_id AS id
		FROM mobile_device_management_commands
		WHERE command="Wallpaper"
	UNION ALL
		SELECT deprecated_branding_icon_id AS id
		FROM self_service
	UNION ALL
		SELECT deprecated_branding_image_id AS id
		FROM self_service
	UNION ALL
		SELECT icon_id AS id
		FROM ss_ios_branding_settings
	UNION ALL
		SELECT icon_id AS id
		FROM ss_macos_branding_settings
)
AND id != -1 AND id != 0;

-- Create a table with all icon_id and content for all icons in use
CREATE TABLE icons_inuse (
	icon_Id int(11),
	contents longblob
);

INSERT INTO icons_inuse
SELECT DISTINCT icons.icon_id, contents FROM icons
	INNER JOIN icons_ids_inuse ON icons_ids_inuse.icon_id = icons.icon_id;

-- Create a table with all icon_id and content that are not being used
CREATE TABLE icons_notinuse (
	icon_Id int(11),
	contents longblob
);

-- Insert into icons_notinuse
SELECT DISTINCT icons.icon_id, icons.contents FROM icons
WHERE icons.icon_id NOT IN (
	SELECT icon_id FROM icons_inuse
);

-- ####################################################################################################
--  Deleting icons, via specific ids, patterns, contents, etc

-- Delete icons by icon_id
DELETE FROM icons WHERE icon_id IN (
	2, 16, 17, 18, 21, 80, 81, 87, 88
);

-- Get or delete icons between ID numbers
[ SELECT * | DELETE ] FROM icons WHERE (
	icon_id BETWEEN 110 AND 293
	OR icon_id BETWEEN 2281 AND 2284
	OR icon_id BETWEEN 2314 AND 2501
	OR icon_id BETWEEN 2505 AND 2579
	OR icon_id BETWEEN 3385 AND 4186
	OR icon_id BETWEEN 6776 AND 13500 );

-- Delete the icons where the contents contain "%<!DOCTYPE%"
DELETE FROM icons WHERE contents LIKE "%<!DOCTYPE%";

-- Get or delete all icons that are assigned to deleted Mobile Device VPP Apps
DELETE icons FROM icons
	INNER JOIN mobile_device_apps ON mobile_device_apps.icon_attachment_id = icons.icon_id
WHERE mobile_device_apps.deleted IS true;

-- Delete icons that are not in use, but not specific IDs
DELETE icons_backup
FROM icons_backup
WHERE icons_backup.icon_id NOT IN (
	SELECT icon_id FROM icon_ids_inuse
)
AND icons_backup.icon_id NOT IN (
	6, 14, 41, 89, 108, 484, 2286, 2580, 19513, 19514, 49370, 56529, 57582
);

-- Delete VPP App Icons not in use
DELETE icons_backup
FROM icons_backup
WHERE icons_backup.icon_id NOT IN (
	SELECT icon_id FROM icon_ids_inuse
)
AND icons_backup.filename IN (
	"100x100bb.jpg", "100x100bb.png", "1024x1024bb.png", "512x512bb.png"
);

-- Delete unused icons' that are from VPP Apps
DELETE FROM icons WHERE icons.icon_id NOT IN (
	SELECT icon_attachment_id AS id
	FROM ibooks
UNION ALL
	SELECT icon_attachment_id AS id
	FROM mobile_device_apps
UNION ALL
	SELECT icon_attachment_id AS id
	FROM mobile_device_configuration_profiles
UNION ALL
	SELECT icon_attachment_id AS id
	FROM mac_apps
UNION ALL
	SELECT icon_attachment_id AS id
	FROM os_x_configuration_profiles
UNION ALL
	SELECT icon_attachment_id AS id
	FROM self_service_plugins
UNION ALL
	SELECT icon_id AS id
	FROM vpp_mobile_device_app_license_app
UNION ALL
	SELECT icon_id AS id
	FROM vpp_assets
UNION ALL
	SELECT self_service_icon_id AS id
	FROM os_x_configuration_profiles
UNION ALL
	SELECT self_service_icon_id AS id
	FROM patch_policies
UNION ALL
	SELECT self_service_icon_id AS id
	FROM policies
UNION ALL
	SELECT profile_id AS id
	FROM mobile_device_management_commands
	WHERE command="Wallpaper"
UNION ALL
	SELECT deprecated_branding_icon_id AS id
	FROM self_service
UNION ALL
	SELECT deprecated_branding_image_id AS id
	FROM self_service
UNION ALL
	SELECT icon_id AS id
	FROM ss_ios_branding_settings
UNION ALL
	SELECT icon_id AS id
	FROM ss_macos_branding_settings
)
AND ( icons.filename REGEXP "^([0-9]+x[0-9]+bb|[0-9]+)[.](png|jpg)$");

