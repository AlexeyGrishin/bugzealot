Overview
---------

Bugzealot is a ICQ-bot for Bugzilla. It provides base set of commands and also allows to create your own.

Bugzealot uses Bugzilla XML-RPC API. Also it stores user credentials in CouchDB (to auto-login on next session)
and global command aliases

How to run
----------

1. Install node.js and couchdb (and Bugzilla of course :)). For bugzilla make sure that XML-RPC API works.
2. run ``npm install``
3. configure ICQ account for bugzealot, CouchDB account and bugzilla location in ``config.json``
4. run ``coffee src/bugzealot``

You may run Bugzealot in debug mode with providing following in config.json
```
"icq": {
    "off": true
}
```
in this case you'll be able to work with Bugzealot in commandline.

How to use
-----------

Connect to the ICQ number you've created for Bugzealot and try to type ``help`` command - it shall print out list of all possible commands


Example
------------

```
login username@mail.com qwerty
> OK

get 2
> ...bug N2...

list ProductName CONFIRMED P1
> ...list of bugs...

update 2 assigned_to=another_user
> OK

updateList "P1 UNCONFIRMED" "bug_status=CONFIRMED"
> OK

take 3
> Error: unknown command

alias "take {bug}" "update {bug} assigned_to=@user"
> OK

take 3
> OK
```