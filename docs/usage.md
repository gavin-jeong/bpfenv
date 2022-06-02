# Usage
All details are in its official repository
- bpftrace: https://github.com/iovisor/bpftrace/blob/master/docs/reference_guide.md
- bcc: https://github.com/iovisor/bcc/blob/master/docs/reference_guide.md

Here I describe some tips for this environment. 
There are some points to care cause it runs under container.

## With Userspace probes
Especially some probes like "uprobe" is depends its root filesystem,
We should take probe information from the target pid or binary in its own file system.

For example let's see diff of the script [bashreadline.bt](https://github.com/iovisor/bpftrace/blob/v0.15.0/tools/bashreadline.bt)
```diff
BEGIN
{
	printf("Tracing bash commands... Hit Ctrl-C to end.\n");
	printf("%-9s %-6s %s\n", "TIME", "PID", "COMMAND");
}

-uretprobe:/bin/bash:readline
+uretprobe:/proc/1/root/bash:readline
{
	time("%H:%M:%S  ");
	printf("%-6d %s\n", pid, str(retval));
}
```

This change allow to script to snoop how the host machine's bash binary is used.

The above is same to BCC as well.
See another diff for the script [sslsniff.py](https://github.com/iovisor/bcc/blob/v0.24.0/tools/sslsniff.py)
```diff
if args.openssl:
-    b.attach_uprobe(name="ssl", sym="SSL_write", fn_name="probe_SSL_write",
+    b.attach_uprobe(name="/proc/1/root/lib/aarch64-linux-gnu/libssl.so.1.1", sym="SSL_write", fn_name="probe_SSL_write",
                    pid=args.pid or -1)
-    b.attach_uprobe(name="ssl", sym="SSL_read", fn_name="probe_SSL_read_enter",
+    b.attach_uprobe(name="/proc/1/root/lib/aarch64-linux-gnu/libssl.so.1.1", sym="SSL_read", fn_name="probe_SSL_read_enter",
                    pid=args.pid or -1)
-    b.attach_uretprobe(name="ssl", sym="SSL_read",
+    b.attach_uretprobe(name="/proc/1/root/lib/aarch64-linux-gnu/libssl.so.1.1", sym="SSL_read",
                       fn_name="probe_SSL_read_exit", pid=args.pid or -1)
```
Actually many of prebuilt tools have a option for setting custom binary target, better to use the option.

## Find probes to use
So how we can check what of lib or binaries we have to use? And what probes?

### With PID
We can take all related probe from its PID like the below.
```bash
$ bpftrace -lp 7728 | head
uprobe:/proc/7728/root/usr/sbin/nginx:__libc_csu_fini
uprobe:/proc/7728/root/usr/sbin/nginx:__libc_csu_init
uprobe:/proc/7728/root/usr/sbin/nginx:_start
uprobe:/proc/7728/root/usr/sbin/nginx:main
uprobe:/proc/7728/root/usr/sbin/nginx:ngx_accept_log_error
uprobe:/proc/7728/root/usr/sbin/nginx:ngx_add_channel_event
uprobe:/proc/7728/root/usr/sbin/nginx:ngx_add_module
uprobe:/proc/7728/root/usr/sbin/nginx:ngx_add_path
uprobe:/proc/7728/root/usr/sbin/nginx:ngx_alloc
uprobe:/proc/7728/root/usr/sbin/nginx:ngx_alloc_chain_link
```

We can also use this `-p` flag for tracing as well. 
But unfortunately in bpftrace, there are no option like `-f` in strace.
So better use exact binary location instead, and filter it with `comm`.

### With binary
If there is no running process now. We should take a look how the target program will be executed.

For example let's try to trace what the host machine's `curl` does.

```bash
$ chroot /proc/1/root
$ ldd $(which curl)
        linux-vdso.so.1 (0x0000ffffbbccf000)
        libcurl.so.4 => /lib/aarch64-linux-gnu/libcurl.so.4 (0x0000ffffbbbb2000)
        libz.so.1 => /lib/aarch64-linux-gnu/libz.so.1 (0x0000ffffbbb88000)
        libpthread.so.0 => /lib/aarch64-linux-gnu/atomics/libpthread.so.0 (0x0000ffffbbb59000)
        libc.so.6 => /lib/aarch64-linux-gnu/atomics/libc.so.6 (0x0000ffffbb9e8000)
        /lib/ld-linux-aarch64.so.1 (0x0000ffffbbc9f000)
        libnghttp2.so.14 => /lib/aarch64-linux-gnu/libnghttp2.so.14 (0x0000ffffbb9b1000)
        libidn2.so.0 => /lib/aarch64-linux-gnu/libidn2.so.0 (0x0000ffffbb983000)
        librtmp.so.1 => /lib/aarch64-linux-gnu/librtmp.so.1 (0x0000ffffbb957000)
        libssh.so.4 => /lib/aarch64-linux-gnu/libssh.so.4 (0x0000ffffbb8dd000)
        libpsl.so.5 => /lib/aarch64-linux-gnu/libpsl.so.5 (0x0000ffffbb8bc000)
        libssl.so.1.1 => /lib/aarch64-linux-gnu/libssl.so.1.1 (0x0000ffffbb822000)
        libcrypto.so.1.1 => /lib/aarch64-linux-gnu/libcrypto.so.1.1 (0x0000ffffbb594000)
        libgssapi_krb5.so.2 => /lib/aarch64-linux-gnu/libgssapi_krb5.so.2 (0x0000ffffbb53c000)
        libldap_r-2.4.so.2 => /lib/aarch64-linux-gnu/libldap_r-2.4.so.2 (0x0000ffffbb4d9000)
        liblber-2.4.so.2 => /lib/aarch64-linux-gnu/liblber-2.4.so.2 (0x0000ffffbb4ba000)
        libbrotlidec.so.1 => /lib/aarch64-linux-gnu/libbrotlidec.so.1 (0x0000ffffbb49f000)
        libunistring.so.2 => /lib/aarch64-linux-gnu/libunistring.so.2 (0x0000ffffbb316000)
        libgnutls.so.30 => /lib/aarch64-linux-gnu/libgnutls.so.30 (0x0000ffffbb125000)
        libhogweed.so.5 => /lib/aarch64-linux-gnu/libhogweed.so.5 (0x0000ffffbb0df000)
        libnettle.so.7 => /lib/aarch64-linux-gnu/libnettle.so.7 (0x0000ffffbb099000)
        libgmp.so.10 => /lib/aarch64-linux-gnu/libgmp.so.10 (0x0000ffffbb012000)
        libdl.so.2 => /lib/aarch64-linux-gnu/atomics/libdl.so.2 (0x0000ffffbaffe000)
        libkrb5.so.3 => /lib/aarch64-linux-gnu/libkrb5.so.3 (0x0000ffffbaf16000)
        libk5crypto.so.3 => /lib/aarch64-linux-gnu/libk5crypto.so.3 (0x0000ffffbaed9000)
        libcom_err.so.2 => /lib/aarch64-linux-gnu/libcom_err.so.2 (0x0000ffffbaec5000)
        libkrb5support.so.0 => /lib/aarch64-linux-gnu/libkrb5support.so.0 (0x0000ffffbaea8000)
        libresolv.so.2 => /lib/aarch64-linux-gnu/atomics/libresolv.so.2 (0x0000ffffbae82000)
        libsasl2.so.2 => /lib/aarch64-linux-gnu/libsasl2.so.2 (0x0000ffffbae57000)
        libgssapi.so.3 => /lib/aarch64-linux-gnu/libgssapi.so.3 (0x0000ffffbae09000)
        libbrotlicommon.so.1 => /lib/aarch64-linux-gnu/libbrotlicommon.so.1 (0x0000ffffbadd8000)
        libp11-kit.so.0 => /lib/aarch64-linux-gnu/libp11-kit.so.0 (0x0000ffffbac8c000)
        libtasn1.so.6 => /lib/aarch64-linux-gnu/libtasn1.so.6 (0x0000ffffbac69000)
        libkeyutils.so.1 => /lib/aarch64-linux-gnu/libkeyutils.so.1 (0x0000ffffbac54000)
        libheimntlm.so.0 => /lib/aarch64-linux-gnu/libheimntlm.so.0 (0x0000ffffbac3a000)
        libkrb5.so.26 => /lib/aarch64-linux-gnu/libkrb5.so.26 (0x0000ffffbab9c000)
        libasn1.so.8 => /lib/aarch64-linux-gnu/libasn1.so.8 (0x0000ffffbaaf7000)
        libhcrypto.so.4 => /lib/aarch64-linux-gnu/libhcrypto.so.4 (0x0000ffffbaab0000)
        libroken.so.18 => /lib/aarch64-linux-gnu/libroken.so.18 (0x0000ffffbaa8a000)
        libffi.so.7 => /lib/aarch64-linux-gnu/libffi.so.7 (0x0000ffffbaa71000)
        libwind.so.0 => /lib/aarch64-linux-gnu/libwind.so.0 (0x0000ffffbaa36000)
        libheimbase.so.1 => /lib/aarch64-linux-gnu/libheimbase.so.1 (0x0000ffffbaa17000)
        libhx509.so.5 => /lib/aarch64-linux-gnu/libhx509.so.5 (0x0000ffffba9bd000)
        libsqlite3.so.0 => /lib/aarch64-linux-gnu/libsqlite3.so.0 (0x0000ffffba88b000)
        libcrypt.so.1 => /lib/aarch64-linux-gnu/libcrypt.so.1 (0x0000ffffba842000)
        libm.so.6 => /lib/aarch64-linux-gnu/atomics/libm.so.6 (0x0000ffffba796000)
```

Let's try to snoop TLS communication of curl.
We could checked that curl uses the libssl library below.
```bash
        libssl.so.1.1 => /lib/aarch64-linux-gnu/libssl.so.1.1 (0x0000ffffbb822000)
```

List some uprobe probes from the library.
```bash
$ bpftrace -l 'uprobe:/proc/1/root/lib/aarch64-linux-gnu/libssl.so.1.1:*' | head
uprobe:/proc/1/root/lib/aarch64-linux-gnu/libssl.so.1.1:BIO_f_ssl
uprobe:/proc/1/root/lib/aarch64-linux-gnu/libssl.so.1.1:BIO_new_buffer_ssl_connect
uprobe:/proc/1/root/lib/aarch64-linux-gnu/libssl.so.1.1:BIO_new_ssl
uprobe:/proc/1/root/lib/aarch64-linux-gnu/libssl.so.1.1:BIO_new_ssl_connect
uprobe:/proc/1/root/lib/aarch64-linux-gnu/libssl.so.1.1:BIO_ssl_copy_session_id
uprobe:/proc/1/root/lib/aarch64-linux-gnu/libssl.so.1.1:BIO_ssl_shutdown
uprobe:/proc/1/root/lib/aarch64-linux-gnu/libssl.so.1.1:DTLS_client_method
uprobe:/proc/1/root/lib/aarch64-linux-gnu/libssl.so.1.1:DTLS_get_data_mtu
uprobe:/proc/1/root/lib/aarch64-linux-gnu/libssl.so.1.1:DTLS_method
uprobe:/proc/1/root/lib/aarch64-linux-gnu/libssl.so.1.1:DTLS_server_method
```

## ARM vs x86
There are some difference between arm64 and x86.
For example there is no trace point `open` in arm64.
So tools like `opensnoop` not working well without the changes below. 
```diff
...
-tracepoint:syscalls:sys_enter_open
...
-tracepoint:syscalls:sys_exit_open
...
```

## With VM based languages

Languages like Java, Python, NodeJS, Shell Script need some precondition to trace its function.
Most of them relies on USDT, we can check that like the below.
```bash
$ bpftrace -l 'usdt:/proc/1/root/usr/bin/python3:*'
usdt:/proc/1/root/usr/bin/python3:python:audit
usdt:/proc/1/root/usr/bin/python3:python:function__entry
usdt:/proc/1/root/usr/bin/python3:python:function__return
usdt:/proc/1/root/usr/bin/python3:python:gc__done
usdt:/proc/1/root/usr/bin/python3:python:gc__start
usdt:/proc/1/root/usr/bin/python3:python:import__find__load__done
usdt:/proc/1/root/usr/bin/python3:python:import__find__load__start
usdt:/proc/1/root/usr/bin/python3:python:line
```

If there is no list of probe, you have to check the belows
- What kind of python implementation it uses?
- What kind of build option is used to build the python?

```python
>>> import platform
>>> platform.python_implementation()
'CPython'
```
'CPython'

```python
>>> import sysconfig
>>> print(sysconfig.get_config_var('CONFIG_ARGS'))
"'--enable-shared' '--prefix=/usr' '--enable-ipv6' '--enable-loadable-sqlite-extensions' '--with-dbmliborder=bdb:gdbm' '--with-computed-gotos' '--without-ensurepip' '--with-system-expat' '--with-dtrace' '--with-system-libmpdec' '--with-system-ffi' 'CC=aarch64-linux-gnu-gcc' 'CFLAGS=-g   -fstack-protector-strong -Wformat -Werror=format-security ' 'LDFLAGS=-Wl,-Bsymbolic-functions  -Wl,-z,relro -g -fwrapv -O2   ' 'CPPFLAGS=-Wdate-time -D_FORTIFY_SOURCE=2'"
```
See it is built with the flag '--with-dtrace'

In this case we could trace its function call with below script.
```bash
$ bpftrace --usdt-file-activation -e 'usdt:/proc/1/root/usr/bin/python3:python:function__entry* { printf("%s:%s:%d\n", str(arg0), str(arg1), arg2); }'
```
