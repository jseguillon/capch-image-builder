FROM ubuntu:noble AS rootfs

ARG KUBERNETES_VERSION=1.33
ARG KUBERNETES_DEB_VERSION=1.33.5-1.1

RUN apt update -y && \
    apt install -y curl gpg systemd-sysv udev lsb-release cloud-init sudo curl gnupg skopeo systemd-resolved dbus && \
    rm -rf /var/lib/apt/lists/* 

RUN echo "net.bridge.bridge-nf-call-iptables  = 1 \n\
net.bridge.bridge-nf-call-ip6tables = 1 \n\
net.ipv4.ip_forward                 = 1" >> /etc/sysctl.d/k8s.conf

RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
RUN apt update && \
    apt install -y --no-install-recommends containerd.io && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/containerd && containerd config default | sed 's/SystemdCgroup = false/SystemdCgroup = true/' > /etc/containerd/config.toml
RUN systemctl enable containerd
RUN curl -fsSL https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_VERSION}/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg 
RUN echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] \
  https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_VERSION}/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list
RUN apt update -y && \
    apt install -y --no-install-recommends kubelet=${KUBERNETES_DEB_VERSION} kubeadm=${KUBERNETES_DEB_VERSION} kubectl=${KUBERNETES_DEB_VERSION} && \
    rm -rf /var/lib/apt/lists/* && \
    apt-mark hold kubelet kubeadm kubectl

RUN mkdir -p /etc/containerd && \
    containerd config default | sed 's/SystemdCgroup = false/SystemdCgroup = true/' > /etc/containerd/config.toml 
RUN systemctl enable kubelet

RUN rm -Rf /lib/netplan /etc/netplan /run/netplan || true
COPY netplan.cfg /etc/netplan/51-virtink-netplan.yaml 

RUN rm -f /etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg \
    && rm -f /etc/cloud/cloud.cfg.d/99-installer.cfg \
    && rm -f /etc/cloud/cloud.cfg.d/curtin-preserve-sources.cfg \
    && rm -f /etc/cloud/ds-identify.cfg \
    && rm -f /etc/cloud/cloud.cfg.d/90-installer-network.cfg

RUN echo 'net.ipv4.conf.lxc*.rp_filter = 0' > /etc/sysctl.d/99-override_cilium_rp_filter.conf


RUN mkdir -p /usr/share/capch/images && \
    images=$(kubeadm config images list --kubernetes-version stable) && \
    for image in $images; do \
        skopeo copy docker://$image oci-archive:/usr/share/capch/images/$(echo $image | sed -r 's/[/:]/_/g').tar:$image; \
    done

RUN update-alternatives --set iptables /usr/sbin/iptables-legacy && \
    update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy

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
