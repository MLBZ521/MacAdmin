-- #############################
-- # Clean up icons in the JSS #
-- #############################

-- These are notes on performing maintenance on the icons table within the Jamf Pro database.
-- Several of the below actions have been incorporated within my jamf_db_maint.sh script.

-- Resources:  
    -- jaycohen @ https://www.jamf.com/jamf-nation/feature-requests/1474/manage-self-service-policy-icons
    -- Sample queries provided by Jamf Support

-- ####################################################################################################
-- Queries for different icons table "issues"

-- Get total count of icons
SELECT COUNT(*) FROM icons;

-- Count the number of icons where the contents contain "%<!DOCTYPE%"
-- My environment had a lot of these for some reason; they resulted in "broken" images GUI
select count(*) from icons where contents LIKE "%<!DOCTYPE%" ;

-- Get all icons that are assigned to deleted Mobile Device VPP Apps
select distinct count(*) from icons
    inner join mobile_device_apps on mobile_device_apps.icon_attachment_id = icons.icon_id
where mobile_device_apps.deleted is true;

-- Count the number of unused icon_id's
SELECT COUNT(*) FROM icons WHERE icons.icon_id NOT IN
    ( SELECT icon_attachment_id AS id
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
    FROM wallpaper_auto_management_settings
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
    WHERE command='Wallpaper'
UNION ALL
    SELECT branding_icon_id AS id
    FROM self_service
UNION ALL
    SELECT branding_image_id AS id
    FROM self_service
    )

-- Count the number of unused icon_id's that are from VPP Apps
SELECT COUNT(*) FROM icons WHERE icons.icon_id NOT IN
    ( SELECT icon_attachment_id AS id
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
    FROM wallpaper_auto_management_settings
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
    WHERE command='Wallpaper'
UNION ALL
    SELECT branding_icon_id AS id
    FROM self_service
UNION ALL
    SELECT branding_image_id AS id
    FROM self_service
    )
    AND ( icons.filename REGEXP "^([0-9]+x[0-9]+bb|[0-9]+)[.](png|jpg)$");

-- Above regex matches or could be substituded with:
-- AND ( filename IN ( 100x100bb.jpg, 100x100bb.png, 1024x1024bb.png, 512x512bb.png ) OR filename REGEXP "^[0-9]+.(png|jpg)$");

-- ####################################################################################################
--  Creating back ups of the icon tables and similar actions

-- Create a backup of the icon table
create table icons_backup like icons;
insert icons_backup select * from icons;

-- Drop the backup table
drop table icons_backup;

-- Create table of icons that are in use, but not including -1 and 0 IDs
create table icons_ids_inuse (
    icon_Id int(11)
);

insert into icons_ids_inuse select id from icons where icons.icon_id IN 
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
        FROM wallpaper_auto_management_settings
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
        WHERE command='Wallpaper'
    UNION ALL
        SELECT branding_icon_id AS id
        FROM self_service
    UNION ALL
        SELECT branding_image_id AS id
        FROM self_service
    )
    AND id != -1 and id != 0;

-- Create a table with all icon_id and content for all icons in use
create table icons_inuse (
    icon_Id int(11),
    contents longblob
);

insert into icons_inuse
    select distinct icons.icon_id, contents from icons
        inner join icons_ids_inuse on icons_ids_inuse.icon_id = icons.icon_id;

-- Create a table with all icon_id and content that are not being used
create table icons_notinuse (
    icon_Id int(11),
    contents longblob
);

-- insert into icons_notinuse
select distinct icons.icon_id, icons.contents from icons
    where icons.icon_id not in (
        select icon_id from icons_inuse
    );

-- ####################################################################################################
--  Deleting icons, via specific ids, patterns, contents, etc

-- Delete icons by icon_id
delete from icons where icon_id in (
    2, 16, 17, 18, 21, 80, 81, 87, 88
);

-- Get or delete icons between ID numbers
[ select * | delete ] from icons where (
    icon_id between 110 and 293
    or icon_id between 2281 and 2284
    or icon_id between 2314 and 2501
    or icon_id between 2505 and 2579
    or icon_id between 3385 and 4186
    or icon_id between 6776 and 13500 )

-- Delete the icons where the contents contain "%<!DOCTYPE%"
delete from icons where contents LIKE "%<!DOCTYPE%";

-- Get or delete all icons that are assigned to deleted Mobile Device VPP Apps
delete icons from icons
    inner join mobile_device_apps on mobile_device_apps.icon_attachment_id = icons.icon_id
where mobile_device_apps.deleted is true;

-- Delete icons that are not in use, but not specific IDs
delete icons_backup from icons_backup 
    where icons_backup.icon_id not in (
        select icon_id from icon_ids_inuse 
        )
    and 
        icons_backup.icon_id not in (
            6, 14, 41, 89, 108, 484, 2286, 2580, 19513, 19514, 49370, 56529, 57582
           );

-- Delete VPP App Icons not in use
delete icons_backup from icons_backup where icons_backup.icon_id not in ( 
    select icon_id from icon_ids_inuse 
    ) 
    and
        icons_backup.filename in (
            "100x100bb.jpg", "100x100bb.png", "1024x1024bb.png", "512x512bb.png"
            );

-- Delete unused icons' that are from VPP Apps
DELETE FROM icons WHERE icons.icon_id NOT IN
    ( SELECT icon_attachment_id AS id
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
    FROM wallpaper_auto_management_settings
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
    WHERE command='Wallpaper'
UNION ALL
    SELECT branding_icon_id AS id
    FROM self_service
UNION ALL
    SELECT branding_image_id AS id
    FROM self_service
    )
    AND ( icons.filename REGEXP "^([0-9]+x[0-9]+bb|[0-9]+)[.](png|jpg)$");

