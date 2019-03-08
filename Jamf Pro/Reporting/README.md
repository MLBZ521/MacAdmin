jamf.Reporting
======

A collection of workflows, scripts, SQL queries, and notes for reporting on a Jamf environment.

## jamf_Audit.ps1

This script report on a wide varity of configurations in Jamf Pro and output the information into csv files.  These csv files can then be referenced in the `Audit_template.xlsx` file for review.  It is limited to the information that the API can provide.  I hope to provide examples soon.  I do plan to add additional functionality to this as well.

This will provide very similar functionality as [Spruce](https://github.com/sheagcraig/Spruce) and some features of [jss_helper](https://github.com/sheagcraig/jss_helper), both by Shea Craig.

Other reporting tools that I've come across:
  * https://github.com/tmhoule/JSSReport
  * https://github.com/daniel-maclaughlin/Advanced_Computer_Search
  * https://apple.lib.utah.edu/using-the-jamf-pro-api-and-python-to-detect-duplicated-attributes/


## jamf_initialEntry.ps1

This script will report the inital entry date for every device record in Jamf (this is _not_ the last enrollment date, but the very first enrollment date).  Note, if a device's original record was deleted, you will not get that original enroll date, just the new records' enroll date.


## jamf_runReports.ps1

This script will run saved Advanced Searches and output their results to a csv.


## Database Maintenance and SQL Queries

This folder contains various SQL queries that can be used for reporting/auditing directly from the database as well as queries that can be used to clean up specific items in the database (i.e. Application Icons).  Also included are notes on various database tables and values.

