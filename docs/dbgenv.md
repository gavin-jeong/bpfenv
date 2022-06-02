# DBGENV
dbgenv image contains various tracing tools including
- bcc tools
- bpftrace and bpftrace tools
- perf, gdb, strace
- tcpdump, tshark
- vim
- ...

## Attach to host rootfs
Some times we need to access host's rootfs.

```bash
$ nsenter -m -p -t 1 -- chroot /proc/1/root
```

## Trace application by I/O

Usually from application its I/O related function can be traces from system calls the belows

| connection management | recv variants | write variants | special purpose |
| --------------------- | ------------- | -------------- | --------------- |
| connect               | read          | write          | setsockopt      |
| accept                | readv         | writev         | sock_alloc      |
| accept4               | recv          | send           | sock_sendmsg    |
| close                 | recvfrom      | sendto         | sock_recvmsg    |
|                       | recvmsg       | sendmsg        |                 |
|                       | recvmmsg      | sendmmsg       |                 |
|                       |               | sendfile       |                 |

In the dbgenv image, there are some helper script for that.
Currently it supports the below system calls
- setsockopt
- bind
- accept4

```bash
$ ./trace.sh ${PID}
```

## Perf

Record whole system
```bash
$ perf record -F 99 -a -g -- sleep 60
```

Record with specific cgroup
```bash
$ perf record -F 99 -a --cgroup=${CGROUUP_PATH} -- sleep 60
```

## JVM

JVM based application is little hard to investigate.
the dbgenv image contains some helper script for that.

### Dump TLS encrypted traffic
```bash
$ ./jtls.sh <docker container name>
```

It will generate secrets to /proc/${PID_OF_TARGET_CONTAINER}/root/tmp/secrets.log
It can be used like the below from tshark

```
$ tcpdump -i any -U -w - host 10.51.7.72 and not port 3393 and not port 53 and not port 6379 \
| tshark -o tls.keylog_file:/proc/6597/root/tmp/secrets.log -Px -Y http -i -
```

### Create symbol maps for perf and BPF

```bash
$ ./jmaps.sh <docker container name>
```

It assumes jvm process is running under the container with PID 1.
It will generate perf map file to /tmp/perf-${PID_OF_TARGET_CONTAINER}.data, 
which iss used to symbol resolution from perf and BPF.
