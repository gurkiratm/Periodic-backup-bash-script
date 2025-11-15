#!/bin/bash
set -e
#NOTE: Backup using path in array with different cron for tarball and directories with implicit argument
############################ FILE PATH ###############################
bpaths=(
"/srv/knot/6c"
"/etc/sysconfig/network-scripts"
"/etc/s64cachedns"
"/etc/chrony.conf"
"/etc/snmp/snmpd.conf"
"/etc/hostname"
"/opt/nwreg2/local/"
"/etc/rsyslog.conf"
"/etc/rsyslog.d/cpnrsdk-log.conf"
"/etc/passwd"
"/etc/profile"
"/etc/sudoers"
"/root/.bashrc"
"/opt/dev_cpnr/"
)  ##update as per your usecase##
######################################################################
base_path=$HOME # Base directory for backups
rsync_path="<user>@<IP_address>:<remote_backup_path>" # Remote rsync path
cron_schedule_tar="0 1 * * 6"  # At 01:00 on Saturday ## can be changed as per requirement
#cron_schedule_tar="*/1 * * * *" # For testing every minute 
cron_schedule_dir="0 2 * * *" # At 02:00 every day  ## can be changed as per requirement
#cron_schedule_dir="*/3 * * * *" # For testing every 3 minutes

current_time=$(date '+d%Y%m%d_t%H%M%S') 
#base_path=/tmp
ssh_key="$base_path/sshkey" # Temporary SSH key file path
logfile="$base_path/$(hostname)_backup.log"  # Log file path
backup_path="$base_path/$(hostname)_${current_time}_bkp.tar.gz" # tmp local backup tarball path
script_path=$(realpath "$0")  # Full path to this script
cron_entry_tar="$cron_schedule_tar $USER $script_path"  # Cron entry for tarball backup
cron_entry_dir="$cron_schedule_dir $USER $script_path"  # Cron entry for directory backup


########################### Color Codes ####################################
BOLD='\e[1m'
UNDERLINE='\e[4m'
BLINK='\e[5m'
INVERSE='\e[7m'
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
BLUE='\e[34m'
MAGENTA='\e[35m'
CYAN='\e[36m'
B_GREEN='\e[42m'
B_BLUE='\e[44m'
RESET='\e[0m'
################################################################################

if [[ $(/usr/bin/id -u) -ne 0 ]]; then
        echo -e "${MAGENTA}<WARNING> Please use root privileges.${RESET}" >&2
#       exit 1;
fi

if ! type rsync > /dev/null 2>&1 ; then
        echo -e "${RED}<ERROR> Please install rysnc before running this script.${RESET}" >&2
        exit 1
fi

cleanup() {
#       echo -e "${YELLOW}<INFO> Removing temporary SSH key file...${RESET}"
        rm -f ${ssh_key}
}
trap cleanup EXIT
exec >> $logfile 2>&1


## Function to create temporary SSH key file##
create_sshkey() {
echo "<##Private key for remote login##>" > ${ssh_key}
chmod 600 ${ssh_key}
}

echo -e "${CYAN}<START>$USER starting backup script at $(date)${RESET}"
echo -e "${YELLOW}<INFO> Provided backup paths: ${bpaths[@]}${RESET}"
echo -e "${YELLOW}<INFO> Log file: ${logfile}${RESET}"

############################### File Path Check ####################################
echo -e "${YELLOW}<INFO> Checking backup paths...${RESET}"
valid_paths=()
for path in "${bpaths[@]}"; do
        if [ -d "$path" ] || [ -f "$path" ]; then
                echo -e "${GREEN}<SUCCESS> Path exists: $path${RESET}"
                valid_paths+=("$path")  # Add to valid paths
        else
                echo -e "${RED}<ERROR> Path does not exist: $path${RESET}" >&2
        fi
done
if [ ${#valid_paths[@]} -eq 0 ]; then
        echo -e "${RED}<ERROR> No valid paths found. Exiting.${RESET}" >&2
        exit 1
fi
echo -e "${YELLOW}<INFO> Valid backup paths: ${valid_paths[@]}${RESET}"
bpaths=("${valid_paths[@]}")

############################# Tar zip creation  ####################################
# Tarball Sync
if [[ $1 == "tarball" ]]; then
        echo -e "${YELLOW}<INFO> Running Tarball Sync...${RESET}"
        if tar --ignore-failed-read -czvf "${backup_path}" "${bpaths[@]}"; then
                echo -e "${GREEN}<SUCCESS> Tar archive created successfully at ${backup_path}${RESET}"
        else
                echo -e "${RED}<ERROR> Failed to create tar archive${RESET}" >&2
                exit 1
        fi
        create_sshkey
        if rsync -avrhq -e "ssh -i ${ssh_key}" --remove-source-files --log-file="$logfile" \
        $base_path/$(hostname)_*.tar.gz "${rsync_path}/$(hostname)/" \
        ; then
                echo -e "${GREEN}<SUCCESS> Rsync of tarball completed successfully${RESET}"
        else
                echo -e "${RED}<ERROR> Rsync of tarball failed${RESET}" >&2
        exit 1
        fi
else
        echo -e "${YELLOW}<INFO> Tarball not requested ${RESET}"
fi
############## Sync complete directories structure and files to the path ##############
# Directory Sync
if [[ $1 == "directories" ]]; then
        echo -e "${YELLOW}<INFO> Running Directory Sync...${RESET}"
        create_sshkey
        if rsync -avrhqR -e "ssh -i ${ssh_key}" --delete --ignore-missing-args --log-file="$logfile" \
        "${bpaths[@]}" "${rsync_path}/$(hostname)/" \
        ; then
                echo -e "${GREEN}<SUCCESS> Rsync of directories completed successfully${RESET}"
        else
                echo -e "${RED}<ERROR> Rsync of directories failed${RESET}" >&2
        exit 1
        fi
else
        echo -e "${YELLOW}<INFO> directories sync not requested ${RESET}"
fi
##################### Cron job configuration of the the script########################
# Add cron job for tarball sync
#if [ ! -f /etc/cron.d/backup_script_tarball ]; then
if ! grep -Fq "$cron_entry_tar" /etc/cron.d/backup_script_tarball ; then
        echo -e "${YELLOW}<INFO> Creating|updating cron job for tarball sync...${RESET}"
        echo "$cron_entry_tar tarball" > /etc/cron.d/backup_script_tarball
        echo -e "${GREEN}<SUCCESS> Cron job for tarball added successfully.${RESET}"
else
        echo -e "${YELLOW}<INFO> Cron job for tarball already exists.${RESET}"
fi
# Add cron job for directories sync
#if [ ! -f /etc/cron.d/backup_script_directories ]; then
if ! grep -Fq "$cron_entry_dir" /etc/cron.d/backup_script_directories ; then
        echo -e "${YELLOW}<INFO> Creating|updating cron job for directories sync...${RESET}"
        echo "$cron_entry_dir directories" > /etc/cron.d/backup_script_directories
        echo -e "${GREEN}<SUCCESS> Cron job for directories added successfully.${RESET}"
else
        echo -e "${YELLOW}<INFO> Cron job for directories already exists.${RESET}"
fi
if [ $? -eq 0 ]; then
        echo -e "${CYAN}<END> Script execution completed at $(date)${RESET}\n\n${GREEN}${BLINK}------------------------------X-X-X-X-X---------------------------------${RESET}\n"
else
        echo -e "${RED}<ERROR> Script exited with Error at $(date)${RESET}\n\n${RED}${BLINK}------------------------------X-X-X-X-X---------------------------------${RESET}\n"
fi
create_sshkey
rsync -avhq -e "ssh -i ${ssh_key}" --inplace --ignore-missing-args  $base_path/$(hostname)_*.log "${rsync_path}/$(hostname)/"
#rsync -avhv -e "ssh -i ${ssh_key}" --inplace --progress --ignore-missing-args --remove-source-files  /tmp/$(hostname)_*.log "${rsync_path}/$(hostname)/"
#echo "exit code is $?"
