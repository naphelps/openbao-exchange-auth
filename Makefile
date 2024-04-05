SHELL := /bin/bash

# Get Arch for tag and hardware (Golang style) to run test
arch_tag ?= $(shell ./tools/arch-tag)
arch ?= $(arch_tag)

OPENBAO_VERSION ?= v2.0.0-alpha20240329
OPENBAO_GPGKEY ?= "" #C874011F0AB405110D02105534365D9472D7468F
OPENBAO_PLUGIN_HASH := ""

EXECUTABLE := hznbaoauth
DOCKER_INAME ?= openhorizon/$(arch)_bao
VERSION ?= 1.1.3
DEV_VERSION ?=testing
DOCKER_IMAGE_LABELS ?= --label "name=$(arch)_bao" --label "version=$(VERSION)" --label "bao_version=$(OPENBAO_VERSION)" --label "release=$(shell git rev-parse --short HEAD)"

DOCKER_DEV_OPTS ?= --rm --no-cache --build-arg ARCH=$(arch) --build-arg OPENBAO_VERSION=$(OPENBAO_VERSION) --build-arg OPENBAO_GPGKEY=$(VAULT_GPGKEY) --build-arg OPENBAO_PLUGIN_HASH=$(OPENBAO_PLUGIN_HASH)

# license file name
export LICENSE_FILE = LICENSE.txt

COMPILE_ARGS ?= CGO_ENABLED=0 GOARCH=amd64 GOOS=linux

ifndef verbose
.SILENT:
endif

all: $(EXECUTABLE) bao-image
dev: $(EXECUTABLE) bao-dev-image
check: test

clean:
	rm -f ./docker/bin/$(EXECUTABLE)
	-@docker rmi $(DOCKER_INAME):$(VERSION) 2> /dev/null || :
	-@docker rmi $(DOCKER_INAME):testing 2> /dev/null || :

format:
	@echo "Formatting all Golang source code with gofmt"
	find . -name '*.go' -exec gofmt -l -w {} \;

$(EXECUTABLE): $(shell find . -name '*.go')
	@echo "Producing $(EXECUTABLE) for arch: amd64"
	$(COMPILE_ARGS) go build -o ./docker/bin/$(EXECUTABLE)

bao-image: OPENBAO_PLUGIN_HASH=$(shell shasum -a 256 ./docker/bin/$(EXECUTABLE) | awk '{ print $$1 }')

bao-image:
	@echo "Handling $(DOCKER_INAME):$(VERSION) with hash $(OPENBAO_PLUGIN_HASH)"
	if [ -n "$(shell docker images | grep '$(DOCKER_INAME):$(VERSION)')" ]; then \
		echo "Skipping since $(DOCKER_INAME):$(VERSION) image exists, run 'make clean && make' if a rebuild is desired"; \
	elif [[ $(arch) == "amd64" ]]; then \
		echo "Building container image $(DOCKER_INAME):$(VERSION)"; \
		docker build $(DOCKER_DEV_OPTS) $(DOCKER_IMAGE_LABELS) -t $(DOCKER_INAME):$(VERSION) -f docker/Dockerfile.ubi.$(arch) ./docker; \
	else echo "Building the openbao docker image is not supported on $(arch)"; fi

bao-dev-image:
	@echo "Handling $(DOCKER_INAME):$(DEV_VERSION)"
	if [ -n "$(shell docker images | grep '$(DOCKER_INAME):$(DEV_VERSION)')" ]; then \
		echo "Skipping since $(DOCKER_INAME):$(DEV_VERSION) image exists, run 'make clean && make' if a rebuild is desired"; \
	elif [[ $(arch) == "amd64" ]]; then \
		echo "Building container image $(DOCKER_INAME):$(DEV_VERSION)"; \
		docker build $(DOCKER_DEV_OPTS)  $(DOCKER_IMAGE_LABELS) -t $(DOCKER_INAME):$(DEV_VERSION) -f docker/Dockerfile.ubi.$(arch) ./docker; \
	else echo "Building the openbap docker image is not supported on $(arch)"; fi

test:
	@echo "Executing unit tests"
	-@$(COMPILE_ARGS) go test -cover -tags=unit


.PHONY: format
