#############################
# Clean up icons in the JSS #
#############################

# Resources:  jaycohen @ https://www.jamf.com/jamf-nation/feature-requests/1474/manage-self-service-policy-icons

# Create a backup of the icon table
create table icons_backup like icons;
insert icons_backup select * from icons;

# Clean up icons by deleting all the icons not in use and where the contents contain "%<!DOCTYPE%" (my environment had a lot of these for some reason)
delete from icons where icon_id in ( select distinct icon_id from ( select icon_id from icons ) as iconRef where icon_id not in ( select icon_attachment_id from ibooks union all select icon_attachment_id from mobile_device_apps union all select icon_attachment_id from mobile_device_configuration_profiles union all select icon_attachment_id from mac_apps union all select icon_attachment_id from os_x_configuration_profiles union all select icon_attachment_id from self_service_plugins union all select icon_id from vpp_mobile_device_app_license_app union all select icon_id from wallpaper_auto_management_settings union all select self_service_icon_id from os_x_configuration_profiles union all select self_service_icon_id from patch_policies union all select self_service_icon_id from policies ) and contents LIKE "%<!DOCTYPE%" );

# Delete icons by icon_id
delete from icons where icon_id in (2, 16, 17, 18, 21, 80, 81, 87, 88);

# Get or delete icons between ID numbers and where the contents contain "%<!DOCTYPE%"
[ select * | delete ] from icons where 
( icon_id between 110 and 293
or icon_id between 2281 and 2284
or icon_id between 2314 and 2501
or icon_id between 2505 and 2579
or icon_id between 3385 and 4186
or icon_id between 6776 and 13500 )
and
( contents LIKE "%<!DOCTYPE%" );

# Get all icons that are between IDs that are also assigned to deleted Mobile Device VPP Apps
select distinct * from icons
inner join mobile_device_apps on mobile_device_apps.icon_attachment_id = icons.icon_id
where icons.icon_id in ( select icon_id from icons where icon_id between 2000 and 8000 ) and ( deleted is true );

# Get all icons that are assigned to deleted Mobile Device VPP Apps
select distinct * from icons
inner join mobile_device_apps on mobile_device_apps.icon_attachment_id = icons.icon_id
where deleted is true;

# Drop the backup table
drop table icons_backup;


###########################################################################
# Break down some of the above sub queries into individual queries/tables #
###########################################################################

# Create a table with all icon_id's that are being used
create table icons_ids_inuse (icon_Id int(11));

insert into icons_ids_inuse
select icon_attachment_id
from ibooks union all select icon_attachment_id
from mobile_device_apps union all select icon_attachment_id
from mobile_device_configuration_profiles union all select icon_attachment_id
from mac_apps union all select icon_attachment_id
from os_x_configuration_profiles union all select icon_attachment_id
from self_service_plugins union all select icon_id
from vpp_mobile_device_app_license_app union all select icon_id
from wallpaper_auto_management_settings union all select self_service_icon_id
from os_x_configuration_profiles union all select self_service_icon_id
from patch_policies union all select self_service_icon_id
from policies;

# Create a table with all icon_id and content for all icons in use
create table icons_inuse (icon_Id int(11), contents longblob);

insert into icons_inuse
select distinct icons.icon_id, contents from icons
inner join icons_ids_inuse on icons_ids_inuse.icon_id = icons.icon_id;

# Create a table with all icon_id and content that are not being used
create table icons_notinuse (icon_Id int(11), contents longblob);

insert into icons_notinuse
select distinct icons.icon_id, icons.contents from icons
where icons.icon_id not in (select icon_id from icons_inuse);
