# Tutorials
Some basic tutorial with this environemnt. 
Especially for using bpftrace.

See below upstream document to get more detail.
- https://github.com/iovisor/bpftrace/blob/master/docs/tutorial_one_liners.md
- https://github.com/iovisor/bpftrace/blob/master/docs/reference_guide.md
- https://github.com/iovisor/bpftrace/tree/master/tools

## About BPF
BPF is event based programming environment in linux.
For tracing we can take the below events.
- kprobe,kretprobe: kernel function
- tracepoint: kernel tracepoint
- uprobe,uretprobe: user function
- USDT: user defined tracepoint

## Tracing process execution

```bash
$ bpftrace -e 'tracepoint:syscalls:sys_enter_exec* { time(); printf("%d ", pid); join(args->argv) }'
Attaching 2 probes...
05:50:41
649573 runc --root /var/run/docker/runtime-runc/moby --log /run/containerd/io.containerd.runtime.v2.task/moby/fc9780e1c63ef6f2e829b13f8477ddfbfff6b4df2daee531b430b42c1e3a224f/log.json --log-format json kill fc9780e1c63ef6f2e829b13f8477ddfbfff6b4df2daee531b430b42c1e3a224f 28
05:50:41
649579 runc --root /var/run/docker/runtime-runc/moby --log /run/containerd/io.containerd.runtime.v2.task/moby/fc9780e1c63ef6f2e829b13f8477ddfbfff6b4df2daee531b430b42c1e3a224f/log.json --log-format json kill fc9780e1c63ef6f2e829b13f8477ddfbfff6b4df2daee531b430b42c1e3a224f 28
```
 
## Tracing bash
Try to snoop bash command inputs in the host machine.

```bash
$ bpftrace -e 'uretprobe:/proc/1/root/bin/bash:readline { time(); printf("%d %d %d: %s\n", uid, gid, pid, str(retval)); }'
Attaching 1 probe...
05:40:19
1002 1002 620276: ls
05:40:27
1002 1002 620276: ps aux
05:40:28
1002 1002 620276: ls
```

## Tracing curl's TLS communication
Let's try to trace TLS communication of curl in the host machine.

Check its TLS dependencies.
```bash
$ chroot /proc/1/root
$ ldd $(which curl) | grep -iE 'ssl|tls'
        libssl.so.1.1 => /lib/aarch64-linux-gnu/libssl.so.1.1 (0x0000ffffbb822000)
```

Now assume that there would be function for encrypt plan text with SSL.
May be the function name contains `enc` or `write`.
```bash
$ bpftrace -l 'uprobe:/proc/1/root/lib/aarch64-linux-gnu/libssl.so.1.1:*' | grep -iE 'write|enc'
uprobe:/proc/1/root/lib/aarch64-linux-gnu/libssl.so.1.1:PEM_write_SSL_SESSION
uprobe:/proc/1/root/lib/aarch64-linux-gnu/libssl.so.1.1:PEM_write_bio_SSL_SESSION
uprobe:/proc/1/root/lib/aarch64-linux-gnu/libssl.so.1.1:SSL_write
uprobe:/proc/1/root/lib/aarch64-linux-gnu/libssl.so.1.1:SSL_write_early_data
uprobe:/proc/1/root/lib/aarch64-linux-gnu/libssl.so.1.1:SSL_write_ex
```

Seems `SSL_write` is what we want.
After searching the function I got its signature.
```
int SSL_write(SSL *ssl, void *buf, int num);
```

The argument buf is key!

```bash
$ bpftrace -e 'uprobe:/proc/1/root/lib/aarch64-linux-gnu/libssl.so.1.1:SSL_write / comm == "curl" / { printf("%r\n", buf(arg1,arg2)); }'
Attaching 1 probe...
```

Let's run curl on host machine like the below
```bash
$ curl --http1.1 -H 'Content-Type:application/json' https://google.com
<HTML><HEAD><meta http-equiv="content-type" content="text/html;charset=utf-8">
<TITLE>301 Moved</TITLE></HEAD><BODY>
<H1>301 Moved</H1>
The document has moved
<A HREF="https://www.google.com/">here</A>.
</BODY></HTML>
```

Then we could see the results.
```
Attaching 1 probe...
Attaching 1 probe...
GET / HTTP/1.1
Host: google.com
User-Agent: curl/7.68.0
Accept: */*
Content-Type:application/json
```

For HTTP2 it uses binary protocol for message we have to parsing it manually.
In this repo, there is simple parser exmample for HTTP2.

```bash
$ bpftrace -e 'uprobe:/proc/1/root/lib/aarch64-linux-gnu/libssl.so.1.1:SSL_write / comm == "curl" / { printf("%r\n", buf(arg1,arg2)) }' | /tmp/parser
Attaching 1 probe...
```
the parser binary takes hex string, we can take it with the function `buf()`.

And run curl again
```bash
$ curl --http2 -H 'Content-Type: application/json' https://google.com
<HTML><HEAD><meta http-equiv="content-type" content="text/html;charset=utf-8">
<TITLE>301 Moved</TITLE></HEAD><BODY>
<H1>301 Moved</H1>
The document has moved
<A HREF="https://www.google.com/">here</A>.
</BODY></HTML>
```

Then it will print decoded texts.
```bash
PRI * HTTP/2.0\x0d\x0a\x0d\x0aSM\x0d\x0a\x0d\x0a
-----START HTTP2 FRAME-----
[FrameHeader SETTINGS len=18]
-----END HTTP2 FRAME-----
-----START HTTP2 FRAME-----
[FrameHeader WINDOW_UPDATE len=4]
-----END HTTP2 FRAME-----
-----START HTTP2 FRAME-----
[FrameHeader HEADERS flags=END_STREAM|END_HEADERS stream=1 len=50]
:method:GET
:path:/
:scheme:https
:authority:google.com
user-agent:curl/7.68.0
accept:*/*
contents-type:application/json
-----END HTTP2 FRAME-----
-----START HTTP2 FRAME-----
[FrameHeader SETTINGS flags=ACK len=0]
-----END HTTP2 FRAME-----
```

## Dump unix domain socket 
There are good BCC tools named `undump`

```bash
$ cd /usr/shar/bcc/example/tracing
$ ./undump.py -p $(pidof dockerd) | grep -v PID | xxd -r -p
GET /v1.40/containers/5ce42941595a71ccec508fcca1fa8d93d5bbaf1517e037a040330fb826738e72/json HTTP/1.1
Host: docker
User-Agent: Go-http-client/1.1

GET /v1.40/containers/e19b89393bd5d0d7b6e403649d1fa716bd956315dacb81fbf1b91b4834c71c2c/json HTTP/1.1
Host: docker
User-Agent: Go-http-client/1.1
```

## Writing kernel event based script
Modern linux kenrel comes with the BTF debug info which has kernel struct and type information. 

Can be checked like the below
```bash
$ cat /boot/config* | grep -i btf
CONFIG_VIDEO_SONY_BTF_MPX=m
CONFIG_DEBUG_INFO_BTF=y
CONFIG_PAHOLE_HAS_SPLIT_BTF=y
CONFIG_DEBUG_INFO_BTF_MODULES=y
```

By default bpftrace take the kernel's BTF debug info.
We can check this with the below command.

```bash
$ bpftool btf dump file /sys/kernel/btf/vmlinux format c > vmlinux.h
```
structs and types in the file is no need to defined from the script.

If there is no proper things. We have to include related kernel headers directly.
