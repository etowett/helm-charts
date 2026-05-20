# Helm charts repository — common dev tasks.
# Run `make help` to list available targets.

# Use bash (not /bin/sh) so we can rely on pipefail, shopt, and arrays in
# recipes. `bash` (PATH lookup) works on macOS and every Linux distro that
# ships bash; `/usr/bin/env bash` is also valid on modern GNU Make but the
# bare name avoids edge cases in older make versions.
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c

# Tool versions — keep in lockstep with .github/workflows/ci.yaml
HELM_VERSION        ?= v3.16.4
KIND_VERSION        ?= v0.31.0
KUBECONFORM_VERSION ?= v0.7.0

# kind node image used by `make kind-up`. Matches the latest version CI installs against.
KIND_NODE_IMAGE     ?= kindest/node:v1.35.0
KIND_CLUSTER        ?= chart-testing

# Kubernetes versions to validate against (kubeconform schemas).
KUBE_VERSIONS       ?= 1.33.0 1.34.0 1.35.0 1.36.0

# Output dirs
PKG_DIR             := dist
LOCAL_BIN           := $(CURDIR)/bin

# Use system kubeconform if present, otherwise fall back to the locally-installed one.
KUBECONFORM         := $(shell command -v kubeconform 2>/dev/null || echo $(LOCAL_BIN)/kubeconform)

.DEFAULT_GOAL := help

##@ General

.PHONY: help
help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "Usage:\n  make \033[36m<target>\033[0m\n"} \
		/^[a-zA-Z_0-9.-]+:.*?##/ { printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2 } \
		/^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) }' $(MAKEFILE_LIST)

.PHONY: check
check: lint template-examples ## Quick local pre-PR checks (lint + render every example)
	@echo "==> Local checks passed."

##@ Lint and render

.PHONY: lint
lint: require-helm ## helm lint every chart
	@for chart in charts/*/; do \
		echo "==> helm lint $$chart"; \
		helm lint "$$chart"; \
	done

.PHONY: template
template: require-helm ## Render every chart with default values
	@for chart in charts/*/; do \
		name=$$(basename "$$chart"); \
		echo "==> helm template $$name (defaults)"; \
		helm template "$$name-ci" "$$chart" >/dev/null; \
	done

.PHONY: template-examples
template-examples: require-helm ## Render every chart with each examples/*.yaml file
	@shopt -s nullglob; \
	for chart in charts/*/; do \
		name=$$(basename "$$chart"); \
		for example in $${chart}examples/*.yaml; do \
			echo "==> helm template $$name -f $$(basename $$example)"; \
			helm template "$$name-ci" "$$chart" -f "$$example" >/dev/null; \
		done; \
	done

##@ Validate (kubeconform)

.PHONY: validate
validate: require-helm install-kubeconform ## kubeconform-validate every chart (defaults + examples) against $(KUBE_VERSIONS)
	@shopt -s nullglob; \
	for k8s in $(KUBE_VERSIONS); do \
		echo "===> Kubernetes $$k8s"; \
		for chart in charts/*/; do \
			name=$$(basename "$$chart"); \
			echo "  --> $$name (defaults)"; \
			helm template "$$name-ci" "$$chart" | $(KUBECONFORM) -strict -ignore-missing-schemas \
				-kubernetes-version "$$k8s" -summary -output text; \
			for example in $${chart}examples/*.yaml; do \
				echo "  --> $$name with $$(basename $$example)"; \
				helm template "$$name-ci" "$$chart" -f "$$example" | $(KUBECONFORM) -strict -ignore-missing-schemas \
					-kubernetes-version "$$k8s" -summary -output text; \
			done; \
		done; \
	done

##@ Chart-testing (ct)

.PHONY: ct-lint
ct-lint: require-ct ## Run chart-testing lint (matches CI)
	ct lint --config .github/ct.yaml

.PHONY: ct-list-changed
ct-list-changed: require-ct ## List charts that changed vs main
	ct list-changed --config .github/ct.yaml

.PHONY: ct-install
ct-install: require-ct ## Run chart-testing install against the current kubeconfig (needs `make kind-up` first)
	ct install --config .github/ct.yaml

##@ Kind cluster (local)

.PHONY: kind-up
kind-up: require-kind ## Create a local kind cluster ($(KIND_CLUSTER), $(KIND_NODE_IMAGE))
	kind create cluster --name $(KIND_CLUSTER) --image $(KIND_NODE_IMAGE)

.PHONY: kind-down
kind-down: require-kind ## Delete the local kind cluster
	kind delete cluster --name $(KIND_CLUSTER)

##@ Package

.PHONY: package
package: require-helm ## Package every chart into $(PKG_DIR)/
	@mkdir -p $(PKG_DIR)
	@for chart in charts/*/; do \
		helm package "$$chart" -d $(PKG_DIR); \
	done

.PHONY: clean
clean: ## Remove packaged charts and local tooling
	rm -rf $(PKG_DIR) $(LOCAL_BIN)

##@ Tooling

.PHONY: install-kubeconform
install-kubeconform: ## Install kubeconform into ./bin/ if missing (matches CI version)
	@if ! command -v kubeconform >/dev/null 2>&1 && [ ! -x "$(LOCAL_BIN)/kubeconform" ]; then \
		mkdir -p $(LOCAL_BIN); \
		os=$$(uname -s | tr A-Z a-z); arch=$$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/'); \
		echo "==> Installing kubeconform $(KUBECONFORM_VERSION) to $(LOCAL_BIN)"; \
		curl -fsSL "https://github.com/yannh/kubeconform/releases/download/$(KUBECONFORM_VERSION)/kubeconform-$${os}-$${arch}.tar.gz" \
			| tar -xz -C $(LOCAL_BIN) kubeconform; \
		chmod +x $(LOCAL_BIN)/kubeconform; \
	fi

##@ Internal

.PHONY: require-helm
require-helm:
	@command -v helm >/dev/null 2>&1 || { echo "ERROR: helm not found. Install: https://helm.sh/docs/intro/install/"; exit 1; }

.PHONY: require-kind
require-kind:
	@command -v kind >/dev/null 2>&1 || { echo "ERROR: kind not found. Install: https://kind.sigs.k8s.io/docs/user/quick-start/#installation"; exit 1; }

.PHONY: require-ct
require-ct:
	@command -v ct >/dev/null 2>&1 || { echo "ERROR: ct (chart-testing) not found. Install: brew install chart-testing  (or see https://github.com/helm/chart-testing)"; exit 1; }
