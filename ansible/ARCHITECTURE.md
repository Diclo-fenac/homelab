# T7910 Ansible Lab - Complete Architecture & Implementation Guide

## Overview

This Ansible implementation automates the complete deployment of your Hybrid Model architecture on a single T7910 Proxmox node. It provisions and configures all infrastructure through Infrastructure-as-Code (IaC), ensuring reproducibility and idempotency.

---

## Architecture Diagram

```
┌───────────────────────────────────────────────────────────────────┐
│                         T7910 Proxmox Node                         │
│                    (2x Xeon CPUs, Dual GPU ready)                 │
├───────────────────────────────────────────────────────────────────┤
│                                                                    │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │              NETWORK LAYER (vmbr0)                          │ │
│  │  192.168.1.0/24 - Isolated lab network                      │ │
│  └─────────────────────────────────────────────────────────────┘ │
│           ▲             ▲             ▲             ▲             │
│           │             │             │             │             │
│  ┌────────┴──┐  ┌──────┴──┐  ┌──────┴──┐  ┌──────┴──┐            │
│  │ Series 1  │  │ Series 2│  │ Series 3│  │ Series 4│  Series 5  │
│  │ Gateway   │  │Observa- │  │Platform │  │AI/Dev  │  Management│
│  │  (LXC)    │  │bility   │  │  (VM)   │  │ (VM)   │   (LXC)    │
│  │ ID: 101   │  │(LXC)    │  │ID: 200  │  │ID: 201 │   ID: 105  │
│  │2GB|2CPU  │  │ID: 102  │  │16GB|8CP │  │32GB|16C│  2GB|2CPU │
│  │192.168.1 │  │4GB|4CPU │  │100GB+500│  │100GB   │  192.168.1 │
│  │   .101   │  │192.168.1│  │GB storage│  │+GPU    │    .105   │
│  │          │  │   .102  │  │192.168.1│  │192.168.│          │
│  │          │  │         │  │   .103  │  │ 1.104  │          │
│  └──────────┘  └─────────┘  └─────────┘  └────────┘          │
│       │             │             │             │             │
│  ┌────┴──────────┬──┴────────┬────┴──────────┬─┴─────────────┐  │
│  │               │           │               │               │  │
│  └─ Nginx         └─ Prometheus   └─ Immich      └─ Ollama    │  │
│  └─ Tailscale     └─ Grafana      └─ Nextcloud   └─ CUDA      │  │
│  └─ DNS           └─ Beszel       └─ Plane       └─ Dev Tools │  │
│                                    └─ Authentik   └─ GPU Pass │  │
│                                    └─ Dashy                    │  │
│                                                                 │  │
└───────────────────────────────────────────────────────────────────┘
```

---

## Deployment Strategy

### Phases

The deployment happens in **6 coordinated phases**, each building on the previous:

```
Phase 0: Prerequisites
    ↓ (Validate Proxmox API, SSH keys, inventory)
Phase 1: Gateway LXC (101)
    ↓ (Nginx + Tailscale + DNS foundation)
Phase 2: Observability LXC (102)
    ↓ (Prometheus + Grafana + monitoring)
Phase 3: Platform VM (200)
    ↓ (Docker host with services)
Phase 4: AI/Staging VM (201)
    ↓ (Ollama + GPU workstation)
Phase 5: Management LXC (105)
    ↓ (Ansible control node + automation hub)
SUCCESS: Fully automated lab running
```

### Execution Flow

```
Ansible Control Machine
    │
    ├─ Inventory (hosts.yml) 
    │   └─ Defines all hosts, IPs, container specs
    │
    ├─ Playbooks (playbooks/*.yml)
    │   └─ Orchestrate deployment phases
    │
    ├─ Roles (roles/*/tasks/*.yml)
    │   ├─ proxmox_provision: API calls to create LXC/VMs
    │   ├─ common: SSH, packages, networking baseline
    │   ├─ gateway: Nginx, Tailscale, DNS config
    │   ├─ observability: Prometheus, Grafana, monitoring
    │   ├─ docker_host: Docker installation and services
    │   ├─ identity: Authentik SSO deployment
    │   ├─ ai_workstation: Ollama, GPU, dev tools
    │   └─ security: Firewall, fail2ban, CrowdSec
    │
    └─ Templates (roles/*/templates/*.j2)
        ├─ cloud-init.yml.j2: VM initialization script
        ├─ nginx.conf.j2: Reverse proxy config
        ├─ prometheus.yml.j2: Metrics config
        └─ docker-compose.yml.j2: Service definitions
        
        All rendered with Jinja2 from inventory variables
```

---

## Key Implementation Details

### 1. Proxmox Provisioning (Agentless)

The `proxmox_provision` role connects to Proxmox API without requiring agents:

```
Ansible → HTTPS API Call → Proxmox API
             POST /api2/json/nodes/{node}/lxc
             POST /api2/json/nodes/{node}/qemu
         ↓
     Container/VM Created
         ↓
     Cloud-Init / First Boot Scripts Execute
         ↓
     SSH Becomes Available
         ↓
     Ansible Configures via SSH
```

**Advantages**:
- ✅ No agent installation required
- ✅ Pure API-driven provisioning
- ✅ Repeatable and idempotent
- ✅ Full self-contained in single control node

### 2. Container-as-Code

**LXC Containers** (Series 1, 2, 5):
- Created via `pct create` (Proxmox API)
- Configured directly via SSH
- Used for "always-on" infrastructure with minimal resource footprint

**Virtual Machines** (Series 3, 4):
- Created via `qm create` with cloud-init
- Cloud-init handles initial OS setup (user, packages, networking)
- Configuration applied via SSH after cloud-init completes

### 3. Template-Driven Configuration

All complex configurations use Jinja2 templates:

```
Inventory Variables (hosts.yml, group_vars/*.yml)
    ↓
Jinja2 Templates (roles/*/templates/*.j2)
    ↓
Rendered Configuration Files
    ↓
Deployed to target containers/VMs
```

**Example**: nginx.conf.j2 dynamically generates reverse proxy rules based on `nginx_upstreams` from inventory.

### 4. Cloud-Init for VMs

VMs use cloud-init for reproducible initialization:

```yaml
# In cloud-init.yml.j2:
users:
  - name: debian
    ssh_authorized_keys:
      - {{ lookup('file', '~/.ssh/id_rsa.pub') }}
packages:
  - docker.io
  - python3
  - curl
runcmd:
  - docker pull immich/immich:latest
  - systemctl enable docker
```

**Advantage**: VMs self-configure on first boot without manual intervention.

### 5. Dynamic Inventory Groups

Targets are organized for flexible deployment:

```yaml
# Serial deployment (one at a time)
all:
  children:
    series_1_gateway: [gateway]
    series_2_observability: [observability]
    series_3_platform: [platform-vm]
    series_4_ai: [ai-vm]
    series_5_management: [management]

# Service-based targeting
  docker_hosts: [platform-vm]
  ai_workstations: [ai-vm]
  monitoring: [observability]
  nginx_reverse_proxy: [gateway]
  sso_providers: [platform-vm]
  security: [all containers/VMs]
```

This allows:
```bash
# Deploy just Docker hosts
ansible-playbook playbooks/03-series3-platform.yml

# Apply security updates to all
ansible-playbook security-patch.yml -i inventory/hosts.yml -l security

# Check specific service
ansible observability -m service -a "name=prometheus state=restarted"
```

---

## Security Architecture

### Secrets Management (Ansible Vault)

Sensitive data is encrypted:

```
vault-password-file (local, .gitignored)
    ↓
ansible-vault decrypt (during playbook execution)
    ↓
{{ vault_proxmox_api_token }}
{{ vault_tailscale_auth_key }}
{{ vault_grafana_password }}
{{ vault_cloud_init_password }}
{{ vault_authentik_password }}
```

### SSH Hardening (Common Role)

```
├─ Disable password auth
├─ Disable root login (on managed hosts)
├─ Configure key-based only authentication
├─ Setup fail2ban for brute force protection
└─ Configure UFW firewall rules
```

### Network Isolation

```
vmbr0 (Proxmox bridge): 192.168.1.0/24
    ↓
Only accessible internally or via Tailscale VPN
    ↓
Gateway LXC acts as single entry point (Nginx + Tailscale)
```

### Role-Based Access Control (via Authentik SSO)

```
Authentik (Series 3 Platform VM)
    ├─ User authentication
    ├─ Group management
    ├─ OAuth2/OIDC provider
    └─ Forward authentication to Nginx via Gateway

All services → Nginx reverse proxy → Authentik authentication → Service
```

---

## Observability & Monitoring

### Monitoring Stack (Series 2)

```
Prometheus (metrics collector)
    ↑
    ├─ Node Exporter (hardware metrics)
    ├─ Nginx metrics (traffic, performance)
    ├─ Beszel (system health)
    ├─ Docker metrics
    └─ Ollama metrics
    
    ↓
    
Grafana (visualization)
    ├─ System dashboards
    ├─ Service health
    ├─ Performance metrics
    └─ Alerts configuration
    
    ↓
    
Loki (optional: log aggregation)
    └─ Centralized logging from all services
```

### Backup Strategy

```
Beszel Agent (on all containers/VMs)
    ↓
Beszel Server (Series 2)
    ↓
Dashboard showing:
    ├─ Uptime
    ├─ CPU/Memory usage
    ├─ Storage utilization
    ├─ Network throughput
    └─ Service health
```

---

## Service Deployment Architecture

### Series 3: Platform VM (Docker-Based)

```
Docker Host (192.168.1.103)
    │
    ├─ Immich (Photo management)
    │   └─ API: 2283, Storage: /data/immich
    │
    ├─ Nextcloud (File sync)
    │   └─ Web: 80, Data: /data/nextcloud
    │
    ├─ Plane (Project management)
    │   └─ Web: 3000
    │
    ├─ Dashy (Dashboard)
    │   └─ Web: 80
    │
    └─ Authentik (SSO)
        └─ Web: 9000, LDAP: 389
        
All access: Gateway reverse proxy (Series 1)
├─ https://immich.lab.local
├─ https://nextcloud.lab.local
├─ https://plane.lab.local
└─ https://auth.lab.local
```

### Series 4: AI Workstation (GPU-Enabled)

```
AI/Staging VM (192.168.1.104)
    │
    ├─ NVIDIA GPU (passthrough)
    │   └─ CUDA + cuDNN installed
    │
    ├─ Ollama (Local LLMs)
    │   ├─ Models: Mistral, Neural-Chat, etc.
    │   └─ API: http://192.168.1.104:11434
    │
    └─ Development Environment
        ├─ Python 3.11+
        ├─ PyTorch/TensorFlow
        ├─ Jupyter Lab
        └─ Dev tools (Git, Docker, etc.)

Use Case: Local LLM inference without external APIs
API Available: http://192.168.1.104:11434
Web UI: Available if Open-WebUI deployed
```

---

## Disaster Recovery & Reproducibility

### One-Command Rebuild

**After hardware failure, rebuild entire lab**:

```bash
# From backup control machine:
git clone <your-repo>
cd ansible-lab
make install
make deploy-all
```

**Recovery Time**: ~30-45 minutes depending on VM image sizes.

### What Gets Recovered

```
Configuration (IaC):
    ✓ All container specs
    ✓ All VM specs
    ✓ All service configurations
    ✓ All network settings
    ✓ All firewall rules

Data (backups needed separately):
    ✗ Immich photos/videos
    ✗ Nextcloud files
    ✗ Plane projects
    ✗ Prometheus metrics history
    
    → Configure via:
      - Proxmox ZFS snapshots
      - External backup storage
      - Restic/Borg backup
```

---

## Ansible Best Practices Used

✅ **Idempotency**: Playbooks can run repeatedly without side effects
✅ **Modularity**: Organized in roles for reusability
✅ **DRY Principle**: Variables in `group_vars/` and `host_vars/`
✅ **Templating**: Jinja2 for dynamic configuration
✅ **Error Handling**: Retry logic, handlers, blocks with rescue
✅ **Documentation**: Extensive comments in playbooks
✅ **Secrets**: Ansible Vault for sensitive data
✅ **Logging**: All runs logged for audit trail
✅ **Testing**: Check mode support and validation playbooks

---

## File Organization

```
ansible-lab/
├── README.md                      # Main documentation
├── QUICKSTART.md                  # 5-minute setup guide
├── Makefile                       # Convenient commands
├── ansible.cfg                    # Ansible configuration
├── requirements-python.txt        # Python dependencies
├── requirements.yml               # Ansible Galaxy requirements
├── vault-password-file (gitignored)
│
├── inventory/
│   ├── hosts.yml                 # Host definitions
│   ├── group_vars/
│   │   ├── proxmox.yml          # Proxmox defaults
│   │   ├── series_1_gateway.yml
│   │   ├── series_2_observability.yml
│   │   ├── series_3_platform.yml
│   │   ├── series_4_ai.yml
│   │   └── (more group vars)
│   └── host_vars/                # Per-host overrides
│       ├── gateway.yml
│       ├── observability.yml
│       ├── platform-vm.yml
│       ├── ai-vm.yml
│       └── management.yml
│
├── playbooks/
│   ├── 00-prerequisites.yml      # Validation
│   ├── 01-series1-gateway.yml
│   ├── 02-series2-observability.yml
│   ├── 03-series3-platform.yml
│   ├── 04-series4-ai.yml
│   ├── 05-management.yml
│   ├── site.yml                  # Master playbook (all series)
│   ├── validate.yml              # Health checks
│   └── teardown.yml              # Infrastructure destruction
│
├── roles/
│   ├── proxmox_provision/        # VM/LXC creation
│   │   ├── tasks/
│   │   │   ├── main.yml
│   │   │   ├── create_lxc.yml
│   │   │   ├── create_vm.yml
│   │   │   └── wait_for_boot.yml
│   │   └── templates/
│   │       ├── cloud-init.yml.j2
│   │       └── lxc-config.j2
│   │
│   ├── common/                   # Base setup for all hosts
│   │   ├── tasks/
│   │   │   ├── main.yml
│   │   │   ├── packages.yml
│   │   │   ├── networking.yml
│   │   │   └── ssh.yml
│   │   └── defaults/main.yml
│   │
│   ├── gateway/                  # Nginx + Tailscale + DNS
│   ├── observability/            # Prometheus + Grafana
│   ├── docker_host/              # Docker + Docker Compose
│   ├── identity/                 # Authentik SSO
│   ├── ai_workstation/           # Ollama + GPU
│   └── security/                 # Firewall + fail2ban + CrowdSec
│
├── templates/                    # Standalone templates
├── files/                        # Static files
├── vars/                         # Global variables
│
└── docs/                         # Documentation
    ├── PROXMOX_SETUP.md         # Proxmox configuration guide
    ├── INVENTORY.md              # Inventory structure
    ├── ROLES.md                  # Role documentation
    ├── SECURITY.md               # Security hardening
    └── TROUBLESHOOTING.md        # Common issues
```

---

## Execution Timeline

```
Time  | Phase                    | Duration  | Output
────────────────────────────────────────────────────────────
0:00  | Prerequisites check      | 2 min     | ✓ Proxmox API OK
0:02  | Create Series 1 LXC      | 3 min     | LXC 101 running
0:05  | Configure Gateway        | 3 min     | Nginx + Tailscale
0:08  | Create Series 2 LXC      | 3 min     | LXC 102 running
0:11  | Configure Monitoring     | 3 min     | Prometheus online
0:14  | Create Series 3 VM       | 5 min     | VM 200 booting
0:19  | Install Docker services  | 5 min     | All services online
0:24  | Create Series 4 VM       | 5 min     | VM 201 booting
0:29  | Configure AI workstation | 3 min     | Ollama ready
0:32  | Create Series 5 LXC      | 3 min     | LXC 105 running
0:35  | Configure Management     | 2 min     | Ansible control node
0:37  | COMPLETE!                | -         | ✓ All systems ready
```

---

## Maintenance & Operations

### Regular Operations

```bash
# Deploy new series
ansible-playbook playbooks/01-series1-gateway.yml

# Update specific service
ansible-playbook playbooks/03-series3-platform.yml --tags docker,services

# Check health
ansible-playbook playbooks/validate.yml

# Patch security updates
ansible all -m apt -a "name=* state=latest"

# Restart service
ansible series_1_gateway -m service -a "name=nginx state=restarted"
```

### Scaling

**Add more compute**: Duplicate Platform VM role with different container ID
**Add more storage**: Mount additional volumes in VMs
**Enable clustering**: Configure Proxmox cluster (requires 3+ nodes)

---

## Conclusion

This Ansible implementation provides:

✅ **Reproducibility**: One-command lab rebuild after failure
✅ **Scalability**: Modular roles for easy customization
✅ **Observability**: Full monitoring stack built-in
✅ **Security**: Encrypted secrets, hardened OS, SSO integration
✅ **Automation**: Fully unattended deployment
✅ **Documentation**: Comprehensive guides and code comments
✅ **GitOps-Ready**: All infrastructure as code in version control

Your T7910 lab is now a fully automated, self-documenting infrastructure! 🚀

---

**For quick start**: See `QUICKSTART.md`
**For detailed roles**: See `docs/ROLES.md`
**For security**: See `docs/SECURITY.md`
