#!/usr/bin/make -f

PACKAGES_SIMTEST=$(shell go list ./... | grep '/simulation')
COMMIT := $(shell git log -1 --format='%H')
DOCKER := $(shell which docker)
LEDGER_ENABLED ?= true
BINDIR ?= $(GOPATH)/bin
BUILD_DIR = ./build
VERSION = v0.0.1-alpha.7

export GO111MODULE = on

# process build tags

# don't override user values
ifeq (,$(VERSION))
  VERSION := $(shell git describe --tags --always)
  # if VERSION is empty, then populate it with branch's name and raw commit hash
  ifeq (,$(VERSION))
    VERSION := $(BRANCH)-$(COMMIT)
  endif
endif

build_tags = netgo
ifeq ($(LEDGER_ENABLED),true)
  ifeq ($(OS),Windows_NT)
    GCCEXE = $(shell where gcc.exe 2> NUL)
    ifeq ($(GCCEXE),)
      $(error gcc.exe not installed for ledger support, please install or set LEDGER_ENABLED=false)
    else
      build_tags += ledger
    endif
  else
    UNAME_S = $(shell uname -s)
    ifeq ($(UNAME_S),OpenBSD)
      $(warning OpenBSD detected, disabling ledger support (https://github.com/cosmos/cosmos-sdk/issues/1988))
    else
      GCC = $(shell command -v gcc 2> /dev/null)
      ifeq ($(GCC),)
        $(error gcc not installed for ledger support, please install or set LEDGER_ENABLED=false)
      else
        build_tags += ledger
      endif
    endif
  endif
endif

ifeq ($(WITH_CLEVELDB),yes)
  build_tags += gcc
endif
build_tags += $(BUILD_TAGS)
build_tags := $(strip $(build_tags))

whitespace :=
empty = $(whitespace) $(whitespace)
comma := ,
build_tags_comma_sep := $(subst $(empty),$(comma),$(build_tags))

ldflags = -X github.com/cosmos/cosmos-sdk/version.Name=manifest \
		  -X github.com/cosmos/cosmos-sdk/version.AppName=manifestd \
		  -X github.com/cosmos/cosmos-sdk/version.Version=$(VERSION) \
		  -X github.com/cosmos/cosmos-sdk/version.Commit=$(COMMIT) \
		  -X github.com/liftedinit/manifest-ledger/app.Bech32Prefix=manifest \
		  -X "github.com/cosmos/cosmos-sdk/version.BuildTags=$(build_tags_comma_sep)"

ifeq ($(WITH_CLEVELDB),yes)
  ldflags += -X github.com/cosmos/cosmos-sdk/types.DBBackend=cleveldb
endif
ifeq ($(LINK_STATICALLY),true)
	ldflags += -linkmode=external -extldflags "-Wl,-z,muldefs -static"
endif
ldflags += $(LDFLAGS)
ldflags := $(strip $(ldflags))

BUILD_FLAGS := -tags "$(build_tags_comma_sep)" -ldflags '$(ldflags)' -trimpath
###########
# Install #
###########

all: install

install:
	@echo "--> ensure dependencies have not been modified"
	@go mod verify
	@echo "--> installing manifestd instrumented for coverage"
	@go install $(BUILD_FLAGS) -cover -covermode=atomic -mod=readonly -coverpkg=github.com/liftedinit/manifest-ledger/... ./cmd/manifestd

init:
	./scripts/init.sh

build:
ifeq ($(OS),Windows_NT)
	$(error demo server not supported)
	exit 1
else
	go build -mod=readonly $(BUILD_FLAGS) -cover -covermode=atomic -coverpkg=github.com/liftedinit/manifest-ledger/... -o $(BUILD_DIR)/manifestd ./cmd/manifestd
endif

build-vendored:
	go build -mod=vendor $(BUILD_FLAGS) -o $(BUILD_DIR)/manifestd ./cmd/manifestd

.PHONY: all build build-linux install init lint build-vendored

###############################################################################
###                          INTERCHAINTEST (ictest)                        ###
###############################################################################

ictest-ibc:
	cd interchaintest && go test -race -v -run TestIBC . -count=1

ictest-tokenfactory:
	cd interchaintest && go test -race -v -run TestTokenFactory . -count=1

ictest-manifest:
	cd interchaintest && go test -race -v -run TestManifestModule . -count=1

ictest-poa:
	cd interchaintest && go test -race -v -run TestPOA . -count=1

ictest-group-poa:
	cd interchaintest && go test -race -v -run TestGroupPOA . -count=1

.PHONY: ictest-ibc ictest-tokenfactory

###############################################################################
###                                Build Image                              ###
###############################################################################

get-heighliner:
	git clone https://github.com/strangelove-ventures/heighliner.git
	cd heighliner && go install

local-image:
ifeq (,$(shell which heighliner))
	echo 'heighliner' binary not found. Consider running `make get-heighliner`
else
	heighliner build -c manifest --local -f ./chains.yaml
endif

.PHONY: get-heighliner local-image

#################
###   Test    ###
#################

test:
	@echo "--> Running tests"
	go test -v ./...

.PHONY: test

coverage: ## Run coverage report
	@echo "--> Creating GOCOVERDIR"
	@mkdir -p /tmp/manifest-ledger-coverage
	@echo "--> Cleaning up coverage files, if any"
	@rm -rf /tmp/manifest-ledger-coverage/*
	@echo "--> Running coverage"
	@go test -timeout 30m -race -covermode=atomic -v -cpu=$$(nproc) -cover $$(go list ./...) ./interchaintest/... -coverpkg=github.com/liftedinit/manifest-ledger/... -args -test.gocoverdir="/tmp/manifest-ledger-coverage" > /dev/null 2>&1
	@echo "--> Converting binary coverage report to text format"
	@go tool covdata textfmt -i=/tmp/manifest-ledger-coverage -o coverage.out
	@echo "--> Filtering coverage report"
	@./scripts/filter-coverage.sh
	@echo "--> Generating coverage report"
	@go tool cover -func=coverage-filtered.out
	@echo "--> Generating HTML coverage report"
	@go tool cover -html=coverage-filtered.out -o coverage.html
	@echo "--> Coverage report available at coverage.html"
	@echo "--> Cleaning up coverage files"
	@rm coverage.out /tmp/manifest-ledger-coverage/*
	@echo "--> Running coverage complete"

.PHONY: coverage


##################
###  Protobuf  ###
##################

protoVer=0.14.0
protoImageName=ghcr.io/cosmos/proto-builder:$(protoVer)
protoImage=$(DOCKER) run --rm -v $(CURDIR):/workspace --workdir /workspace $(protoImageName)

proto-all: proto-format proto-lint proto-gen

proto-gen:
	@echo "Generating protobuf files..."
	@$(protoImage) sh ./scripts/protocgen.sh
	@go mod tidy

proto-format:
	@$(protoImage) find ./ -name "*.proto" -exec clang-format -i {} \;

proto-lint:
	@$(protoImage) buf lint proto/ --error-format=json

.PHONY: proto-all proto-gen proto-format proto-lint

#################
###  Linting  ###
#################

golangci_lint_cmd=golangci-lint
golangci_version=v1.58.0

lint:
	@echo "--> Running linter"
	@go install github.com/golangci/golangci-lint/cmd/golangci-lint@$(golangci_version)
	@$(golangci_lint_cmd) run ./... --timeout 15m

lint-fix:
	@echo "--> Running linter and fixing issues"
	@go install github.com/golangci/golangci-lint/cmd/golangci-lint@$(golangci_version)
	@$(golangci_lint_cmd) run ./... --fix --timeout 15m

.PHONY: lint lint-fix

#### FORMAT ####
goimports_version=latest

format-install:
	@echo "--> Installing goimports $(goimports_version)"
	@go install golang.org/x/tools/cmd/goimports@$(goimports_version)
	@echo "--> Installing goimports $(goimports_version) complete"

format: ## Run formatter (goimports)
	@echo "--> Running goimports"
	$(MAKE) format-install
	@find . -name '*.go' -not -name '*.pulsar.go' -not -name '*.pb.go' -exec goimports -w -local github.com/liftedinit/manifest-ledger {} \;

#### GOVULNCHECK ####
govulncheck_version=latest

govulncheck-install:
	@echo "--> Installing govulncheck $(govulncheck_version)"
	@go install golang.org/x/vuln/cmd/govulncheck@$(govulncheck_version)
	@echo "--> Installing govulncheck $(govulncheck_version) complete"

govulncheck: ## Run govulncheck
	@echo "--> Running govulncheck"
	$(MAKE) govulncheck-install
	@govulncheck ./...

#### VET ####

vet: ## Run go vet
	@echo "--> Running go vet"
	@go vet ./...

.PHONY: vet
