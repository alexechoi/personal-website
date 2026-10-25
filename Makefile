# Day-to-day commands. `p` is a project slug (a folder in projects/).
#
#   make new p=my-idea [t=static|node|python]
#   make dev p=my-idea
#   make deploy p=my-idea
#   make list

include config.env

p ?=
t ?= static

.PHONY: help login new dev deploy deploy-all destroy list infra

help:
	@sed -n '2,7p' Makefile | sed 's/^# \{0,1\}//'

login: ## Authenticate gcloud and point it at the project
	gcloud auth login
	gcloud config set project $(GCP_PROJECT)
	gcloud config set run/region $(GCP_REGION)

new:
	@scripts/new.sh $(p) $(t)

dev:
	@scripts/dev.sh $(p)

deploy:
	@test -n "$(p)" || (echo "usage: make deploy p=<slug>" && exit 1)
	@scripts/deploy.sh $(p)

deploy-all:
	@scripts/deploy.sh --all

destroy:
	@scripts/destroy.sh $(p)

list:
	@scripts/list.sh

infra:
	cd infra && terraform init && terraform apply
