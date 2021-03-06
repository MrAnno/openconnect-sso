EM_B   = "\\e[1m"
EM_RST = "\\e[0m"

NIX_QTWRAPPER ?= # Set up environment for locating Qt libraries from Nix

all: help

###############################################################################
## General
.PHONY: help
help:  ## Show possible make targets
	@echo "usage: make <target> [VAR=value ...]"
	@sed -E -n \
		-e 's/^## ([^:]+)/\n\1 targets:/p' \
		-e 's/^([^:]+)\s*:\s*[^#=]+## +(.*)/  \1\t\2/p' \
	| column \
		--table \
		--table-empty-lines \
		--separator '	' \
		--table-wrap 2

.PHONY: dev
dev:  ## Initializes repository for development
	@echo -e "$(EM_B)-> Setting up pre-commit hooks...$(EM_RST)"
	pre-commit install --install-hooks

	@echo -e "$(EM_B)-> Removing existing .venv directory if exists...$(EM_RST)"
	rm -fr .venv

	@echo -e "$(EM_B)-> Creating virtualenv in .venv...$(EM_RST)"
	python3 -m venv .venv

	@echo -e "$(EM_B)-> Installing openconnect-sso in develop mode..$(EM_RST)"
	source .venv/bin/activate && poetry install

	@echo -e "$(EM_B)=> Development installation finished.$(EM_RST)"

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
