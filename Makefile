IMAGE_REPOSITORY ?= jseguillon
KERNEL_VERSION ?= 6.12.8
CAPCH_KERNEL_IMAGE ?= $(IMAGE_REPOSITORY)/capch-kernel-$(KERNEL_VERSION)
KUBERNETES_VERSION ?= 1.33
KUBERNETES_DEB_VERSION ?=1.33.5-1.1
CAPCH_ROOTFS_IMAGE ?= $(IMAGE_REPOSITORY)/capch-rootfs-$(KUBERNETES_VERSION)
CAPCH_ROOTFS_CDI_IMAGE ?= $(IMAGE_REPOSITORY)/capch-rootfs-cdi-$(KUBERNETES_VERSION)
CAPCH_DISK_SUDO_PASSWORD ?= password
CAPCH_DISK_IMAGE ?= $(IMAGE_REPOSITORY)/capch-disk-$(KUBERNETES_VERSION)
CAPCH_DISK_CDI_IMAGE ?= $(IMAGE_REPOSITORY)/capch-disk-cdi-$(KUBERNETES_VERSION)

all: push-kernel-amd64 push-kernel-arm4  push-rootfs-amd64 push-rootfs-arm64 push-disk

.PHONY: push-kernel-amd64
push-kernel-amd64:
	docker buildx build --platform linux/amd64 --build-arg KERNEL_VERSION=$(KERNEL_VERSION) -t $(CAPCH_KERNEL_IMAGE) -f kernel/Dockerfile --push .

.PHONY: push-kernel-arm64
push-kernel-armd64:
	docker buildx build --platform linux/arm64 --build-arg KERNEL_VERSION=$(KERNEL_VERSION) -t $(CAPCH_KERNEL_IMAGE) -f kernel/Dockerfile --push .

.PHONY: push-rootfs-amd64
push-rootfs-amd64:
	docker buildx build --platform linux/amd64 --build-arg KUBERNETES_VERSION=$(KUBERNETES_VERSION) --build-arg KUBERNETES_DEB_VERSION=${KUBERNETES_DEB_VERSION} \
	  -f rootfs/Dockerfile --push -t $(CAPCH_ROOTFS_IMAGE) --target virtink-container-rootfs .
	docker buildx build --platform linux/amd64 --build-arg KUBERNETES_VERSION=$(KUBERNETES_VERSION) --build-arg KUBERNETES_DEB_VERSION=${KUBERNETES_DEB_VERSION} \
		-f rootfs/Dockerfile --push -t $(CAPCH_ROOTFS_CDI_IMAGE) .

.PHONY: push-rootfs-arm64
push-rootfs-arm64:
	docker buildx build --platform linux/arm64 --build-arg KUBERNETES_VERSION=$(KUBERNETES_VERSION) --build-arg KUBERNETES_DEB_VERSION=${KUBERNETES_DEB_VERSION} \
	  -f rootfs/Dockerfile --push -t $(CAPCH_ROOTFS_IMAGE) --target virtink-container-rootfs .
	docker buildx build --platform linux/arm64 --build-arg KUBERNETES_VERSION=$(KUBERNETES_VERSION) --build-arg KUBERNETES_DEB_VERSION=${KUBERNETES_DEB_VERSION} \
		-f rootfs/Dockerfile --push -t $(CAPCH_ROOTFS_CDI_IMAGE) .

.PHONY: push-disk
push-disk:
	docker buildx build --build-arg "ARCH=amd64" --build-arg PACKER_GITHUB_API_TOKEN=$(PACKER_GITHUB_API_TOKEN) --build-arg KUBERNETES_VERSION=$(KUBERNETES_VERSION) --build-arg SUDO_PASSWORD=$(CAPCH_DISK_SUDO_PASSWORD) -f disk/Dockerfile.builder -o disk/out/linux/amd64 .
	docker buildx build --build-arg "ARCH=arm64" --build-arg PACKER_GITHUB_API_TOKEN=$(PACKER_GITHUB_API_TOKEN) --build-arg KUBERNETES_VERSION=$(KUBERNETES_VERSION) --build-arg SUDO_PASSWORD=$(CAPCH_DISK_SUDO_PASSWORD) -f disk/Dockerfile.builder -o disk/out/linux/arm64 .

	docker buildx build --platform linux/amd64,linux/arm64 -f disk/Dockerfile --push -t $(CAPCH_DISK_IMAGE) .
	docker buildx build --platform linux/amd64,linux/arm64 -f disk/Dockerfile.cdi --push -t $(CAPCH_DISK_CDI_IMAGE) .
