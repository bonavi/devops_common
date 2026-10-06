#!/usr/bin/env bash
# Редактирование vault-секретов ansible-хоста (создаёт файл, если его нет). Переменные: HOST, VAULT_EDITOR
source "$(dirname "$0")/lib.sh"

host_vars="$ROOT/ansible/host_vars"
host="$(choose "Хост" "${HOST:-}" $(cd "$host_vars" && ls -d */ | tr -d /))" || exit 1

secrets="$host_vars/$host/secrets.yml"
action=edit
[ -f "$secrets" ] || action=create

EDITOR="${VAULT_EDITOR:-goland --wait}" run ansible-vault "$action" "$secrets" \
	--vault-password-file "$ROOT/ansible/config/.vault_password"
