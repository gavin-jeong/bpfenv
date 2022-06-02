#!/usr/bin/env bash
set -xeo pipefail

function log {
  >&2 echo "$@"
}

function set_default {
  cmd=bash
  tool=dbgenv
}

function print_usage {
  echo "$0 [flags] <pod> [command]"
  echo ""
  echo "-t | --tool <tool>            Set tool to use bpftrace,bcc,bpftool"
  echo "-i | --image <image>          Image to use"
  echo "-h | --help                   This help"
}

function parse_args {
  POSITIONAL_ARGS=()
  
  while [[ $# -gt 0 ]]
  do
    if [[ ! -z $flag_ignore_parse  ]]
    then
        POSITIONAL_ARGS+=("$1")
        shift
        continue
    fi
  
    case $1 in
      -t|--tool)
        tool=$2
        shift
        shift
        ;;
      -i|--image)
        image=$2
        shift
        shift
        ;;
      -h|--help)
        print_usage
        exit 0
        ;;
      --)
        shift
        flag_ignore_parse=1
        ;;
      -*|--*)
        log "Unknown option $1"
        exit 1
        ;;
      *)
        POSITIONAL_ARGS+=("$1")
        shift
        ;;
    esac
  done
}

set_default
parse_args $@
set -- "${POSITIONAL_ARGS[@]}"

node=$1
shift
cmd=$@

case $tool in
  dbgenv)
    image=gavinjeong/dbgenv:latest
    ;;
  bpftrace)
    image=gavinjeong/bpftrace:latest
    ;;
  bcc)
    image=gavinjeong/bcc:latest
    ;;
  bpftool)
    image=gavinjeong/bpftool:latest
    ;;
  *)
    log "Unsupported tool: $tool"
    exit 1
    ;;
esac

container=$tool-$node

docker -H ssh://$node pull $image
docker -H ssh://$node run --name "$container" \
  -tid --rm --init --privileged --pid host --net host \
  -v /etc/os-release:/etc/os-release:ro \
  -v /etc/localtime:/etc/localtime:ro \
  -v /sys:/sys:rw \
  -v /usr/src:/usr/src:rw \
  -v /lib/modules:/lib/modules:rw \
  -v /boot:/boot:ro \
  -v /usr/bin/docker:/usr/bin/docker:ro \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -e BPFTRACE_STRLEN=32 \
  $image $cmd
if [[ $image = *env* ]]
then
  docker -H ssh://$node cp $HOME/.tmux.conf $container:/root/.tmux.conf
  docker -H ssh://$node cp $HOME/.vimrc $container:/root/.vimrc
fi
docker -H ssh://$node attach "$container"
