Managing the Java JRE
======

These configuration files are for managing the Java Runtime Environment on client systems.  I used these files and scripts to whitelist websites and Java applets.  This is the macOS version of the [Windows.Software folder](https://github.com/MLBZ521/Windows.Software/tree/master/Managing%20the%20Java%20JRE) of the same title.  The Java Deployment Config files can be found in that folder.


## Scripts ##


#### config_Java.sh ####

Description:  This script installs the Java customizations used by the organization.  (In Windows, I used Group Policy Preferences to copy these files locally; this script was used with a custom package to get these files in place.)  This script also disabled the Java auto-update feature.


#### install_JavaCert.sh ####

Description:  This script imports a certificate into the default Java cacerts keystore.  This certificate was used to sign the DeploymentRuleSet.jar package to whitelist Java applets that are pre-approved.

Note:  (* This has to be applied AFTER every Java update. *)


## JRE Configuration Files ##

See the [Windows.Software folder](https://github.com/MLBZ521/Windows.Software/tree/master/Managing%20the%20Java%20JRE) for copies of these files.

### Source Information ###
* Java 8:  http://docs.oracle.com/javase/8/docs/technotes/guides/deploy/properties.html
* Java 7:  http://docs.oracle.com/javase/7/docs/technotes/guides/jweb/jcp/properties.html


#### deployment.config ####


#### deployment.properties ####


#### exception.sites ####



## Java Deployment Ruleset ##

### Source Information ###
* Java 8:  http://docs.oracle.com/javase/8/docs/technotes/guides/deploy/deployment_rules.html
* Java 7:  http://docs.oracle.com/javase/7/docs/technotes/guides/jweb/security/deployment_rules.html


#### ruleset.xml ####
