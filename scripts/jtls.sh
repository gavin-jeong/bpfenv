#!/usr/bin/env bash
set -eo pipefail
PID=$(docker inspect -f '{{.State.Pid}}' $1)

if [[ -z $2 ]]
then
  PID_INSIDE=1
else
  PID_INSIDE=$2
fi

[[ -z $PID ]] && { echo Failed to find PID of $1; exit 1; }

cp /root/extract-tls-secrets-4.0.0.jar /proc/$PID/root/tmp/
nsenter -t $PID -p -- chroot /proc/$PID/root java -jar /tmp/extract-tls-secrets-4.0.0.jar $PID_INSIDE /tmp/secrets.log

echo /proc/$PID/root/tmp/secrets.log
