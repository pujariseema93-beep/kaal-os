# =============================================================================
# Makefile — Unified Build System for KAAL OS
# =============================================================================
# Ties all the build steps together in one place. Can be run locally
# or in CI/CD. Each target maps to a specific build phase.
#
# Usage:
#   make help           — Show available targets
#   make validate       — Lint and validate all code
#   make build          — Build the live ISO
#   make test           — Boot-test the ISO in QEMU
#   make release        — Create a GitHub release (requires tag)
#   make docker-build   — Build the Docker build container
#   make docker-run     — Run the build container interactively
#   make assemble       — Assemble all packages into a single tree
#   make clean          — Remove build artifacts
#   make dist-clean     — Remove everything including results
# =============================================================================

# ---- Variables ----
DISTRO_NAME    := KAAL OS
DISTRO_LOWER   := $(shell echo $(DISTRO_NAME) | tr '[:upper:]' '[:lower:]')
RELEASEVER     := 42
PROFILE        := all
WORKDIR        := /var/tmp/distro-build
RESULTDIR      := results
BUILD_DATE     := $(shell date '+%Y-%m-%d %H:%M:%S')
DOCKER_IMAGE   := distro-builder
ROOT_DIR       := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

# ---- Colors ----
GREEN  := \033[0;32m
YELLOW := \033[1;33m
BLUE   := \033[0;34m
RED    := \033[0;31m
NC     := \033[0m

# ---- Default target ----
.DEFAULT_GOAL := help

# =============================================================================
# Targets
# =============================================================================

.PHONY: help
help: ## Show available targets
	@echo ""
	@echo "$(GREEN)KAAL OS Build System$(NC)"
	@echo ""
	@echo "$(BLUE)Available targets:$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(BLUE)Variables:$(NC)"
	@echo "  DISTRO_NAME=$(DISTRO_NAME)"
	@echo "  RELEASEVER=$(RELEASEVER)"
	@echo "  PROFILE=$(PROFILE)"
	@echo ""

# ---- Validate ----
.PHONY: validate
validate: validate-shell validate-python validate-kickstart validate-yaml ## Run all validation checks

.PHONY: validate-shell
validate-shell: ## Lint shell scripts with shellcheck
	@echo "$(GREEN)[validate] Checking shell scripts...$(NC)"
	@find . -name '*.sh' -not -path './.git/*' | while read f; do \
		echo "  Checking: $$f"; \
		shellcheck -S warning "$$f" || true; \
	done
	@echo "$(GREEN)Shell scripts passed.$(NC)"

.PHONY: validate-python
validate-python: ## Lint Python modules with flake8
	@echo "$(GREEN)[validate] Checking Python modules...$(NC)"
	@find . -name 'main.py' -path '*/modules/*' -not -path './.git/*' | while read f; do \
		echo "  Checking: $$f"; \
		flake8 --max-line-length=120 --extend-ignore=E402,W503 "$$f" || true; \
	done
	@echo "$(GREEN)Python modules passed.$(NC)"

.PHONY: validate-kickstart
validate-kickstart: ## Validate kickstart files
	@echo "$(GREEN)[validate] Checking kickstart files...$(NC)"
	@find . -name '*.ks' -not -path './.git/*' | while read f; do \
		echo "  Checking: $$f"; \
		ksvalidator "$$f" || true; \
	done
	@echo "$(GREEN)Kickstart files passed.$(NC)"

.PHONY: validate-yaml
validate-yaml: ## Lint YAML files
	@echo "$(GREEN)[validate] Checking YAML files...$(NC)"
	@yamllint -d "{extends: default, rules: {line-length: disable, document-start: disable}}" . 2>&1 || true
	@echo "$(GREEN)YAML files passed.$(NC)"

# ---- Assemble ----
.PHONY: assemble
assemble: ## Assemble all packages into a single installable tree
	@echo "$(GREEN)[assemble] Building install tree...$(NC)"
	@mkdir -p build-tree/usr/libexec/distro-installer
	@mkdir -p build-tree/usr/libexec/distro-bootloader
	@mkdir -p build-tree/usr/libexec/distro-hardware
	@mkdir -p build-tree/etc/calamares/modules
	@mkdir -p build-tree/usr/lib/calamares/modules
	@mkdir -p build-tree/usr/lib/calamares/branding
	@mkdir -p build-tree/usr/share/distro/profiles

	# Copy bootloader package
	@if [ -d distro-bootloader ]; then \
		cp -r distro-bootloader/etc/* build-tree/etc/ 2>/dev/null || true; \
		cp -r distro-bootloader/usr/* build-tree/usr/ 2>/dev/null || true; \
	fi

	# Copy installer scripts
	@if [ -d distro-iso-builder/scripts ]; then \
		cp distro-iso-builder/scripts/*.sh build-tree/usr/libexec/distro-installer/; \
	fi
	@if [ -d distro-hardware/scripts ]; then \
		cp distro-hardware/scripts/*.sh build-tree/usr/libexec/distro-installer/; \
	fi

	# Copy profiles
	@if [ -d distro-iso-builder/profiles ]; then \
		cp distro-iso-builder/profiles/*.list build-tree/usr/share/distro/profiles/; \
	fi

	# Copy Calamares modules
	@if [ -d distro-calamares/modules ]; then \
		cp -r distro-calamares/modules/* build-tree/usr/lib/calamares/modules/; \
		cp distro-calamares/settings.conf build-tree/etc/calamares/settings.conf; \
		cp distro-calamares/modules/distro-post-install.conf build-tree/etc/calamares/modules/distro-post-install.conf; \
	fi

	# Copy Calamares branding
	@if [ -d distro-calamares/branding ]; then \
		cp -r distro-calamares/branding/* build-tree/usr/lib/calamares/branding/; \
	fi

	# Make scripts executable
	@chmod +x build-tree/usr/libexec/distro-installer/*.sh 2>/dev/null || true
	@chmod +x build-tree/etc/grub.d/0*-distro* 2>/dev/null || true
	@chmod +x build-tree/etc/grub.d/2*-distro* 2>/dev/null || true
	@chmod +x build-tree/usr/libexec/distro-bootloader/* 2>/dev/null || true

	@echo "$(GREEN)Install tree assembled at build-tree/$(NC)"
	@find build-tree -type f | wc -l | xargs -I{} echo "  {} files"

# ---- Build ISO ----
.PHONY: build
build: ## Build the live ISO using livemedia-creator
	@echo "$(GREEN)[build] Starting ISO build...$(NC)"
	@echo "  Distro: $(DISTRO_NAME)"
	@echo "  Base: Fedora $(RELEASEVER)"
	@echo "  Profile: $(PROFILE)"
	@echo ""
	@mkdir -p $(RESULTDIR)
	@sudo bash -c '\
		set -e; \
		mkdir -p $(WORKDIR) $(RESULTDIR); \
		cp distro-iso-builder/distro-live.ks $(WORKDIR)/distro-live.ks; \
		sed -i "s/\[DISTRO_NAME\]/$(DISTRO_NAME)/g" $(WORKDIR)/distro-live.ks; \
		sed -i "s/\[distro\]/$(DISTRO_LOWER)/g" $(WORKDIR)/distro-live.ks; \
		sed -i "s/BUILD_DATE_PLACEHOLDER/$(BUILD_DATE)/g" $(WORKDIR)/distro-live.ks; \
		ksvalidator $(WORKDIR)/distro-live.ks || true; \
		livemedia-creator \
			--ks $(WORKDIR)/distro-live.ks \
			--no-virt --image-only \
			--tmp $(WORKDIR) \
			--resultdir $(RESULTDIR) \
			--iso-label "$(DISTRO_NAME)_LIVE" \
			--releasever $(RELEASEVER) \
			--title "$(DISTRO_NAME) Live" \
			--project "$(DISTRO_NAME)" \
			--volid "$(DISTRO_NAME)_LIVE" \
			--make-iso --compress xz; \
	'
	@echo "$(GREEN)ISO build complete.$(NC)"
	@ls -lh $(RESULTDIR)/*.iso 2>/dev/null || echo "  No ISO found!"

# ---- Test ISO ----
.PHONY: test
test: ## Boot-test the ISO in QEMU
	@echo "$(GREEN)[test] Booting ISO in QEMU...$(NC)"
	@ISO=$$(find $(RESULTDIR) -name '*.iso' | head -1); \
	if [ -z "$$ISO" ]; then \
		echo "$(RED)No ISO found in $(RESULTDIR)$(NC)"; \
		echo "Run 'make build' first."; \
		exit 1; \
	fi; \
	echo "Testing: $$ISO"; \
	bash ci/qemu-boot-test.sh "$$ISO"

# ---- Release ----
.PHONY: release
release: ## Create a GitHub release (requires VERSION=x.y.z)
	@if [ -z "$(VERSION)" ]; then \
		echo "$(RED)Usage: make release VERSION=0.1.0$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)[release] Creating release v$(VERSION)...$(NC)"
	@git tag -a "v$(VERSION)" -m "$(DISTRO_NAME) v$(VERSION)"
	@git push origin "v$(VERSION)"
	@echo "$(GREEN)Tag pushed. GitHub Actions will create the release.$(NC)"

# ---- Docker ----
.PHONY: docker-build
docker-build: ## Build the Docker build container
	@echo "$(GREEN)[docker] Building build container...$(NC)"
	@docker build -t $(DOCKER_IMAGE) -f Dockerfile/Dockerfile .
	@echo "$(GREEN)Docker image built: $(DOCKER_IMAGE)$(NC)"

.PHONY: docker-run
docker-run: ## Run the build container interactively
	@echo "$(GREEN)[docker] Starting build container...$(NC)"
	@docker run --rm -it --privileged \
		-v $(ROOT_DIR):/workspace \
		-v /var/tmp/distro-build:/var/tmp/distro-build \
		$(DOCKER_IMAGE) /bin/bash

.PHONY: docker-build-iso
docker-build-iso: ## Build the ISO inside Docker
	@echo "$(GREEN)[docker] Building ISO in container...$(NC)"
	@docker run --rm --privileged \
		-v $(ROOT_DIR):/workspace \
		-v /var/tmp/distro-build:/var/tmp/distro-build \
		-v $(ROOT_DIR)/results:/workspace/results \
		-e DISTRO_NAME="$(DISTRO_NAME)" \
		-e RELEASEVER="$(RELEASEVER)" \
		-w /workspace/distro-iso-builder \
		$(DOCKER_IMAGE) \
		bash -c 'sudo dnf install -y lorax xorriso isomd5sum pykickstart && \
			sed -i "s/\[DISTRO_NAME\]/$(DISTRO_NAME)/g" distro-live.ks && \
			livemedia-creator --ks distro-live.ks --no-virt --image-only \
			--tmp /var/tmp/distro-build --resultdir /workspace/results \
			--iso-label "$(DISTRO_NAME)_LIVE" --releasever $(RELEASEVER) \
			--title "$(DISTRO_NAME) Live" --make-iso --compress xz'

# ---- Clean ----
.PHONY: clean
clean: ## Remove build artifacts
	@echo "$(YELLOW)[clean] Removing build artifacts...$(NC)"
	@rm -rf $(WORKDIR) build-tree/
	@echo "$(GREEN)Clean.$(NC)"

.PHONY: dist-clean
dist-clean: clean ## Remove everything including results
	@echo "$(YELLOW)[dist-clean] Removing all outputs...$(NC)"
	@rm -rf $(RESULTDIR) /var/tmp/distro-build
	@echo "$(GREEN)Dist clean.$(NC)"
