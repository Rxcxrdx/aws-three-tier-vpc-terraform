.DEFAULT_GOAL := help
ENV ?= dev
TFDIR = envs/$(ENV)
PROFILE = sandbox-net

.PHONY: login plan apply nuke cost help

login: ## Renueva la sesión SSO (4 horas)
	aws sso login --profile $(PROFILE)

plan: ## Muestra qué cambiaría
	cd $(TFDIR) && terraform plan

apply: ## Levanta el ambiente
	cd $(TFDIR) && terraform apply

nuke: ## Destruye el ambiente. Correr al terminar cada sesión.
	cd $(TFDIR) && terraform destroy

cost: ## Verifica que no quedó nada cobrando
	@echo "--- NAT Gateways ---"
	@aws ec2 describe-nat-gateways --filter "Name=state,Values=available" \
	  --query 'NatGateways[].NatGatewayId' --output text
	@echo "--- VPC Endpoints ---"
	@aws ec2 describe-vpc-endpoints --query 'VpcEndpoints[].VpcEndpointId' --output text
	@echo "--- EIPs sin asociar ---"
	@aws ec2 describe-addresses \
	  --query 'Addresses[?AssociationId==null].PublicIp' --output text

help:
	@grep -E '^[a-z]+:.*?##' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-7s\033[0m %s\n", $$1, $$2}'terraform fmt