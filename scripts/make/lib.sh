#!/usr/bin/env bash
# Общие функции для задач common/Makefile: выбор пунктов меню и подтверждение.
set -euo pipefail

# Корень проекта (папка, в которой лежит common/)
ROOT="${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"

# choose <подпись> <значение-из-переменной> <варианты...>
# Если значение задано (например, ENV=prod из CI) — проверяет его и возвращает без меню.
# Иначе показывает меню в столбик (в stderr) и читает номер из stdin — работает и в терминале,
# и в консоли запуска IDE, где нет /dev/tty. Печатает выбранный вариант.
choose() {
	local label="$1" preset="$2"
	shift 2
	if [ "$#" -eq 0 ]; then
		echo "Нет вариантов для «$label»" >&2
		exit 1
	fi
	if [ -n "$preset" ]; then
		local option
		for option in "$@"; do
			if [ "$option" = "$preset" ]; then
				echo "$preset"
				return
			fi
		done
		echo "«$preset» нет среди вариантов для «$label»: $*" >&2
		exit 1
	fi
	local PS3="$label: " COLUMNS=1 choice
	select choice in "$@"; do
		if [ -n "$choice" ]; then
			echo "$choice"
			return
		fi
	done
	exit 1
}

# confirm <вопрос> — продолжает только при ответе «y»
confirm() {
	local answer
	read -r -p "$1 [y/N] " answer
	[ "$answer" = "y" ] || { echo "Отменено" >&2; exit 1; }
}

# run <команда...> — печатает команду и выполняет её
run() {
	echo "+ $*" >&2
	"$@"
}
