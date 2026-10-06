#!/usr/bin/env bash
# Редактирование SOPS-секретов окружения k3s. Переменные: ENV, SOPS_EDITOR
source "$(dirname "$0")/lib.sh"

environment="$(choose "Окружение" "${ENV:-}" prod dev)" || exit 1

export SOPS_AGE_KEY_FILE="$ROOT/k8s/secrets/key.txt"
EDITOR="${SOPS_EDITOR:-goland --wait}" run sops --config "$ROOT/k8s/secrets/.sops.yaml" "$ROOT/k8s/secrets/secrets-$environment.yaml"
