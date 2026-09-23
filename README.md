# devops_common

Общий репозиторий для переиспользуемых ansible-ролей, k8s-чартов и скриптов,
подключаемый как git submodule во все devops-проекты.

## Структура

Внутри `common` — те же директории верхнего уровня, что и в корне обычного
devops-проекта, только с содержимым, общим для всех проектов:

```
common/
├── ansible/
│   └── roles/        # общие роли (users, docker, nginx, fail2ban, ...)
├── k8s/
│   └── charts/        # общие helm-чарты (app, ...)
└── scripts/            # общие вспомогательные скрипты
```

## Как подключить в проект

Submodule монтируется в **корень** проекта, ровно под именем `common`, —
это единообразие важно: скрипты и конфиги внутри `common` вычисляют пути
относительно места своего монтирования и ожидают именно такое расположение.

```sh
git submodule add git@github.com:bonavi/devops_common.git common
```

После этого структура devops-проекта должна выглядеть так:

```
<devops-project>/
├── common/       # submodule
├── ansible/
│   ├── config/
│   ├── roles/     # проектные роли, специфичные только для этого проекта
│   └── playbooks/
└── k8s/
    ├── config/
    └── helmfile.yaml
```

## Что класть в common, а что — в проект

- В `common` — то, что можно применить дословно в любом другом devops-проекте:
  установка/хардненинг сервера, docker, nginx, fail2ban, generic-чарт
  приложения, скрипты общего назначения (например, рестор pg-дампа в k8s).
- В проекте — всё, что завязано на конкретный домен, конкретных
  пользователей, конкретную бизнес-логику деплоя.
- Если роль/скрипт нужно обобщить, чтобы вынести в `common` (убрать
  захардкоженные значения, параметризовать), делайте это отдельным шагом
  перед переносом, а не после.

## Деплой docker-compose приложений: `docker-compose-app`

Деплой одиночного docker-compose сервиса всегда одинаковый по шагам:
создать директории, при необходимости засеять конфиги, отрендерить
`docker-compose.yml`, `pull` / `down` / `up -d`. Эта механика вынесена в один
общий tasks-файл — `common/ansible/roles/docker-compose-app/tasks/deploy.yml`.
А вот сам `docker-compose.yml.j2` (и `files/`, если сервису нужны
seed-файлы) — специфичны для каждого приложения и живут в его собственной
роли, а не в `docker-compose-app`.

`docker-compose-app` — **не полноценная роль для вызова через `- role:`**, у
неё нет своих `templates/`/`files/`. Подключается только через
`import_tasks` (не `include_role` — тот меняет контекст роли, и `template:`
внутри искал бы файлы в самой `docker-compose-app`, а не в вызывающей роли):

```yaml
# ansible/roles/xray-agent/tasks/main.yml
- import_tasks: ../../../../common/ansible/roles/docker-compose-app/tasks/deploy.yml
  vars:
    docker_compose_app_name: xray-agent
```

```
# ansible/roles/xray-agent/templates/docker-compose.yml.j2
services:
  xray-agent:
    image: ghcr.io/vpn-tg/xray-agent:latest
    network_mode: host
    environment:
      AUTH_TOKEN: "{{ xray_agent_auth_token }}"
```

Число `../` в `import_tasks` зависит от глубины роли: у ролей проекта
(`ansible/roles/<app>/tasks/main.yml`) их четыре — до корня проекта, потом в
`common/...`; у тонких ролей самого `common` (например `node-exporter`,
лежащей рядом, в `common/ansible/roles/`) — на два уровня меньше, см. её
`tasks/main.yml` как образец.

Если сервису нужны доп. директории или seed-файлы (пример — `3x-ui` с
`x-ui.db`), передайте их через `docker_compose_app_extra_dirs` /
`docker_compose_app_seed_files` в тех же `vars:`, что и `docker_compose_app_name`
(см. `ansible/roles/3x-ui/tasks/main.yml` — там же пример, почему путь к
seed-файлу приходится резолвить через `set_fact` до `import_tasks`: `role_path`
резолвится лениво и в самом `deploy.yml` указывал бы уже не туда).

Если сервис конфигурируется **одинаково на всех проектах** (как
`node-exporter`) — такую роль кладут в `common/ansible/roles`, а не в
проект. Если сервис специфичен для проекта (`3x-ui`, `xray-agent`,
`tg-proxy`, `vue-client` в этом репозитории) — роль остаётся в
`ansible/roles` проекта. В обоих случаях в плейбуке — просто `- role: <app>`,
без переменных в самом плейбуке.

## Ручная выдача сертификатов: `certs-manual`

Альтернатива роли `certs` (реальный `certbot`) для случаев, когда сертификат
выпускать через DNS-01 не нужно/невозможно (dev-окружение, ручная выдача) —
`common/ansible/roles/certs-manual` эмулирует раскладку certbot: копирует
заранее подготовленные файлы в `/etc/letsencrypt/archive/<domain>/` и делает
на них симлинки из `/etc/letsencrypt/live/<domain>/`, тем же способом, что и
сам certbot (`cert1.pem` в archive, `cert.pem` в live как симлинк на него).
Для nginx (и всего остального, что ждёт стандартный letsencrypt-layout)
разницы с настоящим сертификатом нет.

Сами файлы сертификата — секрет конкретного проекта, поэтому в `common` не
хранятся. Роль берёт их с Ansible-контроллера из
`{{ certs_manual_source_dir }}/<domain>/{cert,chain,fullchain,privkey}.pem`
(по умолчанию — `host_vars/<host>/certs-manual/<domain>/...`, тот же
принцип, что и для `env.yml`/`secrets.yml`: всё специфичное для хоста в
одном месте, независимо от того, какой плейбук роль вызвал). Эту директорию
гитигнорите в проекте и наполняете руками. Пример —
`ansible/playbooks/vpn-front/setup-app.yml` в этом репозитории:

```yaml
- name: Seed manual certs
  import_role:
    name: certs-manual
  vars:
    certs_manual_domains:
      - digital-security.pro
```

Файлы для этого примера кладутся в
`ansible/host_vars/vpn-front-digital-security/certs-manual/digital-security.pro/`.

## Как ссылаться на common из проекта

Роли, чарты и скрипты в `common` не публикуются отдельно — на них ссылаются
относительными путями из проектных конфигов, считая, что submodule лежит
в `<корень проекта>/common`:

- **Ansible роли** — добавьте `common/ansible/roles` в `roles_path` в
  `ansible.cfg` (второй путь после проектных ролей), например:
  ```ini
  roles_path = ../roles:../../common/ansible/roles
  ```
  После этого в плейбуках роли из `common` подключаются так же, как
  проектные: `- role: users`.

- **Helm-чарты** — указывайте путь к чарту в `helmfile.yaml` напрямую:
  ```yaml
  chart: ../common/k8s/charts/app
  ```

- **Скрипты** — вызывайте напрямую по относительному пути
  (`../common/scripts/<script>/...`) либо через `common/scripts/Makefile`.
  Скрипты, которым нужен путь к проектным файлам (секреты, конфиги),
  вычисляют корень проекта от собственного расположения (submodule всегда
  в `<корень проекта>/common`), либо принимают путь через переменную
  окружения — смотрите комментарий в шапке конкретного скрипта.

## Обновление common в проекте

```sh
cd common
git pull origin main
cd ..
git add common
git commit -m "update common"
```

## Изменение common

Правьте файлы прямо внутри `common/` любого подключённого проекта, коммитьте
и пушьте из этой директории как из отдельного репозитория. После этого
обновите pointer submodule в проекте (`git add common && git commit`) и,
если правка нужна и в других devops-проектах, обновите там `common` тем же
способом.
