# Backup Server Tool

This tool is designed to back up one or more servers to a dedicated machine.

## Prerequisites

- At least two Linux machines

Before using the various scripts (backup, restore, and checking the date of the last backup), you need to configure the servers to be backed up.

### Set Up SSH Key Access (root) on the Servers to Be Backed Up

You must have [SSH key access](https://www.cyberciti.biz/faq/how-to-set-up-ssh-keys-on-linux-unix/) configured with the root user on the machine initiating the backups.

### Configure the Backup Settings for the Servers

Duplicate the `./secrets/var.dev.sh` file and rename it to `./secrets/var.sh` to define the backup configuration for the servers.

Next, set the following information:

#### Required Variables on the Backup Server (for each $SERVER to be backed up):

- `NAME`: Server name (Note: this parameter must match the $NAME_CURRENT_SERVER value on the server)
- `IP`: Server's IP address
- `BACKUP_USER`: User to use for the backup (root is recommended to avoid losing file and folder ownership)
- `FOLDER_BACKUP_SOURCE`: Folder to be backed up on the server
- `FOLDER_BACKUP_TARGET`: Destination folder for backups on the backup server (initiating the backup) for the current server
- `FOLDER_BACKUP_GLOBAL`: Parent backup folder (to group backups)
- `FOLDER_BACKUP_PARAMETERS`: Configuration folder
- `NUMBER_OF_DAYS_WITHOUT_WARNING`: Number of days without a backup before receiving notifications

Then, provide the URL of a [Discord webhook](https://support.discord.com/hc/en-us/articles/228383668-Intro-to-Webhooks) to notify the administrator during a backup with the variable `DISCORD_WEBHOOK_URL`.

#### Required Variable Only on the Server to Be Backed Up:

- `NAME_CURRENT_SERVER`: Name of the server to be backed up (the machine's name, which can be equal to $HOST)

## Additional Information

You can run the scripts more easily by creating symbolic links for the scripts in `/usr/bin`:

```bash
sudo ln -s {project-path}/bin/backup.sh /usr/bin/backup
sudo ln -s {project-path}/bin/check-backup-time.sh /usr/bin/check-backup-time
sudo ln -s {project-path}/bin/restore.sh /usr/bin/restore
```

## Using the Scripts

The following 3 scripts are now available:

```bash
# Backup a server (run on the backup server)
sudo backup
# OR
sudo backup ichigo

# Restore a server (run on the backup server)
sudo restore ichigo ichigo ichigo-2023-01-29-22-34-28_1675028068_.tar.gz

# Check the last backup date of the server (run on the server to be backed up)
sudo check-backup-time
```

## Configuring Cron Jobs

It may be useful to run the scripts automatically at regular intervals. Scheduled tasks or cron jobs serve this purpose.

You can configure them on the backup server:

```conf
0 1 * * * root backup
```

And on the server to be backed up:

```conf
0 1 * * * root check-backup-time
```

The tool [Crontab Guru](https://crontab.guru/) can help you configure your cron jobs more easily.

## License

This project is licensed under the GPL License. See the [LICENSE](./LICENSE) file for more details.
