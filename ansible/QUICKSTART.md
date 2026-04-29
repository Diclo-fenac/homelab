# Quick Start Guide - T7910 Ansible Lab

## 📋 Table of Contents
1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [Configuration](#configuration)
4. [Deployment](#deployment)
5. [Verification](#verification)
6. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### System Requirements
- **Proxmox VE 7.x or 8.x** installed on T7910
- **SSH access** to Proxmox host
- **API Token** created in Proxmox (see below)
- **Control machine** (Linux, macOS, or WSL) with:
  - Python 3.8+
  - pip3
  - SSH client
  - curl

### Proxmox API Token Setup

1. **Log into Proxmox Web UI** (https://your-t7910-ip:8006)
2. **Navigate**: Datacenter → Permissions → API Tokens
3. **Click**: "Add"
4. **Configure**:
   - User: `root@pam` (or your user)
   - Token ID: `ansible-token`
   - Privilege Separation: Unchecked
5. **Copy** the displayed token (won't be shown again!)
6. **Grant permissions** (or use sudo for testing):
   - Datacenter → Permissions → Add
   - User/Token: Your token
   - Role: Administrator (or custom role with VM/LXC create/delete)

---

## Initial Setup

### 1. Clone or Organize Files

```bash
# Create directory structure
mkdir -p ~/t7910-ansible-lab
cd ~/t7910-ansible-lab

# Copy all files from this repository
# Or initialize git:
git clone <your-repo> .
cd ansible-lab
```

### 2. Install Dependencies

```bash
# Install Ansible and Python packages
make install

# Or manually:
pip3 install -r requirements-python.txt
ansible-galaxy install -r requirements.yml
```

### 3. Setup Vault (Secrets Management)

```bash
# Initialize Ansible Vault
make vault-init

# You'll be prompted for a password
# This will create vault-password-file (KEEP THIS SECRET!)
```

---

## Configuration

### 1. Update Inventory

Edit `inventory/hosts.yml` and update:

```yaml
proxmox:
  hosts:
    t7910:
      ansible_host: 192.168.1.100        # Your T7910 IP
      proxmox_api_host: 192.168.1.100    # Same as above
      proxmox_api_user: root@pam         # Proxmox user
```

### 2. Add Vault Secrets

Create encrypted secrets file:

```bash
# Edit secrets (will prompt for vault password)
ansible-vault create inventory/group_vars/all.yml
```

Add the following to your vault file:

```yaml
---
# Proxmox API Token
vault_proxmox_api_token: "your-api-token-here"

# Tailscale Auth Key (get from https://login.tailscale.com/admin/settings/keys)
vault_tailscale_auth_key: "tskey-xxxxxxxxxxxxxxxxxxxx"

# Grafana Admin Password
vault_grafana_password: "your-secure-password"

# Cloud-Init password (for VM initial setup)
vault_cloud_init_password: "your-vm-setup-password"

# Authentik (SSO) Admin Password
vault_authentik_password: "your-authentik-password"
```

### 3. Customize Host Variables (Optional)

Edit individual series configuration in `inventory/group_vars/`:

```bash
# Gateway settings
vi inventory/group_vars/series_1_gateway.yml

# Observability settings
vi inventory/group_vars/series_2_observability.yml

# Platform VM settings
vi inventory/group_vars/series_3_platform.yml

# AI VM settings
vi inventory/group_vars/series_4_ai.yml
```

### 4. Customize Host IPs (If Different)

If your network is different (e.g., 192.168.100.x instead of 192.168.1.x):

Edit `inventory/hosts.yml` and update all IP addresses in:
- Host `ansible_host` values
- Gateway variables
- DNS records
- Networking configuration

---

## Deployment

### Option 1: Deploy Everything (Recommended for First Run)

```bash
# Full deployment with confirmation prompts
make deploy-all

# Or directly:
ansible-playbook playbooks/site.yml --vault-password-file=vault-password-file
```

### Option 2: Deploy Series Individually

```bash
# Run prerequisites first
make prerequisites

# Then deploy each series
make series1          # Gateway
make series2          # Observability
make series3          # Platform VM
make series4          # AI/Staging VM
make management       # Management LXC
```

### Option 3: Dry Run (Check Mode)

Test without making changes:

```bash
ansible-playbook playbooks/site.yml --check --vault-password-file=vault-password-file
```

---

## Verification

### Check Deployment Status

```bash
# Verify all infrastructure is running
make validate

# Or manually:
make status              # Check Proxmox containers/VMs
make ping                # Test SSH connectivity
```

### Access Services

Once deployed:

```
Gateway (Series 1):       192.168.1.101
  - Nginx Reverse Proxy
  - Tailscale VPN
  - DNS Server

Observability (Series 2): 192.168.1.102
  - Prometheus:           http://192.168.1.102:9090
  - Grafana:              http://192.168.1.102:3000
  - Beszel:               http://192.168.1.102:3001

Platform VM (Series 3):   192.168.1.103
  - Immich:               http://192.168.1.103:2283
  - Nextcloud:            http://192.168.1.103:80
  - Plane:                http://192.168.1.103:3000
  - Authentik (SSO):      http://192.168.1.103:9000

AI/Staging VM (Series 4): 192.168.1.104
  - Ollama API:           http://192.168.1.104:11434

Management (Series 5):    192.168.1.105
  - Ansible Control Node
```

### Via Gateway Reverse Proxy (Recommended)

Access services through the gateway:

```
https://immich.lab.local       → Immich (via Gateway)
https://nextcloud.lab.local    → Nextcloud
https://plane.lab.local        → Plane
https://auth.lab.local         → Authentik
https://prometheus.lab.local   → Prometheus
https://grafana.lab.local      → Grafana
```

---

## Troubleshooting

### Issue: "Proxmox API authentication failed"

```bash
# Verify API token is correct
cat vault-password-file | grep proxmox_api_token

# Check Proxmox permissions:
# Datacenter → Permissions → Verify your token has "Administrator" role
```

### Issue: "SSH: Permission denied (publickey)"

```bash
# Ensure SSH key has correct permissions
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub

# Add key to Proxmox:
ssh-copy-id -i ~/.ssh/id_rsa.pub root@192.168.1.100
```

### Issue: "Cloud-init timeout on VM"

```bash
# Verify cloud-init image is available:
pve-enh-gpl and pve-no-subscription repos enabled

# Check logs on the VM:
ssh debian@192.168.1.103 "tail -f /var/log/cloud-init-output.log"
```

### Issue: "Container/VM creation fails at Proxmox API"

```bash
# Verify Proxmox credentials:
ansible-playbook playbooks/00-prerequisites.yml --vault-password-file=vault-password-file

# Check storage:
pvesm status

# Check available resources:
proxmox-ve version
```

### Issue: "Ansible: unreachable - Failed to connect to the host via ssh"

```bash
# Test SSH connectivity manually
ssh -v root@192.168.1.101

# If fails, check:
1. Host is powered on: make status
2. SSH service is running: systemctl status ssh
3. Firewall allows SSH: ufw status
4. Network connectivity: ping 192.168.1.101
```

### View Detailed Logs

```bash
# See full Ansible execution log
tail -f ansible.log

# See logs for specific series:
ansible-playbook playbooks/01-series1-gateway.yml -vvv --vault-password-file=vault-password-file

# Check systemd logs on target:
ssh root@192.168.1.101 "journalctl -n 100 -f"
```

---

## Next Steps

1. **Review the docs/**:
   - PROXMOX_SETUP.md - Detailed Proxmox configuration
   - ROLES.md - Role documentation
   - SECURITY.md - Security hardening details

2. **Customize for your environment**:
   - Update domain names (currently lab.local)
   - Adjust resource allocations
   - Configure service-specific settings

3. **Implement backups**:
   - Set `backup_enabled: true` in group_vars/proxmox.yml
   - Configure backup storage

4. **Setup monitoring**:
   - Configure Prometheus scrape targets
   - Create Grafana dashboards
   - Setup alerting

5. **Enable high availability** (optional):
   - Setup Proxmox cluster (requires 3+ nodes)
   - Configure failover

---

## Common Commands

```bash
# Deployment
make deploy-all              # Deploy everything
make series1                 # Deploy specific series
make test                    # Dry-run check

# Status & Monitoring
make status                  # Check container/VM status
make validate                # Run health checks
make ping                    # Test connectivity
make logs                    # View logs

# Maintenance
make lint                    # Lint playbooks
make clean                   # Clean temp files
make vault-init              # Manage vault

# Destruction (CAREFUL!)
make teardown                # Destroy all infrastructure
```

---

## Support

For issues or questions:

1. Check this guide's troubleshooting section
2. Review Ansible documentation: https://docs.ansible.com/
3. Check Proxmox docs: https://pve.proxmox.com/wiki/
4. Review log files for specific errors

---

**Version**: 1.0  
**Last Updated**: 2026  
**Target**: T7910 Proxmox Node  

Good luck with your lab! 🚀
