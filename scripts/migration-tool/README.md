# Copying Data Between CML Servers

The `virl2-migrate-data.sh` script allows you to copy CML configuration, lab, node, and image data between two CML servers.  Copying can be done "online" whereby the data is copied directly from one system to another; or "offline" where the data is first archived, and then the archive can be transferred to the new system and then extracted.

You can also use this script to migrate between supported CML versions.  The current release supports source servers running CML 2.6.x through 2.10.x and target servers running CML 2.8.x through 2.10.x.  Both online and offline workflows are supported, and the script auto-detects when a version migration (rather than a same-version copy) is required.

The script requires the following:

- The source and target CML servers must be running supported versions (see above).  For a straight data copy without a version change, both servers must be on the *exact same version of CML*.
- The target CML server must have sufficient disk space to copy all of the data from the source CML server (in online operation).
- The source server must have sufficient disk space to hold an archive of all of its data (in offline operation).

## Installation

To perform any data copy or version migration, the `virl2-migrate-data.sh` script needs to be copied to the target (i.e., *new* server).  The best way to transfer the script to a CML server is to place it on an external SFTP or SCP server, and then execute the following from Cockpit's Terminal as root (i.e., after using `sudo -E -s`):

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

> If you are doing an offline copy or version migration, you must copy the script to both the source and target CML servers.

## What Is Copied?

The script copies the following data:

- Labs and the non-volatile and data storage for nodes within the labs
- Custom node definitions
- Custom image definitions
- CML server config including users and groups

Notably, items **not** copied are:

- Licensing (the target server must already have its own license)
- Stock node and image definitions (make sure you either have the same refplat ISO mounted on or contents copied to the target server)
  - **Note:** Version migration *does* copy stock node and image definitions
- Custom bridge interfaces on the Linux side
  - **Note**: The bridge interfaces are copied from a virtualization standpoint, but the underlying bridge-to-physical interface mappings are not

## General Operations

The script itself will handle the shutting down and restarting of CML services on both the source and target servers.  However, it is **strongly** recommended that you shutdown all running labs/nodes on both servers prior to beginning the data copy or version migration.

## Online Copy or Version Migration

To perform an online, server-to-server copy or version migration, on the source server, run the following commands to enable the OpenSSH service:

```bash
sudo systemctl enable sshd
sudo systemctl start sshd
```

Back on the target server, run the following command to initiate the transfer:

```bash
sudo /usr/local/bin/virl2-migrate-data.sh --host <SOURCE CML SERVER IP>
```

Here, `<SOURCE CML SERVER IP>` is the IP address or hostname of the source CML server.  This will prompt you to confirm a few things and do some checks to ensure the migration is most likely to succeed.

When migration completes, you can disable the OpenSSH server on the source server to maintain tight security.  Run the following commands to do so:

```bash
sudo systemctl stop sshd
sudo systemctl disable sshd
```

> **Note:** This is an optional step... If the OpenSSH service was already enabled prior to running the migration tool then it is up to the system administrator whether they want to leave it enabled or disable it at this point.

## Offline Copy or Version Migration

To perform an offline, archive file copy, run the following command on the source server to create an archive of all configuration, lab, node, and image data:

```bash
sudo /usr/local/bin/virl2-migrate-data.sh --backup --file /path/to/archive.tar
```

The same command is used regardless of whether you are doing a same-version data copy or a version migration; the script inspects the source and target CML versions and adjusts its behavior automatically.

You can specify a file path for the archive wherever you have the requisite disk space.  The backup command will perform some source checks and then create this archive tar file.

Once the backup portion completes, transfer this archive file to the target CML server.  How you do this transfer is up to you.  Using an intermediate SFTP or SCP server might be the easiest way.

When the archive file is on the target server, run the following command to restore it (this is the same command for both data copy and version migration):

```bash
sudo /usr/local/bin/virl2-migrate-data.sh --restore --file /path/to/archive.tar
```

The restore command will perform target checks and then prompt you to confirm you want to restore the source data onto this server.

## Updating the Script

If you run the script with the `--update` flag, it will check GitHub to see if a new release is available.  If so, it will download the new script (overwriting itself) and prepare itself for execution.  If there are no updates available, the script will not be touched.  For example:

```bash
/usr/local/bin/virl2-migrate-data.sh --update
```

This step isn't typically required, but if you are running into problems it can be something to try before reporting the problem upstream.

## Caveats

This script is distributed as-is without formal support.  While it has been tested to work, it cannot anticipate all conditions of the source and target CML servers and may not properly copy all data in all cases.  Prior to running the script, you should have a backup of the source CML server (and/or VMware snapshot) just in case something goes wrong.  You should also wait to delete the source server after migration until you have thoroughly tested the target and confirm all functionality is properly working.

If you have renamed the *sysadmin* user, you must pass the `--user` parameter to the migration command when doing online migration/copying.  For example: `--user cmladmin`.

Likewise, if the source CML server's sysadmin SSH service is reachable on a non-default port, pass `--port <port>` (the default is `1122`).  For unattended invocations the script also accepts `--no-confirm` to skip the interactive confirmation prompts.
