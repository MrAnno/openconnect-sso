BOLD   = \033[1m
RED    = \033[31m
GREEN  = \033[32m
YELLOW = \033[33m
RESET  = \033[0m

NIX_QTWRAPPER ?= # Set up environment for locating Qt libraries from Nix

all: help

###############################################################################
## General
.PHONY: help
help:  ## Show possible make targets
ifeq (, $(shell which gawk))
 $(error "This target requires 'gawk'. Install that first.")
endif
	@printf "Usage: $(YELLOW)make$(RESET) $(GREEN)<target>$(RESET)\n"
	@gawk 'match($$0, /^## (.+)$$/, m) { \
		printf "\n$(BOLD)%s targets:$(RESET)\n", m[1]; \
	}; \
	match($$0, /^([^:]+)\s*:\s*[^#=]+## +(.*)/, m) { \
		if (length(m[1]) < 10) { \
			printf "  $(YELLOW)%-10s$(RESET) %s\n", m[1], m[2]; \
		} else { \
			printf "$(YELLOW)%s$(RESET)\n%-12s %s\n", m[1], "", m[2]; \
		};\
	}; \
	match($$0, /^[^: ]+\s*:\s*([^?= ]+)\s*\?=\s*([^# ]+)?\s*## +(.*)/, m) { \
		if (length(m[2]) == 0) { \
			m[2] = "unset"; \
		}; \
		printf "%-13s- $(GREEN)%s$(RESET): %s (default: $(BOLD)%s$(RESET))\n", "", m[1], m[3], m[2]; \
	} \
	' $(MAKEFILE_LIST)

.PHONY: dev
dev:  ## Initializes repository for development
	@printf "$(BOLD)-> Setting up pre-commit hooks...$(RESET)\n"
	pre-commit install --install-hooks

	@printf "$(BOLD)-> Removing existing .venv directory if exists...$(RESET)\n"
	rm -fr .venv

	@printf "$(BOLD)-> Creating virtualenv in .venv...$(RESET)\n"
	python3 -m venv .venv

	@printf "$(BOLD)-> Installing openconnect-sso in develop mode...$(RESET)\n"
	source .venv/bin/activate && poetry install

	@printf "$(BOLD)$(YELLOW)=> Development installation finished.$(RESET)\n"

.PHONY: clean
clean:  ## Remove temporary files and artifacts
	git clean -Xdf

###############################################################################
## QA
.PHONY: check
check: pre-commit test  ## Run required tests and coding style checks

.PHONY: pre-commit
pre-commit:
	pre-commit run -a

.PHONY: test
test:  ## Run tests
	$(NIX_QTWRAPPER) pytest

###############################################################################
## Release
VERSION = $(shell .venv/bin/python -c 'import openconnect_sso; print(f"v{openconnect_sso.__version__}")')

.PHONY: changelog
changelog:  ## Shows the project's changelog
	@{  trap "rm -f .reno_err" EXIT; \
		reno report $(if $(ONLY_CURRENT),\
			--earliest-version=$$(git describe --abbrev=0 --tags)\
		)\
		2> .reno_err || cat .reno_err; } \
		| pandoc --from rst --to $(FORMAT) $(if $(OUTPUT_FILE),-o $(OUTPUT_FILE))
changelog: FORMAT ?= gfm  ## Output format for changelog
changelog: ONLY_CURRENT ?=  ## Log only current (and unreleased) versions changes
changelog: OUTPUT_FILE ?=  ## Write changelog to file instead of displaying

.INTERMEDIATE: CHANGELOG.md
CHANGELOG.md: $(wildcard releasenotes/**/*)
	$(MAKE) changelog OUTPUT_FILE=CHANGELOG.md

.PHONY: dist
dist: CHANGELOG.md  ## Build packages from whatever state the repository is
	poetry build
	cp CHANGELOG.md dist/CHANGELOG-$(VERSION).md

.PHONY: tag-repo
tag-repo: CURRENT_TAG = $(shell git describe --tags)
tag-repo:
	@printf "$(BOLD) -> Tagging repository as $(VERSION)...$(RESET)\n"
	if [ "$(VERSION)" != "$(CURRENT_TAG)" ]; then \
		git tag $(VERSION) || { printf "$(BOLD)$(RED) => Existing tag $(VERSION) is not at HEAD!$(RESET)\n" && false; }; \
	fi

release: before-release before-clean clean dev check tag-repo dist  ## Build release version in a clean environment
	@printf "$(BOLD)$(GREEN) => Finished building release version $(VERSION).$(RESET)\n"

before-clean:
	@printf "$(YELLOW)"
	@git clean --dry-run -Xd
	@printf "$(RESET)$(BOLD) -> CTRL-C in 10s to cancel...$(RESET)\n"
	@sleep 10

before-release:
	@printf "$(BOLD) -> Building release version...$(RESET)\n"
	@if [ -n "$$(git status --short)" ]; then \
		git status; \
		printf "$(BOLD)$(RED) => Repository is dirty!$(RESET)\n"; \
		false; \
	fi
	@if [ $$(git rev-parse HEAD) != $$(git rev-parse origin/master) ]; then \
		git --no-pager log --oneline --graph origin/master...; \
		printf "$(BOLD)$(RED) => HEAD must point to origin/master!$(RESET)\n"; \
		false; \
	fi
