#!/bin/sh
# Имя папки local-path: pvc-<uid>_<namespace>_<pvc>. В именах namespace и
# PVC подчёркиваний не бывает (DNS-1123), поэтому делим по "_".
# volume = pvc-<uid> = имя PV: у одного PVC может остаться папка от прошлого,
# удалённого PV — без volume такие строки совпали бы по меткам.
set -eu
collect() {
  tmp=/www/metrics.tmp
  {
    echo '# HELP local_path_volume_used_bytes Занято в томе local-path (du)'
    echo '# TYPE local_path_volume_used_bytes gauge'
    for d in /storage/pvc-*; do
      [ -d "$d" ] || continue
      name=${d##*/}; volume=${name%%_*}; rest=${name#*_}
      ns=${rest%%_*}; pvc=${rest#*_}
      kb=$(nice -n 19 du -sk "$d" 2>/dev/null | cut -f1) || continue
      echo "local_path_volume_used_bytes{node=\"$NODE_NAME\",volume=\"$volume\",pvc_namespace=\"$ns\",persistentvolumeclaim=\"$pvc\"} $((kb * 1024))"
    done
    echo '# HELP local_path_volume_last_collect_seconds Время последнего подсчёта'
    echo '# TYPE local_path_volume_last_collect_seconds gauge'
    echo "local_path_volume_last_collect_seconds{node=\"$NODE_NAME\"} $(date +%s)"
  } > "$tmp"
  mv "$tmp" /www/metrics
}
collect
( while sleep 300; do collect || true; done ) &
exec httpd -f -p 9101 -h /www
