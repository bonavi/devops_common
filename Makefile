export ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)
export HOST GROUP PLAYBOOK ANSIBLE_ARGS ACTION ENV RELEASE APP_VERSION RELEASE_TIMEOUT KUBE_USER MODULE
SCRIPTS := $(ROOT)/common/scripts/make

# Список задач и параметров (задача по умолчанию)
help:
	@$(SCRIPTS)/help.sh

# Секреты ansible-хоста.                 HOST=k3s
edit-ansible-secrets:
	@$(SCRIPTS)/edit-ansible-secrets.sh

# Секреты окружения k3s (SOPS).            ENV=prod|dev
edit-k3s-secrets:
	@$(SCRIPTS)/edit-k3s-secrets.sh

# Ansible-плейбук.                         GROUP=vpn-server PLAYBOOK=deploy-xray-agent HOST=all
run-ansible-playbook:
	@$(SCRIPTS)/run-ansible-playbook.sh

# Действие с k3s: apply|sync|diff|template|destroy|restore-db|kubeconfig.
#                                          ACTION=apply ENV=prod RELEASE=go-server|all
do-k3s:
	@$(SCRIPTS)/do-k3s.sh

# Terraform-модуль проекта (terraform/<модуль>): plan|apply|import.
#                                          MODULE=dns ACTION=plan
do-terraform:
	@$(SCRIPTS)/do-terraform.sh

.PHONY: help edit-ansible-secrets edit-k3s-secrets run-ansible-playbook do-k3s do-terraform
