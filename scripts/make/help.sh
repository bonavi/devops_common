#!/usr/bin/env bash
# Справка по задачам: без параметров каждая показывает меню, любой пункт можно задать переменной
cat <<'HELP'
Задачи (без параметров — меню):

  make edit-ansible-secrets   секреты ansible-хоста          HOST=k3s
  make edit-k3s-secrets       секреты окружения k3s (SOPS)   ENV=prod|dev
  make run-ansible-playbook   ansible-плейбук                GROUP=vpn-server PLAYBOOK=deploy-xray-agent HOST=all|<хост>
                                                             ANSIBLE_ARGS="-e key=value"
  make do-k3s                 действие с кластером           ACTION=apply|sync|diff|template|destroy|restore-db|kubeconfig
                                                             ENV=prod|dev RELEASE=all|<релиз>
                                                             RELEASE_TIMEOUT=180 APP_VERSION=latest KUBE_USER=devops
HELP
