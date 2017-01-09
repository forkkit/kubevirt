#!/usr/bin/bash

set -xe

fatal() { echo "FATAL: $@" >&2 ; exit 2 ; }
[[ -f /host/var/run/libvirtd.pid ]] && fatal "libvirtd seems to be running on the host"

# HACK
# Use hosts's /dev to see new devices and allow macvtap
mkdir /dev.container && {
  mount --rbind /dev /dev.container

  mount --rbind /host/dev /dev

  # Keep some devices from the containerinal /dev
  keep() { mount --rbind /dev.container/$1 /dev/$1 ; }
  keep shm
  keep mqueue
  # Keep ptmx/pts for pty creation
  keep pts
  mount --rbind /dev/pts/ptmx /dev/ptmx
  # Use the container /dev/kvm if available
  [[ -e /dev.container/kvm ]] && keep kvm
}

# We create the network on a file basis to not
# have to wait for libvirtd to come up
if [[ -n "$LIBVIRTD_DEFAULT_NETWORK_DEVICE" ]]; then
  mkdir -p /etc/libvirt/qemu/networks/autostart
  cat > /etc/libvirt/qemu/networks/default.xml <<EOX
<!-- Generated by libvirtd.sh container script -->
<network>
  <name>default</name>
  <forward mode="bridge">
    <interface dev="$LIBVIRTD_DEFAULT_NETWORK_DEVICE" />
  </forward>
</network>
EOX
  ln -s /etc/libvirt/qemu/networks/default.xml /etc/libvirt/qemu/networks/autostart/default.xml
fi

/usr/sbin/virtlogd &
/usr/sbin/libvirtd -l