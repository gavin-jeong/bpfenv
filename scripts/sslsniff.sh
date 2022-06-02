#!/usr/bin/bpftrace
uprobe:/proc/1/root/lib64/libssl.so.10:SSL_write / comm == "curl" / { printf("%r\n", buf(arg1,arg2)); }
