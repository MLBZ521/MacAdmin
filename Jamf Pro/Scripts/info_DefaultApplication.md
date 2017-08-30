Documentation

So I had a request to set the default Mail application in macOS from another tech.  I did a bit of looking into this and found it was not the easiest thing to do.  There are several third-party 'solutions' out there (see some below).  While some work quite well (specifically most people use dutil), some only did half of what I was wanting to accomplish.  And mostly, I didn't want to have to package these utilities and deploy them, just to perform this task, if I didn't absolutely have too.

This script was [inspired by @thoule & @scheb](https://www.jamf.com/jamf-nation/discussions/15472/set-outlook-2016-as-default-without-having-to-open-mail-app) and [miketaylr@GitHub](https://gist.github.com/miketaylr/5969656).  It will allow you to set the default application for both URL Schemes and Content Types (i.e. File Extensions).  I wrote this for use in a JAMF environment utilizing JSS Script Parameters, but it isn't required obviously and those entries can be manually set. 


Apple Official Documentation on Launch Services

* [Launch Services API Functions](https://developer.apple.com/documentation/coreservices/launch_services)

* [Launch Services Concepts](https://developer.apple.com/library/content/documentation/Carbon/Conceptual/LaunchServicesConcepts/LSCConcepts/LSCConcepts.html)

* [LSRolesMask](https://developer.apple.com/documentation/coreservices/lsrolesmask?language=objc)



Other 'complied' utilities that perform this task as well

* [duti](https://github.com/moretension/duti)

* [defaultapp](http://www.heliumfoot.com/blog/77)

* [LaunchSetter](https://github.com/tmhoule/LaunchSetter)

* [LaunchServices](https://github.com/coruus/launchservices)

* [RCDefaultApp](http://www.rubicode.com/Software/RCDefaultApp/)

* [IC-Switch] - doesn't seem to be mentioned on the developers website anymore, but I was able to find a [link](http://media.flip.macrobyte.net/files/IC-Switch1.5b1.zip) to download it from the dev's site.



Other random mentionings regarding configuring Launch Services

* lsregister: How Files Are Handled in Mac OS X via [krypted.com](http://krypted.com/mac-security/lsregister-associating-file-types-in-mac-os-x/)

* Why is a command line change to ~/Library/Preferences/com.apple.LaunchServices.plist not effective immediately? [AskDifferent@StackExchange](https://apple.stackexchange.com/questions/50004/why-is-a-command-line-change-to-library-preferences-com-apple-launchservices-p)

* Change file association in terminal? @ [AskDifferent@StackExchange](https://apple.stackexchange.com/questions/91522/change-file-association-in-terminal)

* How to change default app for all files of particular file type through terminal in OS X? via [SuperUser@StackExchange](https://superuser.com/questions/273756/how-to-change-default-app-for-all-files-of-particular-file-type-through-terminal)

* How to set default application for specific file types in Mac OS X? via [StackOverflow](https://stackoverflow.com/questions/9172226/how-to-set-default-application-for-specific-file-types-in-mac-os-x)

* Change the default application (for a file extension) via script/command line? via [AskDifferent@StackExchange](https://apple.stackexchange.com/questions/49532/change-the-default-application-for-a-file-extension-via-script-command-line)