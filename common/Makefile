.DEFAULT_GOAL:=help

## All commands available in the Makefile

##@ Helper
help:  ## Display this help
	@echo ""
	@echo "  __    __     ______     __  __     ______    "
	@echo " /\ \"-./  \   /\  __ \   /\ \/ /    /\  ___\   "
	@echo " \ \ \-./\ \  \ \  __ \  \ \  _\"-.  \ \  __\   "
	@echo "  \ \_\ \ \_\  \ \_\ \_\  \ \_\ \_\  \ \_____\ "
	@echo "   \/_/  \/_/   \/_/\/_/   \/_/\/_/   \/_____/ "
	@echo ""
	@awk 'BEGIN{FS=":.*##";print "Usage:\n  make \033[36m<target>\033[0m\n"} \
	/^##@/{print "\n\033[1m"substr($$0,5)"\033[0m"} \
	/^[a-zA-Z0-9._-]+.*:.*##/{split($$1,t,/ /);name=t[1];if(length(t)>1){name=name", "t[2]} \
	printf "  \033[36m%-22s\033[0m %s\n",name,$$2}' $(MAKEFILE_LIST)

##@ Devpod
devpod-list dpl: ## List all workspace
	devpod ls

devpod-start dps: ## Start all workspace
	./.devpod/script/up.sh

devpod-recreate dpr: ## Recreate and Start all workspace
	./.devpod/script/up.sh --recreate

devpod-stop: ## Stop all workspace
	devpod list --output json | jq -r '.[] | select(.id | startswith("(prefix)-")) | .id' | xargs -I {}  devpod stop {}

devpod-delete: ## Stop all workspace
	devpod list --output json | jq -r '.[] | select(.id | startswith("(prefix)-")) | .id' | xargs -I {} devpod delete {}
