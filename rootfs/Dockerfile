# -----------------------------------------------------------------------------
# Build Ubuntu rootfs with Kubernetes + containerd from RELEASE TARBALLS
# (no apt Kubernetes packages)
# -----------------------------------------------------------------------------
FROM ubuntu:24.04 AS rootfs

ARG KUBERNETES_VERSION="v1.30.0"
ARG CONTAINERD_VERSION="1.7.20"
ARG RUNC_VERSION="1.1.12"
ARG CNI_PLUGINS_VERSION="v1.5.1"

ENV KUBERNETES_VERSION=${KUBERNETES_VERSION}
ENV CONTAINERD_VERSION=${CONTAINERD_VERSION}
ENV RUNC_VERSION=${RUNC_VERSION}
ENV CNI_PLUGINS_VERSION=${CNI_PLUGINS_VERSION}
ENV ARCH=amd64
ENV K8S_BASE_URL="https://dl.k8s.io/release/${KUBERNETES_VERSION}/bin/linux/${ARCH}"

# Base tools (kept minimal)
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends ca-certificates systemd-sysv udev lsb-release cloud-init sudo curl gnupg skopeo xz-utils iptables && \
    rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# Install containerd + runc from releases
# -----------------------------------------------------------------------------
# containerd
RUN set -eux; \
    cd /usr/local; \
    curl -fsSLO https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-${ARCH}.tar.gz; \
    tar -xzf containerd-${CONTAINERD_VERSION}-linux-${ARCH}.tar.gz; \
    rm containerd-${CONTAINERD_VERSION}-linux-${ARCH}.tar.gz

# systemd unit for containerd
RUN set -eux; \
    mkdir -p /usr/local/lib/systemd/system; \
    curl -fsSL https://raw.githubusercontent.com/containerd/containerd/v${CONTAINERD_VERSION}/containerd.service \
      -o /usr/local/lib/systemd/system/containerd.service

# runc
RUN set -eux; \
    curl -fsSL https://github.com/opencontainers/runc/releases/download/v${RUNC_VERSION}/runc.${ARCH} -o /usr/local/sbin/runc; \
    chmod +x /usr/local/sbin/runc

# CNI plugins
RUN set -eux; \
    mkdir -p /opt/cni/bin; \
    curl -fsSLo /tmp/cni.tgz https://github.com/containernetworking/plugins/releases/download/${CNI_PLUGINS_VERSION}/cni-plugins-linux-${ARCH}-${CNI_PLUGINS_VERSION}.tgz; \
    tar -xzf /tmp/cni.tgz -C /opt/cni/bin; \
    rm -f /tmp/cni.tgz

# containerd config (systemd cgroup)
RUN set -eux; \
    mkdir -p /etc/containerd; \
    /usr/local/bin/containerd config default | sed 's/SystemdCgroup = false/SystemdCgroup = true/' > /etc/containerd/config.toml

# -----------------------------------------------------------------------------
# Install kubeadm/kubectl/kubelet from Kubernetes releases
# -----------------------------------------------------------------------------
RUN set -eux; \
    # binaries
    curl -fsSLo /usr/local/bin/kubeadm  ${K8S_BASE_URL}/kubeadm; \
    curl -fsSLo /usr/local/bin/kubectl  ${K8S_BASE_URL}/kubectl; \
    curl -fsSLo /usr/local/bin/kubelet  ${K8S_BASE_URL}/kubelet; \
    chmod +x /usr/local/bin/kubeadm /usr/local/bin/kubectl /usr/local/bin/kubelet; \
    # kubelet systemd units & drop-in
    mkdir -p /usr/lib/systemd/system /etc/systemd/system/kubelet.service.d; \
    curl -fsSL https://raw.githubusercontent.com/kubernetes/release/${KUBERNETES_VERSION}/cmd/krel/templates/systemd/kubelet.service \
      -o /usr/lib/systemd/system/kubelet.service || \
    curl -fsSL https://raw.githubusercontent.com/kubernetes/release/master/cmd/krel/templates/systemd/kubelet.service \
      -o /usr/lib/systemd/system/kubelet.service; \
    curl -fsSL https://raw.githubusercontent.com/kubernetes/release/${KUBERNETES_VERSION}/cmd/krel/templates/systemd/10-kubeadm.conf \
      -o /etc/systemd/system/kubelet.service.d/10-kubeadm.conf || \
    curl -fsSL https://raw.githubusercontent.com/kubernetes/release/master/cmd/krel/templates/systemd/10-kubeadm.conf \
      -o /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

# Useful kernel/sysctl defaults (commented—uncomment if desired)
# RUN echo "net.bridge.bridge-nf-call-iptables=1\nnet.bridge.bridge-nf-call-ip6tables=1\nnet.ipv4.ip_forward=1" > /etc/sysctl.d/k8s.conf
# RUN echo 'net.ipv4.conf.lxc*.rp_filter=0' > /etc/sysctl.d/99-override_cilium_rp_filter.conf

# Enable services inside the VM (optional—leave commented if your init handles this)
# RUN systemctl enable containerd
# RUN systemctl enable kubelet

# -----------------------------------------------------------------------------
# Pre-pull control-plane images with skopeo using kubeadm's list
# -----------------------------------------------------------------------------
RUN set -eux; \
    mkdir -p /usr/share/capch/images; \
    KUBEADM_VERSION=$(/usr/local/bin/kubeadm version -o short); \
    images=$(/usr/local/bin/kubeadm config images list --kubernetes-version "$KUBEADM_VERSION"); \
    for image in $images; do \
        skopeo copy "docker://$image" "oci-archive:/usr/share/capch/images/$(echo "$image" | sed -r 's/[/:]/_/g').tar:$image"; \
    done

# -----------------------------------------------------------------------------
# Virtink rootfs assembly
# -----------------------------------------------------------------------------
FROM smartxworks/virtink-container-rootfs-base AS virtink-container-rootfs

COPY --from=rootfs / /rootfs

# Basic resolv/hosts setup inside the VM filesystem
RUN ln -sf ../run/systemd/resolve/stub-resolv.conf /rootfs/etc/resolv.conf
RUN echo -e "127.0.0.1 localhost \n\
::1     localhost ip6-localhost ip6-loopback \n\
fe00::0 ip6-localnet \n\
fe00::0 ip6-mcastprefix \n\
fe00::1 ip6-allnodes \n\
fe00::2 ip6-allrouters" > /rootfs/etc/hosts

FROM smartxworks/virtink-container-rootfs-base AS virtink-container-rootfs

COPY --from=rootfs / /rootfs

RUN ln -sf ../run/systemd/resolve/stub-resolv.conf /rootfs/etc/resolv.conf
RUN echo -e "127.0.0.1 localhost \n\
::1     localhost ip6-localhost ip6-loopback \n\
fe00::0 ip6-localnet \n\
fe00::0 ip6-mcastprefix \n\
fe00::1 ip6-allnodes \n\
fe00::2 ip6-allrouters" > /rootfs/etc/hosts

FROM virtink-container-rootfs AS qcow2-rootfs
RUN apk add qemu-img
RUN /entrypoint.sh /rootfs.raw 2G
RUN qemu-img convert -f raw -O qcow2 /rootfs.raw rootfs.qcow2

FROM kubevirt/container-disk-v1alpha

COPY --from=qcow2-rootfs /rootfs.qcow2 /disk/rootfs.qcow2
