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

# load_sops_key — даёт sops ключ проекта. Если задан SOPS_KEYCHAIN_SERVICE, читает его из Keychain
# один раз на запуск: helmfile расшифровывает несколько раз, а пароль спросится один раз.
# Иначе, как раньше и как в CI, берёт файл k8s/secrets/key.txt
load_sops_key() {
	if [ -z "${SOPS_KEYCHAIN_SERVICE:-}" ] || ! command -v security >/dev/null; then
		export SOPS_AGE_KEY_FILE="$ROOT/k8s/secrets/key.txt"
		return
	fi
	unset SOPS_AGE_KEY_FILE
	SOPS_AGE_KEY="$(security find-generic-password -a "$USER" -s "$SOPS_KEYCHAIN_SERVICE" -w)" || {
		echo "Не удалось прочитать ключ $SOPS_KEYCHAIN_SERVICE из Keychain" >&2
		exit 1
	}
	export SOPS_AGE_KEY
}
