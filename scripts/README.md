# Homelab Scripts

This directory contains utility and automation scripts for the homelab.

## `backup_gcp.sh` - Production Grade GCS Backup

This script synchronizes local Proxmox or PBS backups to Google Cloud Storage (GCS). It is designed to run unattended via Cron.

### Key Features
*   **Service Account Auth:** Uses a dedicated JSON key for secure, non-expiring authentication.
*   **Concurrency Locking:** Uses `flock` to ensure two backups never run at the same time.
*   **Prometheus Metrics:** Outputs success status, last run time, and duration to Node Exporter for Grafana alerting.
*   **PBS Datastore Support:** If you sync a Proxmox Backup Server (PBS) datastore directory, your data is **already encrypted, chunked, and deduplicated client-side**. This is highly recommended over raw VZDumps.
*   **Optional GPG Encryption:** If you aren't using PBS, the script can GPG encrypt your files before uploading.

### Q: Should I use a JSON key with Ansible?
**Yes.** In a proper "Infrastructure as Code" setup, you should **never** hardcode the JSON key in this Git repository.
Instead:
1.  Store the JSON key contents in Ansible Vault (or HashiCorp Vault).
2.  Write an Ansible task that copies the secret to the server (e.g., `/etc/gcp/homelab-backup-sa.json`) with strict `0600` permissions (read/write only by root).

### Setting up GCS Lifecycle Rules (15 Days)
You asked how to keep backups for exactly 15 days using Lifecycle Rules. You do **not** configure this in the script. You configure this directly on the GCP Bucket once. GCP will automatically delete files older than 15 days, saving you money.

You can apply a rule via the `gcloud` CLI (run this once from your admin laptop):

1. Create a file named `lifecycle.json`:
```json
{
  "rule": [
    {
      "action": {"type": "Delete"},
      "condition": {"age": 15}
    }
  ]
}
```

2. Apply it to your bucket:
```bash
gcloud storage buckets update gs://your-homelab-backup-bucket --lifecycle-file=lifecycle.json
```
