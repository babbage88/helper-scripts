#!/bin/bash
export DATE=$(date +%Y_%m_%d)
export MOV_LOG_FILE="${DATE}_b2_rclone_mov.log"
export TV_LOG_FILE="${DATE}_b2_rclone_tv.log"
rclone sync /mnt/trahan-nas/Movies/ b2_media:backup-trah-nas/Movies/ \
  --exclude-from /scripts/exclude_from_backup.txt \
  --multi-thread-streams=8 \
  --log-level=INFO \
  --log-file=/scripts/logs/$MOV_LOG_FILE
rclone sync /mnt/trahan-nas/TV/ \
  b2_media:backup-trah-nas/TV/ \
  --exclude-from /scripts/exclude_from_backup.txt \
  --multi-thread-streams=8 \
  --log-level=INFO \
  --log-file=/scripts/logs/$TV_LOG_FILE
