#!/usr/bin/env bash
# Разовый рестор бэкапов в postgres.
# Конфигурация — через имена файлов: backups/<db_user>.sql
# (или .dump/.tar/.tar.gz/.gz — накатывается через pg_restore). Имя файла без
# расширения = юзер и БД в postgres (БД называется так же, как её владелец,
# см. ../../config/postgres/init-secret.yaml.gotmpl).
#
# Дамп льётся локальным psql/pg_restore через `kubectl port-forward` до пода
# postgres — обычный TCP-тоннель, устойчивый для больших/долгих передач
# (в отличие от `kubectl exec -i`, чей attach-стрим по WAN рвётся на крупных
# файлах — connection reset by peer).
#
# Требуются локальные psql/pg_restore (brew install libpq).
#
# Один файл в backups/ = один запуск psql/pg_restore = один рестор.
#
# Скрипт общий (лежит в common), а секреты — в конкретном проекте, поэтому
# путь к ним не выводится из расположения скрипта напрямую: common
# монтируется submodule'ом в корень devops-репозитория одинаково во всех
# проектах, так что K8S_DIR по умолчанию — <корень репозитория>/k8s
# (три уровня вверх от скрипта: restorePgsqlDumpInK8S -> scripts -> common
# -> корень репозитория). Можно переопределить через переменную окружения.
# Дампы (backups/) лежат рядом со скриптом, в этом же common-репозитории.
#
# Usage: K8S_DIR=/path/to/k8s ./restore-backups.sh <env: dev|prod>

set -euo pipefail

ENV="${1:?usage: restore-backups.sh <env>}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
K8S_DIR="${K8S_DIR:-$REPO_ROOT/k8s}"
BACKUPS_DIR="${BACKUPS_DIR:-$SCRIPT_DIR/backups}"
NAMESPACE="postgres-${ENV}"
LOCAL_PORT=15432

shopt -s nullglob
FILES=("$BACKUPS_DIR"/*)
if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "No backups found in $BACKUPS_DIR"
  exit 0
fi

POD="$(kubectl get pod -n "$NAMESPACE" \
  -l app.kubernetes.io/name=postgresql,app.kubernetes.io/instance=postgres \
  -o jsonpath='{.items[0].metadata.name}')"
if [[ -z "$POD" ]]; then
  echo "postgres pod not found in $NAMESPACE" >&2
  exit 1
fi

kubectl port-forward -n "$NAMESPACE" "pod/${POD}" "${LOCAL_PORT}:5432" >/tmp/restore-port-forward.log 2>&1 &
PF_PID=$!
trap 'kill $PF_PID 2>/dev/null' EXIT

for _ in $(seq 1 20); do
  if (echo >/dev/tcp/127.0.0.1/"$LOCAL_PORT") 2>/dev/null; then
    break
  fi
  sleep 0.5
done

for FILE in "${FILES[@]}"; do
  BASENAME="$(basename "$FILE")"
  DB_USER="${BASENAME%.*}"
  [[ "$BASENAME" == *.tar.gz ]] && DB_USER="${BASENAME%.tar.gz}"

  PASSWORD="$(sops -d --extract "[\"pgsql\"][\"users\"][\"${DB_USER}\"][\"password\"]" \
    "$K8S_DIR/secrets/secrets-${ENV}.yaml")"

  echo "==> Restoring ${BASENAME} into ${DB_USER}@${NAMESPACE} (pod ${POD})"
  case "$BASENAME" in
    *.sql)
      PGPASSWORD="$PASSWORD" PAGER=cat psql -X -h 127.0.0.1 -p "$LOCAL_PORT" -U "$DB_USER" -d "$DB_USER" \
        -P pager=off -f "$FILE"
      ;;
    *)
      PGPASSWORD="$PASSWORD" pg_restore -h 127.0.0.1 -p "$LOCAL_PORT" -U "$DB_USER" -d "$DB_USER" \
        --no-owner --clean --if-exists "$FILE"
      ;;
  esac
  echo "==> Done: ${BASENAME}"
done
