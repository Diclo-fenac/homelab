# Ansible Lab - Quick Reference Card

## 🚀 One-Command Deployment

```bash
cd ansible-lab
make install           # Install dependencies (5 min)
make vault-init        # Setup secrets (2 min)
# Edit inventory/hosts.yml & add vault secrets
make deploy-all        # Deploy everything (40 min)
```

---

## 📍 Network Map

```
INTERNET (Tailscale VPN)
    ↓
192.168.1.101 - Gateway LXC
├─ Nginx Reverse Proxy
├─ Tailscale VPN
└─ DNS Server
    ↓
    ├─→ 192.168.1.102 (Observability LXC)
    │   ├─ Prometheus:9090
    │   ├─ Grafana:3000
    │   └─ Beszel:3001
    │
    ├─→ 192.168.1.103 (Platform VM)
    │   ├─ Immich:2283
    │   ├─ Nextcloud:80
    │   ├─ Plane:3000
    │   ├─ Dashy:80
    │   └─ Authentik:9000
    │
    ├─→ 192.168.1.104 (AI VM)
    │   ├─ Ollama:11434
    │   └─ GPU (CUDA)
    │
    └─→ 192.168.1.105 (Management LXC)
        └─ Ansible Control Node
```

---

## 📦 Container/VM Specifications

| Series | Type | ID | RAM | CPU | Storage | Purpose |
|--------|------|-----|-----|-----|---------|---------|
| 1 | LXC | 101 | 2GB | 2 | 20GB | Nginx Gateway |
| 2 | LXC | 102 | 4GB | 4 | 50GB | Monitoring |
| 3 | VM | 200 | 16GB | 8 | 100GB+500GB | Docker Host |
| 4 | VM | 201 | 32GB | 16 | 100GB | AI Workstation |
| 5 | LXC | 105 | 2GB | 2 | 30GB | Ansible Hub |

---

## 🎮 Essential Commands

```bash
# Deployment
make deploy-all              # Full deployment
make series1/2/3/4           # Deploy specific series
make prerequisites           # Validation only
make test                    # Dry-run

# Status & Monitoring
make status                  # Check container/VM status
make validate                # Health checks
make ping                    # Test SSH
make logs                    # View logs

# Maintenance
make lint                    # Check syntax
make clean                   # Remove temp files
make teardown                # ⚠️ DESTROY infrastructure

# Ansible direct commands
ansible all -m ping                    # Test connectivity
ansible gateway -m service -a "name=nginx state=restarted"  # Restart service
ansible platform-vm -m docker_container -a "name=immich state=started"  # Restart Docker container
```

---

## 🔑 SSH Access

```bash
# Direct SSH
ssh root@192.168.1.101      # Gateway
ssh root@192.168.1.102      # Observability
ssh debian@192.168.1.103    # Platform VM
ssh debian@192.168.1.104    # AI VM
ssh root@192.168.1.105      # Management

# From Ansible host
ansible gateway -m shell -a "uptime"
ansible all -m setup | grep ansible_host
```

---

## 🌐 Service Access

```
Via Gateway Reverse Proxy (Recommended):
  https://immich.lab.local       → Immich (Photos)
  https://nextcloud.lab.local    → Nextcloud (Files)
  https://plane.lab.local        → Plane (Projects)
  https://prometheus.lab.local   → Prometheus
  https://grafana.lab.local      → Grafana (Dashboards)
  https://auth.lab.local         → Authentik (SSO)

Direct Access:
  http://192.168.1.102:9090      → Prometheus
  http://192.168.1.102:3000      → Grafana
  http://192.168.1.103:2283      → Immich
  http://192.168.1.104:11434     → Ollama API
```

---

## 🔒 Vault Secrets

```bash
# Create/edit vault
make vault-init
ansible-vault create inventory/group_vars/all.yml
ansible-vault edit inventory/group_vars/all.yml

# View vault contents (decrypted in memory)
ansible-vault view inventory/group_vars/all.yml --vault-password-file=vault-password-file

# Required secrets:
vault_proxmox_api_token        # Proxmox API token
vault_tailscale_auth_key       # Tailscale auth key
vault_grafana_password         # Grafana admin password
vault_cloud_init_password      # VM initial password
vault_authentik_password       # Authentik admin password
```

---

## 🐛 Quick Troubleshooting

| Issue | Check |
|-------|-------|
| Playbook fails | `make test` (dry-run first) |
| SSH error | `make ping` (connectivity test) |
| API auth fails | Verify `vault_proxmox_api_token` |
| Containers won't start | Check Proxmox storage: `pvesm status` |
| Cloud-init timeout | Check VM has network: `ssh debian@IP` |
| Nginx 502 | Verify upstream services running |
| Prometheus no targets | Check Series 2 deployed correctly |

---

## 📂 Key Files to Edit

```
inventory/hosts.yml              ← Update IP addresses
inventory/group_vars/series_*.yml ← Customize per-series
ansible-vault (secrets)          ← Add credentials
roles/*/defaults/main.yml        ← Role configuration
roles/*/templates/*.j2           ← Service configs
```

---

## 🔄 Disaster Recovery

```bash
# After hardware failure:
git clone <your-repo> ansible-lab
cd ansible-lab
make install
make deploy-all

# Rebuild time: ~40 minutes
# All configuration restored ✓
# User data: Restore from backups separately
```

---

## 📊 Resource Usage (Baseline)

| Component | CPU | RAM | Disk |
|-----------|-----|-----|------|
| T7910 Host | ~5% | ~8GB | 2TB+ |
| Series 1+2+5 (LXCs) | ~1% | 8GB | 100GB |
| Series 3 (Docker) | ~3% | 16GB | 600GB |
| Series 4 (AI) | ~0% | 32GB | 100GB |
| **Total** | **~10%** | **56GB** | **800GB** |

---

## 🎯 Deployment Checklist

- [ ] Proxmox API token created
- [ ] `inventory/hosts.yml` updated with correct IPs
- [ ] Vault secrets configured
- [ ] SSH key has correct permissions (0600)
- [ ] Network access to Proxmox API (8006)
- [ ] Network IPs planned (192.168.1.101-105)
- [ ] Storage available on Proxmox node
- [ ] Git repo created for backups

---

## 📚 Documentation Quick Links

| Document | Purpose |
|----------|---------|
| `README.md` | Full documentation |
| `QUICKSTART.md` | 5-minute setup |
| `ARCHITECTURE.md` | Technical deep-dive |
| `IMPLEMENTATION_SUMMARY.md` | Overview |
| `docs/PROXMOX_SETUP.md` | Proxmox config |
| `docs/SECURITY.md` | Security details |
| `docs/TROUBLESHOOTING.md` | Common issues |

---

## 🚨 Critical Don'ts

```
❌ DON'T commit vault-password-file to git
❌ DON'T commit unencrypted secrets
❌ DON'T use the same API token for multiple setups
❌ DON'T run make teardown without double-checking
❌ DON'T expose Grafana/Prometheus to the internet
❌ DON'T share vault password via email/chat
❌ DON'T forget to backup your Ansible code
```

---

## ✅ Critical Do's

```
✅ DO use Ansible Vault for all secrets
✅ DO version control your Ansible code (git)
✅ DO run `make test` before `make deploy-all`
✅ DO backup the vault password securely
✅ DO document any customizations you make
✅ DO monitor resource usage after deployment
✅ DO test disaster recovery (rebuild from git)
✅ DO update Proxmox regularly
```

---

## 🏗️ Customization Examples

### Add a custom service to Series 3

```yaml
# In roles/docker_host/templates/docker-compose.yml.j2
my-service:
  image: myregistry/my-service:latest
  ports:
    - "5000:5000"
  environment:
    - MY_VAR=value
```

### Add a custom Prometheus scrape job

```yaml
# In roles/observability/templates/prometheus.yml.j2
scrape_configs:
  - job_name: 'my-custom-service'
    static_configs:
      - targets: ['192.168.1.103:5000']
```

### Increase Series 4 AI VM resources

```yaml
# In inventory/group_vars/series_4_ai.yml
vm_memory: 64000  # 64GB instead of 32GB
vm_cores: 32      # 32 cores instead of 16
vm_rootfs_size: 200G  # 200GB instead of 100GB
```

---

## 📞 Getting Help

```bash
# Show all available commands
make help

# List all hosts
ansible-inventory -i inventory/hosts.yml --list

# Test Proxmox connectivity
ansible proxmox -m ping

# See what would change (no changes made)
ansible-playbook playbooks/site.yml --check

# Increase verbosity for debugging
ansible-playbook playbooks/01-series1-gateway.yml -vvv
```

---

## 🎓 Learning Resources

- **Ansible**: https://docs.ansible.com/
- **Proxmox**: https://pve.proxmox.com/wiki/
- **Docker**: https://docs.docker.com/
- **Prometheus**: https://prometheus.io/docs/
- **Nginx**: https://nginx.org/en/docs/

---

## 📊 Monitoring Dashboards

```
Grafana (http://192.168.1.102:3000):
├─ System Overview Dashboard
├─ Node Exporter Dashboard
├─ Docker Container Dashboard
├─ Nginx Dashboard
├─ Prometheus Dashboard
└─ Custom Dashboards (you can add)

Prometheus (http://192.168.1.102:9090):
├─ Targets page (active scrapers)
├─ Graph page (metric queries)
├─ Alerts (if configured)
└─ Status pages
```

---

## 🔗 Quick Links

```bash
# Create symlink for easier access
ln -s ~/path/to/ansible-lab ~/lab

# Jump to lab
cd ~/lab
make help

# Edit playbooks
vim playbooks/site.yml

# View logs
tail -f ansible.log
```

---

## 💾 Backup Your Lab

```bash
# Version control your Ansible code
git init
git add .
git commit -m "Initial Ansible lab"
git push -u origin main

# Backup Proxmox node (setup in Proxmox UI)
Datacenter → Backup → Add

# Backup important data (separate from IaC)
rsync -av debian@192.168.1.103:/data/immich /backup/
```

---

**Quick Reference Version**: 1.0  
**Last Updated**: 2026  
**For Full Docs**: See README.md, QUICKSTART.md, ARCHITECTURE.md  

Print this page for quick desk reference! 📋
