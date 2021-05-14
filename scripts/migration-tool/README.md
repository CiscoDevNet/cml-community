# Migrating Data Between CML Servers

The `virl2-migrate-data.sh` script allows you to migrate CML configuration, lab, node, and image data between two CML servers.  Migration can be done "online" whereby the data is copied directly from one system to another; or "offline" where the data is first archived, and then the archive can be transferred to the new system and then extracted.

The script requires the following:

-   Both CML servers must be running the _exact same version of CML_.
-   The target CML server must have sufficient disk space to copy all of the data from the source CML server (in online operation).
-   The source server must have sufficient disk space to hold an archive of all of its data (in offline operation).

## Installation

To perform any migration, the `virl2-migrate-data.sh` script needs to be copied to both servers.  The best way to transfer the script to a CML server is to place it on an external SFTP or SCP server, and then execute the following from Cockpit's Terminal as root (i.e., after using `sudo -E -s`):

SFTP:

```bash
# cd /usr/local/bin
# sftp user@server.example.com
sftp> get virl2-migrate-data.sh
sftp> quit
```

SCP:

```bash
# cd /usr/local/bin
# scp user@server.example.com:virl2-migrate-data.sh ./virl2-migrate-data.sh
```

In both cases, then run the following to make the script executable:

```bash
# chmod +x virl2-migrate-data.sh
```

## What Is Migrated?

The script migrates the following data:

-   Labs and the non-volatile and data storage for nodes within the labs
-   Custom node definitions
-   Custom image definitions
-   CML server config including users and groups

Notably, what is **not** migrated are:

-   Licensing (the target server must already have its own license)
-   Stock node and image definitions (make sure you either have the same refplat ISO mounted on or contents copied to the target server)

## General Operations

The script itself will handle the shutting down and restarting of CML services on both the source and target servers.  However, it is **strongly** recommended that you shutdown all running labs/nodes on both servers prior to beginning migration.

## Online Migration

To perform an online, server-to-server transfer, on the source server, run the following command to enable the OpenSSH service:

```bash
$ sudo /usr/local/bin/virl2-migrate-data.sh --prep
```

Back on the target server, run the following command to initiate the transfer:

```bash
$ sudo /usr/local/bin/virl2-migrate-data.sh --host <SOURCE CML SERVER IP>
```

Here, `<SOURCE CML SERVER IP>` is the IP address or hostname of the source CML server.  This will prompt you to confirm a few things and do some checks to ensure the migration is most likely to succeed.

When migration completes, you can disable the OpenSSH server on the source server to maintain tight security.  Run the following command to do so:

```bash
$ sudo /usr/local/bin/virl2-migrate-data.sh --unprep
```

> **Note:** This is an optional step... If the OpenSSH service was already enabled prior to running the migration tool then it is up to the system administrator whether they want to leave it enabled or disable it at this point.

## Offline Migration

To perform an offline, archive file migration, run the following command on the source server to create an archive of all configuration, lab, node, and image data:

```bash
$ sudo /usr/local/bin/virl2-migrate-data.sh --backup --file /path/to/archive.tar
```

You can specify a file path for the archive where ever you have the requisite disk space.  The backup command will perform some source checks and then create this archive tar file.

Once the backup portion completes, transfer this archive file to the target CML server.  How you do this transfer is up to you.  Using an intermediate SFTP or SCP server might be the easiest way.

When the archive file is on the target server, run the following command to restore it:

```bash
$ sudo /usr/local/bin/virl2-migrate-data.sh --restore --file /path/to/archive.tar
```

The restore command will perform target checks and then prompt you to confirm you want to restore the source data onto this server.

## Caveats

This script is distributed as-is without formal support.  While it has been tested to work, it cannot anticipate all conditions of the source and target CML servers and may not properly migrate all data in all cases.  Prior to running the script, you should have a backup of the source CML server (and/or VMware snapshot) just in case something goes wrong.  You should also wait to delete the source server after migration until you have thoroughly tested the target and confirm all functionality is properly working.
