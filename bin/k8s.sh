#!/usr/bin/env bash
set -eo pipefail

function log {
  >&2 echo "$@"
}

function set_default {
  namespace=default
  tool=dbgenv
  cmd=bash
}

function print_usage {
  echo "$0 [flags] <pod> [command]"
  echo ""
  echo "-t | --tool <tool>            Set tool to use bpftrace,bcc,bpftool"
  echo "-n | --namespace <namespace>  Namespace of a given pod"
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
      -n|--namespace)
        namespace=$2
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

pod=$1
shift
cmd=$@

if [[ ! -z $tool ]]
then
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
fi

name=$tool
node=$(kubectl get pod -n $namespace -o=jsonpath={.spec.nodeName} $pod)

kubectl run -n default $name-$pod \
  --image $image \
  --overrides='{
  "apiVersion": "v1",
  "kind": "Pod",
  "spec": {
    "containers": [
      {
        "name": "'$name-$pod'",
        "image": "'$image'",
        "stdin": true,
        "tty": true,
        "imagePullPolicy": "Always",
        "command": ["/bin/bash"],
        "env": [
          {
            "name": "BPFTRACE_STRLEN", 
            "value": "32" 
          }
        ],
        "securityContext": {
          "allowPrivilegeEscalation": true,
          "privileged": true,
          "capabilities": {
            "add": [
              "NET_ADMIN",
              "SYS_ADMIN",
              "SYS_PTRACE"
            ]
          }
        },
        "volumeMounts": [
          {
            "mountPath": "/etc/os-release",
            "readOnly": true,
            "name": "osrelease"
          },
          {
            "mountPath": "/sys",
            "name": "sys"
          },
          {
            "mountPath": "/usr/src",
            "name": "usrsrc"
          },
          {
            "mountPath": "/lib/modules",
            "name": "libmodules"
          },
          {
            "mountPath": "/boot",
            "readOnly": true,
            "name": "boot"
          }
        ]
      }
    ],
    "hostNetwork": true,
    "hostPID": true,
    "volumes": [
      {
        "hostPath": {
          "path": "/etc/os-release",
          "type": "File"
        },
        "name": "osrelease"
      },
      {
        "hostPath": {
          "path": "/sys",
          "type": "Directory"
        },
        "name": "sys"
      },
      {
        "hostPath": {
          "path": "/usr/src",
          "type": "Directory"
        },
        "name": "usrsrc"
      },
      {
        "hostPath": {
          "path": "/lib/modules",
          "type": "Directory"
        },
        "name": "libmodules"
      },
      {
        "hostPath": {
          "path": "/boot",
          "type": "Directory"
        },
        "name": "boot"
      }
    ],
    "nodeSelector": {
      "kubernetes.io/hostname": "'$node'"
    }
  }
}'

kubectl wait pods -n default -l run=$name-$pod --for condition=Ready --timeout=60s
if [[ $image = *env* ]]
then
  kubectl -n default cp $HOME/.tmux.conf $name-$pod:/root/.tmux.conf
  kubectl -n default cp $HOME/.vimrc $name-$pod:/root/.vimrc
fi
kubectl attach pod -ti -n default $name-$pod
