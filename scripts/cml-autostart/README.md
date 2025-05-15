# README

This script adds lab autostart capability to CML.  It's implemented in a very simple way without any additional dependencies to install. 

> [!WARNING]
>
> It's important to understand that this mechanism is very simple and also very insecure. You need to provide a password for a user of the system in clear text as part of the configuration. If you are not comfortable to provide a password that is stored in clear text on the server, then this solution is not for you. Also, if the system uses external authentication via LDAP, then this solution is likely not for you.

## How it works

The autostart script basically looks at all labs that the user has access to (users with admin rights will see all labs, the script passes the "show_all" flag so if a non-admin user runs this, they will see all labs they have access to).

Credentials and the regular expression is configured in a central configuration file `/etc/default/cml-autostart`.

A lab that has "(autostart)" in the lab description will be started when the system comes up and is ready.

The string that triggers the autostart is configured in the file mentioned above. It is treated as a regular expression.

## Installation

Simply copy the `autostart.sh` script to the CML server. Either via scp or simply copying/pasting it into a file on the CML server (for example, via the Cockpit terminal). From there, run the script which then installs it:

```bash
$ sudo bash ./autostart.sh
installing defaults     ✅
installing script       ✅
installing service unit ✅
******************************************************************************
* IMPORTANT!                                                                 *
* you need to ensure that you change the username and password for a user of *
* the system that can start the labs.                                        *
*                                                                            *
* Every lab that has the string configured in the lab description which is   *
* defined in the default will be started by the script.                      *
*                                                                            *
* The default is "(autostart)".                                              *
*                                                                            *
* /etc/default/cml-autostart                                                 *
******************************************************************************
$
```

Then configure the defaults (e.g. change the password) as outlined in the next section.

## Configuration

The defaults are

```bash
USERNAME="admin"
PASSWORD="password-that-needs-to-be-changed"
TITLE_REGEX="\(autostart\)"
```

After installation, at least the password needs to be changed.

## Verification

If labs do not start as expected, check the service unit output… If that's not sufficient, then enable debugging in the script by removing the comment in the `/usr/local/bin/cml-autostart.sh` line that says `# set -x`. 

```bash
sudo journalctl -u cml-autostart.service
```

Check the service unit status:

```bash
sudo systemctl status cml-autostart.service
```

