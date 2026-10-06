#!/usr/bin/env bash
# Выпуск kubeconfig для пользователя кластера (сервис-аккаунт из cluster-users) на рабочий стол.
# Переменные: KUBE_USER (по умолчанию devops)
source "$(dirname "$0")/lib.sh"

user="${KUBE_USER:-devops}"
context="$(awk '/kubeContext:/{print $2; exit}' "$ROOT/k8s/helmfile.yaml")"
output="$HOME/Desktop/$user.yaml"
certificate="$(mktemp)"
trap 'rm -f "$certificate"' EXIT

kubectl --context "$context" get secret "$user-token" -n default -o jsonpath='{.data.ca\.crt}' | base64 -d >"$certificate"
server="$(kubectl config view --context "$context" --minify -o jsonpath='{.clusters[0].cluster.server}')"
token="$(kubectl --context "$context" get secret "$user-token" -n default -o jsonpath='{.data.token}' | base64 -d)"

kubectl --kubeconfig="$output" config set-cluster "$context" --server="$server" --certificate-authority="$certificate" --embed-certs=true >/dev/null
kubectl --kubeconfig="$output" config set-credentials "$user" --token="$token" >/dev/null
kubectl --kubeconfig="$output" config set-context default --cluster="$context" --user="$user" >/dev/null
kubectl --kubeconfig="$output" config use-context default >/dev/null

echo "Kubeconfig сохранён в $output"
