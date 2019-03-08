# Queries on Miscellaneous Configurations
# Most of these should be working, but some may still be a work in progress.
# These are formatted for readability, just fyi.

##################################################
## Printers

# Unused Printers
select distinct printers.printer_id, printers.display_name
from printers 
where printers.printer_id not in ( select printer_id from policy_printers );

# Another Query to check configuration profiles would likely be useful
