#!/usr/bin/env bash
# Terraform-модуль проекта: модуль → действие.
# Модуль — папка terraform/<модуль> с *.tf. Переменные: MODULE, ACTION (plan|apply|import)
#
# Окружение модуля — файл terraform/<модуль>/make.env, строки ИМЯ=значение:
#   VAULT_ADDR=https://vault.example.com
#   DIGITALOCEAN_TOKEN=touchkey:<имя в связке>   — секрет читается через touchkey (Touch ID)
# Секреты живут только в env этого запуска: в файлах и в терминале их нет.
#
# import — если в модуле есть import.sh: связывает уже существующие ресурсы
# с конфигом (пишет imports.tf), дальше plan/apply.
source "$(dirname "$0")/lib.sh"

terraform_dir="$ROOT/terraform"
modules="$(cd "$terraform_dir" && for d in */; do ls "$d"*.tf >/dev/null 2>&1 && echo "${d%/}"; done)"
module="$(choose "Модуль" "${MODULE:-}" $modules)" || exit 1
module_dir="$terraform_dir/$module"

actions="plan apply"
[ -x "$module_dir/import.sh" ] && actions="$actions import"
action="$(choose "Действие" "${ACTION:-}" $actions)" || exit 1

# Окружение модуля
if [ -f "$module_dir/make.env" ]; then
	while IFS='=' read -r name value; do
		case "$name" in '' | \#*) continue ;; esac
		if [[ "$value" == touchkey:* ]]; then
			value="$(/usr/local/bin/touchkey get "${value#touchkey:}")" || {
				echo "Нет секрета ${value#touchkey:} в touchkey: touchkey set ${value#touchkey:}" >&2
				exit 1
			}
		fi
		export "$name=$value"
	done <"$module_dir/make.env"
fi

cd "$module_dir"
run terraform init -input=false >/dev/null

case "$action" in
	import) run ./import.sh ;;
	*) run terraform "$action" ;;
esac
