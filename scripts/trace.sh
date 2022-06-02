#!/usr/bin/env bash

export KERNEL=$(uname -r)
export ARCH=$(uname -m)

bpftrace \
-I/lib/modules/$KERNEL/build/arch/${ARCH%%_*}/include \
-I/lib/modules/$KERNEL/build/arch/${ARCH%%_*}/include/uapi \
-I/lib/modules/$KERNEL/build/arch/${ARCH%%_*}/include/generated \
-I/lib/modules/$KERNEL/build/arch/${ARCH%%_*}/include/generated/uapi \
-e '
#include <linux/in.h>
#include <linux/in6.h>

BEGIN
{
       @fam2str[AF_UNSPEC] = "AF_UNSPEC";
       @fam2str[AF_UNIX] = "AF_UNIX";
       @fam2str[AF_INET] = "AF_INET";
       @fam2str[AF_INET6] = "AF_INET6";
}


tracepoint:syscalls:sys_enter_setsockopt
/pid == '$1'/
{
       // socket opts: https://elixir.bootlin.com/linux/v5.18.7/source/include/uapi/linux/tcp.h#L92     

       $fd = args->fd;
       $optname = args->optname;
       $optval = args->optval;
       $optval_int = *$optval;
       $optlen = args->optlen;
       printf("\n########## setsockopt() ##########\n");
       printf("comm:%-16s: setsockopt: fd=%d, optname=%d, optval=%d, optlen=%d. stack: %s\n", comm, $fd, $optname, $optval_int, $optlen, ustack);
}

tracepoint:syscalls:sys_enter_bind
/pid == '$1'/
{
       // printf("bind");
       $sa = (struct sockaddr *)args->umyaddr;
       $fd = args->fd;
       printf("\n########## bind() ##########\n");

       if ($sa->sa_family == AF_INET || $sa->sa_family == AF_INET6) {

              // printf("comm:%-16s: bind AF_INET(6): %-6d %-16s %-3d \n", comm, pid, comm, $sa->sa_family);
              if ($sa->sa_family == AF_INET) { //IPv4
                     $s = (struct sockaddr_in *)$sa;
                     $port = ($s->sin_port >> 8) |
                         (($s->sin_port << 8) & 0xff00);
                     $bind_ip = ntop(AF_INET, $s->sin_addr.s_addr);                         
                     printf("comm:%-16s: bind AF_INET: ip:%-16s port:%-5d fd=%d \n", comm,
                         $bind_ip,
                         $port, $fd);
              } else { //IPv6
                     $s6 = (struct sockaddr_in6 *)$sa;
                     $port = ($s6->sin6_port >> 8) |
                         (($s6->sin6_port << 8) & 0xff00);
                     $bind_ip = ntop(AF_INET6, $s6->sin6_addr.in6_u.u6_addr8);
                     printf("comm:%-16s: bind AF_INET6:%-16s %-5d \n", comm,
                         $bind_ip,
                         $port);
              }
              printf("stack: %s\n", ustack);

              // @bind[comm, args->uservaddr->sa_family,
              //        @fam2str[args->uservaddr->sa_family]] = count();

       }      
}

//tracepoint:syscalls:sys_enter_accept,
tracepoint:syscalls:sys_enter_accept4
/pid == '$1'/
{
       @sockaddr[tid] = args->upeer_sockaddr;
}


//tracepoint:syscalls:sys_exit_accept,
tracepoint:syscalls:sys_exit_accept4
/pid == '$1'/
{
       if( @sockaddr[tid] != 0 ) {
              $sa = (struct sockaddr *)@sockaddr[tid];
              if ($sa->sa_family == AF_INET || $sa->sa_family == AF_INET6) {
                     printf("\n########## exit accept4() ##########\n");

                     printf("accept4: pid:%-6d comm:%-16s family:%-3d ", pid, comm, $sa->sa_family);
                     $error = args->ret;

                     if ($sa->sa_family == AF_INET) { //IPv4
                            $s = (struct sockaddr_in *)@sockaddr[tid];
                            $port = ($s->sin_port >> 8) |
                            (($s->sin_port << 8) & 0xff00);
                            printf("peerIP:%-16s peerPort:%-5d fd:%d\n",
                            ntop(AF_INET, $s->sin_addr.s_addr),
                            $port, $error);
                            printf("stack: %s\n", ustack);
                     } else { //IPv6
                            $s6 = (struct sockaddr_in6 *)@sockaddr[tid];
                            $port = ($s6->sin6_port >> 8) |
                            (($s6->sin6_port << 8) & 0xff00);
                            printf("%-16s %-5d %d\n",
                            ntop(AF_INET6, $s6->sin6_addr.in6_u.u6_addr8),
                            $port, $error);
                            printf("stack: %s\n", ustack);
                     }
              }

              delete(@sockaddr[tid]);
       }
}

END
{
       clear(@sockaddr);
       clear(@fam2str);
}'
