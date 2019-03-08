#############################
# Clean up Location History #
#############################

#############################
# Option one, this is what I wanted for my environment:
#   + Remove Empty Location History records
#   + If the record was empty (not assigned any value, besides Building/Department)
#   + Unless it was the latest record


# Backup Database
# Stop Tomcat on all JPS servers

# Create a backup of the table affected tables
create table location_history_backup like location_history;
insert location_history_backup select * from location_history;

create table locations_backup like locations;
insert locations_backup select * from locations;


# Create a table with the empty location records
create table empty_location_records (
    select locations.location_id from locations where ( 
        locations.username = ""
        and locations.realname = ""
        and locations.room = ""
        and locations.phone = ""
        and locations.email = ""
        and locations.position = ""
        and locations.location_id not in ( select location_id from locations inner join computers_denormalized on computers_denormalized.last_location_id = locations.location_id )
    )
);

# Delete empty location records
delete locations_backup from locations_backup where location_id in ( select location_id from empty_location_records );
delete location_history_backup from location_history_backup where location_id in ( select location_id from empty_location_records );


# Start Tomcat on master JPS that is admin facing and verify everything looks good with the modifications performed.

drop table location_history_backup;
drop table locations_backup;
drop table empty_location_records;

# Start Tomcat on all JPS servers


#############################
# Option two, this is the commands Jamf Support provided to erase everything, but the latest record per device.
# I did not take this method as I wanted to keep legitmate history.

# Backup Database
# Stop all Tomcats

# To clear out Location_History information, excluding the most recent data -

create table location_history_new like location_history;

insert into location_history_new
(select * from location_history where computer_id = 0);

insert into location_history_new
(select * from location_history where location_id in (select last_location_id from computers_denormalized));

rename table location_history to location_history_old;

rename table location_history_new to location_history;

drop table location_history_old;


# To clear Locations information, excluding most recent data -

create table locations_new like locations;

insert into locations_new (select * from locations where location_id in (select last_location_id from computers_denormalized));

insert into locations_new (select * from locations where location_id in (select last_location_id from mobile_devices_denormalized));

rename table locations to locations_old;

rename table locations_new to locations;

drop table locations_old;


# Start all Tomcats