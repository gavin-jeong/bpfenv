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

# todo: find java_home from given inner pid
JAVA_HOME=$(nsenter -p -t $PID -- chroot /proc/$PID/root sh -c "type -p java | xargs readlink -f | xargs dirname | xargs dirname")

cp -r $HOME/perf-map-agent /proc/$PID/root/tmp/
nsenter -p -t $PID -- chroot /proc/$PID/root sh -c "cd /tmp/perf-map-agent && /usr/bin/java -cp /tmp/perf-map-agent/attach-main.jar:$JAVA_HOME/lib/tools.jar net.virtualvoid.perf.AttachOnce $PID_INSIDE"
cp /proc/$PID/root/tmp/perf-$PID_INSIDE.map /tmp/perf-$PID.map
