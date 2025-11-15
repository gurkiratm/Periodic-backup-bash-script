# Periodic-backup-bash-script

A simple Bash backup helper that creates tarball and directory backups and synchronizes them to a remote host using `rsync` + SSH. The script also installs cron jobs (under `/etc/cron.d`) to run tarball and directory backups on a schedule.

**Intended host:** Linux systems with Bash and `rsync` installed (run as `root` or with sufficient privileges to read listed paths and write cron files).

## Working Snapshots

***Backup files at Remote server***

<img width="367" height="315" alt="{CA41F5C1-3697-4B2B-8AD1-C237B0D28031}" src="https://github.com/user-attachments/assets/a1aa84b6-2e05-44ba-8b47-2fc3f1bc513a" />


***Log File output***
<img width="1106" height="524" alt="{4A2BA28C-250C-4A99-A923-154FBE77D4B0}" src="https://github.com/user-attachments/assets/20f956fc-ac70-4c12-a3aa-b1e56ba69343" />


---

**Quick Summary:**
- Tarball mode: run the script with the `tarball` argument to create a compressed tarball of configured paths and push it to the remote `rsync` location.
- Directories mode: run the script with the `directories` argument to sync the specified paths (preserving structure) to the remote host.
- Running the script without `tarball`/`directories` will still ensure the cron jobs are present (it writes files under `/etc/cron.d`).

## Requirements
- Bash 
- `rsync` installed and available on `PATH`
- SSH pubic key configured on the remote host (the script creates a temporary SSH private key file by default)
- Permissions to write to `/etc/cron.d` (to install cron jobs)

## Configuration (in the script)
Open the script and update these variables to suit your environment:

- `bpaths` — array of files/directories to include in backups. Example entries are already present; remove or add entries as needed.
- `rsync_path` — remote rsync path in the form `<user>@<host>:<remote_backup_path>` (replace placeholders).
- `cron_schedule_tar` — cron schedule for tarball backups (default: `0 1 * * 6` = 01:00 on Saturday).
- `cron_schedule_dir` — cron schedule for directory syncs (default: `0 2 * * *` = 02:00 every day).
- `base_path` — base working directory where temporary tarball, log, and SSH key are placed (defaults to `$HOME`).
- `ssh_key` — path used by the script to write a temporary SSH private key. By default it is `$base_path/sshkey`.

### SSH key placement
- The corresponding *public* key (the `.pub` file contents) must be appended to the remote user's `~/.ssh/authorized_keys` on the remote server so passwordless SSH from the backup host is allowed. Example on the remote server:

```bash
# on remote host, as the backup-receiving user
mkdir -p ~/.ssh && chmod 700 ~/.ssh
echo 'ssh-rsa AAAA... your-public-key ... user@host' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

## Usage
From a shell on the machine hosting the files to backup:

```bash
# Create a tarball of the configured paths and rsync it to the remote host
sudo bash /path/to/backup_script.sh tarball

# Sync directories (preserve structure) to the remote host
sudo bash /path/to/backup_script.sh directories

# Run without args to ensure cron jobs are installed
sudo bash /path/to/backup_script.sh
```

Notes:
- The script checks each `bpaths` entry and only includes existing files/dirs.
- On `tarball` the script creates a gzipped tarball named like `<hostname>_dYYYYMMDD_tHHMMSS_bkp.tar.gz` under `base_path`.
- `rsync` calls use an SSH key configured at `ssh_key` and will transfer the created tarball and logs to the remote `rsync_path/$(hostname)/`.

## Cron Installation
The script will create or update these files under `/etc/cron.d`:
- `/etc/cron.d/backup_script_tarball` — contains the cron entry for tarball backups.
- `/etc/cron.d/backup_script_directories` — contains the cron entry for directory syncs.

Each cron line includes the schedule, the user (script uses `$USER`), the script path, and the argument (`tarball` or `directories`). If you prefer to manage cron yourself, you can comment out that section in the script and create your own cron entries.

Example cron line written to `/etc/cron.d/backup_script_tarball` (fields: schedule user command arg):

```
0 1 * * 6 root /path/to/backup_script.sh tarball
```

## Logging
- The script writes stdout/stderr to `logfile` (default: `$HOME/$(hostname)_backup.log`).
- After run it attempts to rsync the log file(s) to the remote host as well.

## Troubleshooting
- "Please install rsync": install `rsync` (e.g., `apt install rsync` or `yum install rsync`).
- Paths not found: verify each entry in `bpaths` exists and has readable permissions.
- Permission denied writing to `/etc/cron.d`: run as root or use proper privilege escalation.
- SSH/rsync failures: verify `rsync_path`, network connectivity, SSH keys, and remote directory permissions.
- SELinux/AppArmor may prevent writes or execution — check `audit.log` or disable enforcement for testing.

## Where files are written/what the script modifies
- Temporary tarballs/logs/sshkey: default under `$HOME` (or `base_path` if changed).
- Cron files: `/etc/cron.d/backup_script_tarball` and `/etc/cron.d/backup_script_directories`.

## Remote cleanup (recommended)
To avoid backup files accumulating on the remote host you can schedule a cleanup job on the remote server that removes older backups. Example (run as the remote backup-receiving account):

```
/usr/bin/find /var/images/ipse/ -name "*_bkp.tar.gz" -type f -mtime +30 -exec rm -vf {} \;
```
Notes:
- Use `-mtime +N` to remove files older than N days.

---
