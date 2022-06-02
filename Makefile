NAMESPACE=gavinjeong
BASE=focal
BPFTRACE_VERSION=v0.15.0
BCC_VERSION=v0.24.0
BPFTOOL_VERSION=v6.8.0
LLVM_VERSION=12

FUNC_SUBSTRING=$(word $2,$(subst /, ,$1))
FUNC_USE_LEGACY_ARCH_NAME=$(subst arm64,aarch64,$(subst amd64,x86_64,$1))

TARGET=$(call FUNC_SUBSTRING,$@,1)
ARCH=$(call FUNC_SUBSTRING,$@,2)
COMMON_TAG_POSTFIX=$(BASE)-$(ARCH)

dbgenv/arm64 dbgenv/amd64: ## Build dbgenv 
	docker build \
		--platform linux/$(ARCH) \
		--build-arg BUILD_BASE=$(NAMESPACE)/bpf-base:$(BCC_VERSION)-$(COMMON_TAG_POSTFIX) \
		--build-arg BASE=$(NAMESPACE)/bpftrace:$(BPFTRACE_VERSION)-$(COMMON_TAG_POSTFIX) \
		--build-arg LLVM_VERSION=$(LLVM_VERSION) \
		--build-arg ARCH=$(call FUNC_USE_LEGACY_ARCH_NAME,$(call FUNC_SUBSTRING,$@,2)) \
		--build-arg BPFTOOL_VERSION=$(BPFTOOL_VERSION) \
		-t $(NAMESPACE)/$(TARGET):latest-$(COMMON_TAG_POSTFIX) \
		-f Dockerfile.$(TARGET) \
		.
.PHONY=dbgenv/arm64 dbgenv/amd64

bpftrace/arm64 bpftrace/amd64: ## Build bpftrace
	docker build \
		--platform linux/$(ARCH) \
		--build-arg BPFTRACE_VERSION=$(BPFTRACE_VERSION) \
		--build-arg BUILD_BASE=$(NAMESPACE)/bpf-base:$(BCC_VERSION)-$(COMMON_TAG_POSTFIX) \
		--build-arg BASE=ubuntu:$(BASE) \
		-t $(NAMESPACE)/$(TARGET):$(BPFTRACE_VERSION)-$(COMMON_TAG_POSTFIX) \
		-f Dockerfile.$(TARGET) \
		.
.PHONY=bpftrace/arm64 bpftrace/amd64

bcc/arm64 bcc/amd64: ## Build bpftrace
	docker build \
		--platform linux/$(ARCH) \
		--build-arg BUILD_BASE=$(NAMESPACE)/bpf-base:$(BCC_VERSION)-$(COMMON_TAG_POSTFIX) \
		--build-arg BASE=ubuntu:$(BASE) \
		--build-arg LLVM_VERSION=$(LLVM_VERSION) \
		-t $(NAMESPACE)/$(TARGET):$(BCC_VERSION)-$(COMMON_TAG_POSTFIX) \
		-f Dockerfile.$(TARGET) \
		.
.PHONY=bcc/arm64 bcc/amd64

bpftool/arm64 bpftool/amd64: ## Build bpftool
	docker build \
		--platform linux/$(ARCH) \
		--build-arg BUILD_BASE=$(NAMESPACE)/bpf-base:$(BCC_VERSION)-$(COMMON_TAG_POSTFIX) \
		--build-arg BASE=ubuntu:$(BASE) \
		--build-arg BPFTOOL_VERSION=$(BPFTOOL_VERSION) \
		-t $(NAMESPACE)/$(TARGET):$(BPFTOOL_VERSION)-$(COMMON_TAG_POSTFIX) \
		-f Dockerfile.$(TARGET) \
		.
.PHONY=bpftool/arm64 bpftool/amd64

base/arm64 base/amd64: ## Build base image
	docker build \
		--platform linux/$(ARCH) \
		--build-arg BASE=$(NAMESPACE)/bpf-llvm:$(LLVM_VERSION)-$(COMMON_TAG_POSTFIX) \
		--build-arg BCC_VERSION=$(BCC_VERSION) \
		-t $(NAMESPACE)/bpf-$(TARGET):$(BCC_VERSION)-$(COMMON_TAG_POSTFIX) \
		-f Dockerfile.$(TARGET) .
.PHONY=base/arm64 base/amd64

llvm/arm64 llvm/amd64: ## Build LLVM base
	docker build \
		--platform linux/$(ARCH) \
		--build-arg ARCH=$(call FUNC_USE_LEGACY_ARCH_NAME,$(call FUNC_SUBSTRING,$@,2)) \
		--build-arg BASE=ubuntu:$(BASE) \
		--build-arg LLVM_VERSION=$(LLVM_VERSION) \
		-t $(NAMESPACE)/bpf-$(TARGET):$(LLVM_VERSION)-$(COMMON_TAG_POSTFIX) \
		-f Dockerfile.$(TARGET) .
.PHONY=llvm/amd64 llvm/adm64

test: ## Test with the image
	@test $(IMAGE) || { echo "Need to set IMAGE"; exit 1; }
	docker run \
	-ti --rm --init --privileged --pid host --net host \
	-e /etc/os-release:/etc/os-release:ro \
	-v /etc/localtime:/etc/localtime:ro \
	-v /sys:/sys:rw \
	-v /usr/src:/usr/src:rw \
	-v /lib/modules:/lib/modules:rw \
	-v /boot:/boot:ro \
	-v /usr/bin/docker:/usr/bin/docker:ro \
	-v /var/run/docker.sock:/var/run/docker.sock:ro \
	$(IMAGE) bash

version: ## Print version
	@case $(TARGET) in \
		bcc) \
			echo $(BCC_VERSION); \
			;; \
		bpftrace) \
			echo $(BPFTRACE_VERSION); \
			;; \
		bpftool) \
			echo $(BPFTOOL_VERSION); \
			;; \
		dgbenv) \
			echo latest; \
			;; \
	esac

manifest: ## Create/Push manifest
	@for target in bcc bpftrace bpftool dbgenv; \
	do \
		echo docker manifest create $(NAMESPACE)/$$target:latest \
			--amend $(NAMESPACE)/$$target:$$(make version TARGET=$$target)-$(BASE)-amd64 \
			--amend $(NAMESPACE)/$$target:$$(make version TARGET=$$target)-$(BASE)-arm64; \
		echo docker manifest push $(NAMESPACE)/$$target:latest; \
	done

help: ## This help
	@awk -F ':|##' '/^[^\t].+?:.*?##/ {\
		printf "\033[36m%-30s\033[0m %s\n", $$1, $$NF \
	}' $(MAKEFILE_LIST)
.DEFAULT_GOAL=help
.PHONY=help
