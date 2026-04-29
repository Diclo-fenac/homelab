# Makefile for T7910 Ansible Lab
# Convenient commands for deploying and managing the infrastructure

.PHONY: help install deploy-all prerequisites series1 series2 series3 series4 management validate status clean lint test

ANSIBLE_DIR := $(shell pwd)
INVENTORY := inventory/hosts.yml
PLAYBOOKS := playbooks

# Colors for output
GREEN := \033[0;32m
BLUE := \033[0;34m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

help:
	@echo "$(BLUE)════════════════════════════════════════════════════════════$(NC)"
	@echo "$(BLUE)  T7910 Ansible Lab - Management Commands                  $(NC)"
	@echo "$(BLUE)════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(GREEN)Installation & Setup:$(NC)"
	@echo "  make install              Install Ansible and dependencies"
	@echo "  make vault-init           Initialize Ansible Vault for secrets"
	@echo ""
	@echo "$(GREEN)Deployment:$(NC)"
	@echo "  make deploy-all           Deploy entire lab (all series)"
	@echo "  make prerequisites        Run prerequisites validation only"
	@echo "  make series1              Deploy Series 1 (Gateway LXC)"
	@echo "  make series2              Deploy Series 2 (Observability LXC)"
	@echo "  make series3              Deploy Series 3 (Platform VM)"
	@echo "  make series4              Deploy Series 4 (AI/Staging VM)"
	@echo "  make management           Deploy Series 5 (Management LXC)"
	@echo ""
	@echo "$(GREEN)Validation & Monitoring:$(NC)"
	@echo "  make validate             Run health checks on all systems"
	@echo "  make status               Check container/VM status"
	@echo "  make ping                 Test connectivity to all hosts"
	@echo "  make logs                 View Ansible execution logs"
	@echo ""
	@echo "$(GREEN)Maintenance:$(NC)"
	@echo "  make lint                 Lint playbooks and roles"
	@echo "  make test                 Test playbooks in check mode"
	@echo "  make clean                Remove temporary files"
	@echo "  make teardown             DESTROY all infrastructure (careful!)"
	@echo ""
	@echo "$(GREEN)Documentation:$(NC)"
	@echo "  make docs                 Generate documentation"
	@echo "  make show-inventory       Display host inventory"
	@echo ""

install:
	@echo "$(YELLOW)Installing Ansible and Python dependencies...$(NC)"
	pip3 install ansible ansible-lint proxmoxer requests netaddr dnspython jinja2
	@echo "$(GREEN)✓ Installation complete$(NC)"
	@echo "$(YELLOW)Next: Run 'make vault-init' to setup secrets$(NC)"

vault-init:
	@echo "$(YELLOW)Initializing Ansible Vault...$(NC)"
	@if [ ! -f vault-password-file ]; then \
		read -sp "Enter vault password: " vault_pass; \
		echo "$$vault_pass" > vault-password-file; \
		chmod 600 vault-password-file; \
		echo ""; \
		echo "$(GREEN)✓ Vault password file created$(NC)"; \
	else \
		echo "$(YELLOW)Vault password file already exists$(NC)"; \
	fi

deploy-all:
	@echo "$(BLUE)════════════════════════════════════════════════════════════$(NC)"
	@echo "$(BLUE)  DEPLOYING ENTIRE LAB (All Series)                        $(NC)"
	@echo "$(BLUE)════════════════════════════════════════════════════════════$(NC)"
	ansible-playbook $(PLAYBOOKS)/site.yml --vault-password-file=vault-password-file -v

prerequisites:
	@echo "$(YELLOW)Running Prerequisites Validation...$(NC)"
	ansible-playbook $(PLAYBOOKS)/00-prerequisites.yml --vault-password-file=vault-password-file -v

series1:
	@echo "$(YELLOW)Deploying Series 1 (Gateway LXC)...$(NC)"
	ansible-playbook $(PLAYBOOKS)/01-series1-gateway.yml --vault-password-file=vault-password-file -v

series2:
	@echo "$(YELLOW)Deploying Series 2 (Observability LXC)...$(NC)"
	ansible-playbook $(PLAYBOOKS)/02-series2-observability.yml --vault-password-file=vault-password-file -v

series3:
	@echo "$(YELLOW)Deploying Series 3 (Platform VM)...$(NC)"
	ansible-playbook $(PLAYBOOKS)/03-series3-platform.yml --vault-password-file=vault-password-file -v

series4:
	@echo "$(YELLOW)Deploying Series 4 (AI/Staging VM)...$(NC)"
	ansible-playbook $(PLAYBOOKS)/04-series4-ai.yml --vault-password-file=vault-password-file -v

management:
	@echo "$(YELLOW)Deploying Series 5 (Management LXC)...$(NC)"
	ansible-playbook $(PLAYBOOKS)/05-management.yml --vault-password-file=vault-password-file -v

validate:
	@echo "$(YELLOW)Running infrastructure validation...$(NC)"
	ansible-playbook $(PLAYBOOKS)/validate.yml --vault-password-file=vault-password-file -v

status:
	@echo "$(YELLOW)Checking container/VM status...$(NC)"
	@echo "$(BLUE)Containers:$(NC)"
	pct list 2>/dev/null || echo "  Proxmox CLI not available"
	@echo ""
	@echo "$(BLUE)Virtual Machines:$(NC)"
	qm list 2>/dev/null || echo "  Proxmox CLI not available"

ping:
	@echo "$(YELLOW)Testing connectivity to all hosts...$(NC)"
	ansible all -m ping -i $(INVENTORY)

logs:
	@echo "$(YELLOW)Recent Ansible activity:$(NC)"
	journalctl -u ansible -n 50 -f 2>/dev/null || echo "  Ansible service logs not available"

lint:
	@echo "$(YELLOW)Linting playbooks and roles...$(NC)"
	ansible-lint $(PLAYBOOKS)/*.yml 2>/dev/null || echo "  ansible-lint not installed (optional)"

test:
	@echo "$(YELLOW)Testing playbooks in check mode...$(NC)"
	ansible-playbook $(PLAYBOOKS)/00-prerequisites.yml --check -v --vault-password-file=vault-password-file

clean:
	@echo "$(YELLOW)Cleaning temporary files...$(NC)"
	find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
	find . -name "*.pyc" -delete 2>/dev/null || true
	find . -name ".DS_Store" -delete 2>/dev/null || true
	find . -name "*~" -delete 2>/dev/null || true
	@echo "$(GREEN)✓ Cleanup complete$(NC)"

show-inventory:
	@echo "$(YELLOW)Ansible Inventory:$(NC)"
	ansible-inventory -i $(INVENTORY) --list | jq '.' 2>/dev/null || ansible-inventory -i $(INVENTORY) --list

docs:
	@echo "$(YELLOW)Generating documentation...$(NC)"
	@echo "Documentation files:"
	@find docs -name "*.md" -type f 2>/dev/null || echo "  Run 'make generate-docs' to create documentation"

teardown:
	@echo "$(RED)════════════════════════════════════════════════════════════$(NC)"
	@echo "$(RED)  WARNING: This will DESTROY all infrastructure!           $(NC)"
	@echo "$(RED)════════════════════════════════════════════════════════════$(NC)"
	@read -p "Type 'DESTROY' to confirm: " confirm; \
	if [ "$$confirm" = "DESTROY" ]; then \
		echo "$(RED)Executing teardown...$(NC)"; \
		ansible-playbook $(PLAYBOOKS)/teardown.yml --vault-password-file=vault-password-file -v; \
	else \
		echo "$(YELLOW)Teardown cancelled$(NC)"; \
	fi

.DEFAULT_GOAL := help
