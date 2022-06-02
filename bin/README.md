# Scripts
Simple helper scripts to run this container to specific environment

## SSH
```bash
$ ./ssh.sh <SSH_HOST> [COMMAND] 
```

If you use bastion host to access the ${SSH_HOST}.
Set proxy command option for direct access.

## Kubernetes
```bash
$ ./k8s.sh <POD> [COMMAND]
```
