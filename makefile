.DEFAULT_GOAL := help

# Sobrescribibles desde la línea de comandos:  make apply ENV=prod
ENV     ?= dev
PROFILE ?= default
TFDIR    = envs/$(ENV)

.PHONY: help login init plan apply nuke fmt validate test example cost

help: ## Muestra esta ayuda
	@grep -hE '^[a-z-]+:.*?##' $(MAKEFILE_LIST) \
	  | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-9s\033[0m %s\n", $$1, $$2}'

login: ## Renueva la sesión SSO
	aws sso login --profile $(PROFILE)

init: ## Inicializa el entorno (requiere envs/$(ENV)/backend.hcl)
	cd $(TFDIR) && terraform init -backend-config=backend.hcl

plan: ## Muestra qué cambiaría
	cd $(TFDIR) && terraform plan

apply: ## Levanta el entorno
	cd $(TFDIR) && terraform apply

nuke: ## Destruye el entorno. Ejecutar al terminar cada sesión.
	cd $(TFDIR) && terraform destroy

fmt: ## Reformatea todos los archivos .tf
	terraform fmt -recursive

validate: ## Comprueba la sintaxis de módulos y entornos
	@terraform fmt -check -recursive
	@cd $(TFDIR) && terraform validate

test: ## Ejecuta la suite de tests (no crea recursos facturables)
	terraform test

example: ## Despliega examples/minimal, sin backend remoto y sin coste
	cd examples/minimal && terraform init && terraform apply

cost: ## Verifica que no quedó nada cobrando en la cuenta
	@echo "--- NAT Gateways ---"
	@aws ec2 describe-nat-gateways \
	  --filter "Name=state,Values=available,pending" \
	  --query 'NatGateways[].NatGatewayId' --output text
	@echo "--- Interface endpoints ---"
	@aws ec2 describe-vpc-endpoints \
	  --query 'VpcEndpoints[?VpcEndpointType==`Interface`].VpcEndpointId' --output text
	@echo "--- Instancias EC2 ---"
	@aws ec2 describe-instances \
	  --query 'Reservations[].Instances[?State.Name!=`terminated`].InstanceId' --output text
	@echo "--- IPs elásticas sin asociar ---"
	@aws ec2 describe-addresses \
	  --query 'Addresses[?AssociationId==null].PublicIp' --output text
