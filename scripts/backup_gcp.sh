#!/usr/bin/env bash

# backup_gcp.sh
# Production-ready GCS Sync Script for Homelab / Proxmox Backup Server (PBS)
# Features:
# - File locking (flock) to prevent concurrent runs
# - Google Cloud Service Account Authentication
# - Optional GPG Symmetric Encryption for VZDump files (PBS handles its own encryption)
# - Prometheus textfile metrics export (success/failure/duration)

set -e

# ==========================================
# CONFIGURATION
# ==========================================

# Use an Ansible-deployed JSON key. Keep this safe (chmod 0600)
GCP_SA_JSON="/etc/gcp/homelab-backup-sa.json" 

# What are we backing up? 
# If this is a PBS Datastore, it's ALREADY encrypted and chunked by PBS!
SOURCE_DIR="/mnt/pve/backups/dump" 
GCS_BUCKET="gs://your-homelab-backup-bucket"
LOG_FILE="/var/log/homelab_gcp_backup.log"

# Encryption settings (Turn to true if syncing raw VZDumps, false if syncing a PBS datastore)
USE_ENCRYPTION="false"
GPG_PASSPHRASE="your_super_secret_passphrase" # Better: Load from a secure file
ENCRYPTED_STAGING_DIR="/mnt/pve/backups/encrypted_staging"

# Prometheus Monitoring (Node Exporter textfile collector dir)
PROM_METRICS_FILE="/var/lib/node_exporter/textfile_collector/gcp_backup.prom"

# Lock file to prevent concurrent execution
LOCK_FILE="/var/run/homelab_gcp_backup.lock"

# ==========================================
# FUNCTIONS
# ==========================================

log_msg() {
    local message="$1"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $message" | tee -a "$LOG_FILE"
}

write_prom_metric() {
    local status=$1
    local duration=$2
    local timestamp=$(date +%s)
    # Use a temporary file to prevent prometheus from reading a half-written file
    cat <<EOF > "${PROM_METRICS_FILE}.tmp"
# HELP homelab_gcp_backup_status 1 for success, 0 for failure
# TYPE homelab_gcp_backup_status gauge
homelab_gcp_backup_status $status
# HELP homelab_gcp_backup_last_run_timestamp Epoch timestamp of the last backup run
# TYPE homelab_gcp_backup_last_run_timestamp gauge
homelab_gcp_backup_last_run_timestamp $timestamp
# HELP homelab_gcp_backup_duration_seconds Duration of the backup run in seconds
# TYPE homelab_gcp_backup_duration_seconds gauge
homelab_gcp_backup_duration_seconds $duration
EOF
    mv "${PROM_METRICS_FILE}.tmp" "$PROM_METRICS_FILE"
}

cleanup() {
    local exit_code=$?
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))

    if [ $exit_code -eq 0 ]; then
        log_msg "Backup completed successfully in $duration seconds."
        write_prom_metric 1 $duration
    else
        log_msg "ERROR: Backup failed after $duration seconds."
        write_prom_metric 0 $duration
    fi
}

# Trap exit signals to ensure cleanup runs
trap cleanup EXIT
START_TIME=$(date +%s)

# ==========================================
# EXECUTION (Wrapped in flock)
# ==========================================

# Open file descriptor 9 and acquire an exclusive lock
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    log_msg "ERROR: Another instance of this script is currently running."
    write_prom_metric 0 0
    exit 1
fi

log_msg "Starting Homelab GCS Sync Pipeline..."

# 1. Authenticate with Google Cloud using Service Account
if [ ! -f "$GCP_SA_JSON" ]; then
    log_msg "ERROR: Service account file not found at $GCP_SA_JSON"
    exit 1
fi
gcloud auth activate-service-account --key-file="$GCP_SA_JSON" >> "$LOG_FILE" 2>&1

# 2. Encryption (If enabled)
TARGET_SYNC_DIR="$SOURCE_DIR"
if [ "$USE_ENCRYPTION" = "true" ]; then
    log_msg "Encrypting files locally before upload..."
    mkdir -p "$ENCRYPTED_STAGING_DIR"
    
    # Simple example: Tar and encrypt the whole source directory
    # Note: For large directories, encrypting file-by-file with rclone is usually better.
    TAR_FILE="$ENCRYPTED_STAGING_DIR/backup-$(date +%Y%m%d).tar.gz.gpg"
    tar -czf - -C "$SOURCE_DIR" . | gpg --symmetric --batch --passphrase "$GPG_PASSPHRASE" -o "$TAR_FILE"
    
    TARGET_SYNC_DIR="$ENCRYPTED_STAGING_DIR"
    log_msg "Encryption complete. Encrypted file: $TAR_FILE"
fi

# 3. Perform Sync
log_msg "Syncing $TARGET_SYNC_DIR to $GCS_BUCKET..."
# Using --delete-unmatched-destination-objects strictly aligns GCS with your local PBS retention
gcloud storage rsync "$TARGET_SYNC_DIR" "$GCS_BUCKET" \
    --recursive \
    --delete-unmatched-destination-objects \
    >> "$LOG_FILE" 2>&1

# 4. Clean up staging if encryption was used
if [ "$USE_ENCRYPTION" = "true" ]; then
    log_msg "Cleaning up encrypted staging files..."
    rm -rf "$ENCRYPTED_STAGING_DIR"/*
fi

# Lock is released automatically when script exits and fd 9 closes.
exit 0
