Wayfare

README

CONTENTS OF THIS FILE
---------------------
01| HOW TO USE THIS DOCUMENT
02| INTRO
03| GETTING STARTED
04| BUILDING
05| INSTALLATION
06| CONFIGURATION
07| MANUAL
08| FAQ
09| PLATFORM NOTES
10| TROUBLESHOOTING
11| KNOWN ISSUES
12| BUG REPORTING
13| FEEDBACK
14| TESTING
15| CONTRIBUTING
16| UPDATING
17| RECENT CHANGES
18| LICENSE
19| LEGAL
20| CREDITS


---01| HOW TO USE THIS DOCUMENT

Prefer to use the website for better and more up-to-date info instead. Otherwise, prefer to use HTML versions as they are hyperlinked.

What is the software about?
See INTRO.

Is it OK for me to use? OK for me to modify? OK to make copies?
See LICENSE for info about the software license.
See LEGAL for any additional info.

How do I get it working?
See GETTING STARTED (after you have it installed and configured) to see how to use.
See BUILDING for how to compile from source.
See INSTALLATION for how to install it on your system (and how to uninstall).
See CONFIGURATION for how you can customize it for your own use.

I cannot make it work, what now?
See TROUBLESHOOTING for dealing with problems with the software.
See PLATFORM NOTES for ensuring it works with your platform/OS.
See MANUAL to make sure you are using it correctly.
See FAQ to see if your question has been answered.
See KNOWN ISSUES to see if your problem is already known about (and any workarounds / advice).
See BUG REPORTING if you want to make a report and get follow-up.

What is in the other sections?
FEEDBACK - Info about things like feature requests.
TESTING - How you can test changes you make to the code.
CONTRIBUTING - How you improve the product for everyone.
UPDATING - How to get the latest changes.
RECENT CHANGES - What the latest changest are.
CREDITS - Third party components used.

---02| INTRO

Wayfare will enable you to add the capability to undo and redo (sqlite) database transactions.

This current version of Wayfare is quite simple and straightforward to use. It features a test table for you to interact with. We also have a short screencast to walk you through usage step-by-step and get up-and-running quickly.
The ability to group transactions together and undo/redo all-at-once as well as the ability to save and restore entire sessions -- these have already been prototyped. You can look forward to their inclusion in a future version!


---03| GETTING STARTED

% package require wayfare
% WayfareNS::ConfigDatabase /path/to/your.db
% WayfareNS::InitializeDatabase
% TestNS::Create FirstEntry
% TestNS::Show
% TestNS::Create SecondEntry
% TestNS::Show
% WayfareNS::Undo
% TestNS::Show
% WayfareNS::Redo
% TestNS::Show
% WayfareNS::Xact1 {DELETE FROM wayfare_test WHERE id = 2}
% qqq {SELECT * FROM wayfare_test}
% WayfareNS::Xact1 {SELECT * FROM wayfare_test}
% WayfareNS::DeletedIdsFor wayfare_test
% WayfareNS::Undo
% WayfareNS::DeletedIdsFor wayfare_test
% TestNS::Show
% WayfareNS::Redo
% TestNS::Show

---04| BUILDING

This is provided as a simple TCL package and does not need to be built.

---05| INSTALLATION

If you are reading this you most likely have already successfully installed.

To install, unzip wayfare.zip in the directory of your choice. That will result in the following files:

README.txt: What you are reading now.
LICENSE.txt: Terms of use and whatnot.
/doc: Any other documents like the manual.
/src: The source code.
/out: The build directory.
You will need to unpack Wayfare in the directory of your choice. The current release of Wayfare requires that TCL be installed. The directory you install Wayfare into will either have to be on the TCL path or you will have to add the directory to the TCL path (your choice). Details are in the INSTALL section of the README.

---06| CONFIGURATION

No configuration necessary to get started or for basic usage.

For options / settings, see MANUAL.txt.

---07| MANUAL

See doc/MANUAL.txt or http://www.robertbrogan.com/wayfare/manual.html.


---08| FAQ

No questions yet.

Please send questions you have to 

wayfare.questions@robertbrogan.com or visit http://www.robertbrogan.com/wayfare/feedback.html.

Also note, you may possibly find the answer to your question in MANUAL, PLATFORM NOTES, TROUBLESHOOTING, or KNOWN ISSUES.

---09| PLATFORM NOTES

The project was developed on Windows Vista using ActiveState ActiveTcl. No platform-specific features are used and it is expected it should run with any TCL interpreter.


---10| TROUBLESHOOTING

No tips at this time.

Also note, you may possibly find help in MANUAL, PLATFORM NOTES, FAQ, or KNOWN ISSUES.

---11| KNOWN ISSUES

None at this time.

For a more up-to-date list, you can visit http://www.robertbrogan.com/wayfare/knownissues.html.

---12| BUG REPORTING

Visit http://www.robertbrogan.com/wayfare/feedback.html. 

Alternatively, send an email to one of:

wayfare.questions@robertbrogan.com
wayfare.comments@robertbrogan.com
wayfare.bugreport@robertbrogan.com
wayfare.wishlist@robertbrogan.com
wayfare.other@robertbrogan.com

and we will try to get back to you ASAP.

---13| FEEDBACK

Visit http://www.robertbrogan.com/wayfare/feedback.html. 

Alternatively, send an email to one of:

wayfare.questions@robertbrogan.com
wayfare.comments@robertbrogan.com
wayfare.bugreport@robertbrogan.com
wayfare.wishlist@robertbrogan.com
wayfare.other@robertbrogan.com

and we will try to get back to you ASAP.

---14| TESTING

Currently, there are no tests.

If and when there are tests, they will be added to a directory called 'test'.

---15| CONTRIBUTING

Nothing formal has been set up for governing this project, yet.

If you like, you may change the code yourself and submit a patch to:

wayfare.bugreport@robertbrogan.com (for bug fixes)
-or-
wayfare.wishlist@robertbrogan.com (for features you implemented)

A roadmap (planned changes) and wishlist (unplanned) are available at:

http://www.robertbrogan.com/wayfare/roadmap.html
http://www.robertbrogan.com/wayfare/wishlist.html

You may want to get involved by submitting wishlist items and/or offering to do work listed in the above two sites. 

---16| UPDATING

The latest version can be found at http://www.robertbrogan.com/wayfare/download.html.

No announcements mechanism has been set up yet. When it is, information for how to subscribe will be put on the above page.

---17| RECENT CHANGES

Initial revision. No changes yet.

---18| LICENSE

See LICENSE.txt

---19| LEGAL

No legal notice at this time (i.e. no use of crypto). See LICENSE.txt for information about the license.

---20| CREDITS

Information posted at wiki.tcl.tk has been helpful throughout work on TCL projects.

