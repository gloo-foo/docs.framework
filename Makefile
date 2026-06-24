# Absolute path to this Makefile's directory, with a trailing slash.
here := $(dir $(realpath $(firstword $(MAKEFILE_LIST))))

.DELETE_ON_ERROR:
.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "\033[36m%-10s\033[0m %s\n",$$1,$$2}'

.PHONY: serve
serve: ## Preview the public docs locally
	hugo server --source $(here)public

.PHONY: build
build: ## Build the public docs site into public/_site
	hugo --minify --source $(here)public

.PHONY: clean
clean: ## Remove the built site
	rm -rf $(here)public/_site $(here)public/resources
