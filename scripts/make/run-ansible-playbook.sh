#!/usr/bin/env bash
# Запуск ansible-плейбука: группа → плейбук → хост («all» — все хосты плейбука).
# Переменные: GROUP, PLAYBOOK, HOST, ANSIBLE_ARGS (доп. аргументы, например «-e key=value»)
source "$(dirname "$0")/lib.sh"

export ANSIBLE_CONFIG="$ROOT/ansible/config/ansible.cfg"
playbooks="$ROOT/ansible/playbooks"

group="$(choose "Группа плейбуков" "${GROUP:-}" $(cd "$playbooks" && ls -d */ | tr -d /))" || exit 1
playbook="$(choose "Плейбук" "${PLAYBOOK:-}" $(cd "$playbooks/$group" && ls *.yml | sed 's/\.yml$//'))" || exit 1
playbook_file="$playbooks/$group/$playbook.yml"

# Хосты, на которые нацелен плейбук (его hosts:), — из инвентаря
target="$(grep -m1 -E '^\s*-?\s*hosts:' "$playbook_file" | sed -E 's/.*hosts:\s*//; s/"//g')"
hosts="$(ansible "$target" --list-hosts 2>/dev/null | tail -n +2 | awk '{print $1}' || true)"
host="$(choose "Хост" "${HOST:-}" all $hosts)" || exit 1

limit=()
[ "$host" = all ] || limit=(-l "$host")
# shellcheck disable=SC2086
run ansible-playbook "$playbook_file" ${limit[@]+"${limit[@]}"} ${ANSIBLE_ARGS:-}
