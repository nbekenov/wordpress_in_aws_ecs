help:
	@echo make targets:
	@awk ' \
	    BEGIN { FS=":.*?## " } \
	    $$1~/^[A-Za-z]/ && $$2~/^.+/ { \
	        printf "    * %-18.18s %s\n",$$1":",$$2 \
	    }' $(MAKEFILE_LIST)

validate: ## validate templates
	@printf "\n\n\033[0;32m** Validate templates **\n\n\033[0m"
	aws cloudformation validate-template --template-body file://templates/main.yml --profile=dev

lint: ## run static code analysis (cfn-lint)
	@printf "\n\n\033[0;32m** Static code analysis (cfn-lint) **\n\n\033[0m"
	cfn-lint templates/*

seclint: ## run security analysis (cfn-nag)
	@printf "\n\n\033[0;32m** Static code security analysis (cfn-nag) **\n\n\033[0m"
	cfn_nag_scan --input-path templates
	cfn_nag_scan --input-path templates --parameter-values-path=prod-configuration.json -o json > reports/cfn_nag.out.json && echo OK || echo FAILED

test: validate lint seclint

package: ## package the code (cloudformation package)
	@printf "\n\n\033[0;32m** Package code (cloudformation package) **\n\n\033[0m"
	aws cloudformation package --template-file templates/main.yml --s3-bucket wordpress-pipeline-artifacts --output-template-file package.yml --profile=dev