#!/usr/bin/env bash
# Действие с кластером k3s: действие → окружение → релиз.
# Переменные: ACTION, ENV, RELEASE (all — все релизы окружения), APP_VERSION, RELEASE_TIMEOUT, KUBE_USER
source "$(dirname "$0")/lib.sh"

export SOPS_AGE_KEY_FILE="$ROOT/k8s/secrets/key.txt"
helmfile_file="$ROOT/k8s/helmfile.yaml"

action="$(choose "Действие" "${ACTION:-}" apply sync diff template destroy restore-db kubeconfig)" || exit 1

# Выпуск kubeconfig для пользователя кластера — без окружения и релиза
if [ "$action" = kubeconfig ]; then
	exec "$(dirname "$0")/make-kubeconfig.sh"
fi

environment="$(choose "Окружение" "${ENV:-}" prod dev)" || exit 1

# Восстановление дампов в Postgres выбранного окружения
if [ "$action" = restore-db ]; then
	run "$ROOT/common/scripts/restorePgsqlDumpInK8S/restore-backups.sh" "$environment"
	exit
fi

# Релизы из helmfile.yaml; «all» недоступен для destroy
releases="$(awk '/^releases:/{in_releases=1} in_releases && /^  - name:/{print $3}' "$helmfile_file")"
if [ "$action" = destroy ]; then
	release="$(choose "Релиз" "${RELEASE:-}" $releases)" || exit 1
	confirm "Удалить релиз $release из $environment?"
else
	release="$(choose "Релиз" "${RELEASE:-}" all $releases)" || exit 1
fi

# В dev всегда отсекаем релизы только для prod
filter=""
[ "$environment" = dev ] && filter="env!=prod"
[ "$release" = all ] || filter="${filter:+$filter,}name=$release"

arguments=(-f "$helmfile_file" -e "$environment" "$action")
[ -n "$filter" ] && arguments+=(-l "$filter")
case "$action" in
	apply | sync) arguments+=(--timeout "${RELEASE_TIMEOUT:-180}") ;;
esac
case "$action" in
	apply | diff) arguments+=(--diff-args=--suppress-secrets) ;;
esac

APP_VERSION="${APP_VERSION:-latest}" run helmfile "${arguments[@]}"
