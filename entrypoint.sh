#!/usr/bin/env bash

function setup_amazon_kernel_package {
  apt update -y
  apt install -y wget sqlite3 rpm gzip

  KERNEL_VERSION=$(uname -r)
  KERNEL_MAJOR_VERSION=$(uname -r | cut -d. -f1,2)
  ARCH=$(uname -m)

  case $KERNEL_VERSION in
    4.*)
      MIRROR_LIST_URL=amazonlinux.us-east-1.amazonaws.com/2/core/latest/${ARCH}/mirror.list
      ;;
    5.*)
      MIRROR_LIST_URL=amazonlinux.us-east-1.amazonaws.com/2/extras/kernel-$(cut -d. -f1,2<<<$KERNEL_MAJOR_VERSION)/latest/${ARCH}/mirror.list
      ;;
  esac

  # Fetch package DB
  wget "${MIRROR_LIST_URL}" 
  [[ ! -f mirror.list  ]] && echo "Failed to fetch mirror list" && exit 1

  wget "$(head -1 mirror.list)/repodata/primary.sqlite.gz"
  [[ ! -f primary.sqlite.gz ]] && echo "Failed to get package DB" && exit 1
  gzip -d primary.sqlite.gz

  VERSION=${KERNEL_VERSION%%-*}
  RELEASE=${KERNEL_VERSION%%.$(uname -m)}
  RELEASE=${RELEASE##*-}
  wget amazonlinux.us-east-1.amazonaws.com/$(sqlite3 primary.sqlite \
    "SELECT location_href FROM packages WHERE name LIKE 'kernel-devel' AND name NOT LIKE '%tools%' AND name NOT LIKE '%doc%' AND version='${VERSION}' AND release='${RELEASE}'" | \
    sed 's#\.\./##g')

  wget amazonlinux.us-east-1.amazonaws.com/$(sqlite3 primary.sqlite \
    "SELECT location_href FROM packages WHERE name LIKE 'kernel-headers' AND name NOT LIKE '%tools%' AND name NOT LIKE '%doc%' AND version='${VERSION}' AND release='${RELEASE}'" | \
    sed 's#\.\./##g')
  
  rpm --nodeps -i kernel-devel*.rpm
  rpm --nodeps -i kernel-headers*.rpm
}

function main
{
  if [[ -e "/lib/modules/$(uname -r)/build" ]]
  then
    exec $@
  fi

  OSNAME=$(grep -E ^NAME= /etc/os-release | cut -d= -f2)
  case $OSNAME in
    *Amazon*)
      setup_amazon_kernel_package
      ;;
    *)
      ;;
  esac

  exec $@
}

main $@
