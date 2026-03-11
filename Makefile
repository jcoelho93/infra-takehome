REPO_URL ?= $(shell git remote get-url origin)

init:
	tofu -chdir=tofu init

plan:
	tofu -chdir=tofu plan -out .plan

apply:
	tofu -chdir=tofu apply .plan

install-argocd:
	kubectl create namespace argocd || true
	kubectl apply --server-side -k argocd/argocd
	kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

deploy-apps:
	REPO_URL=$(REPO_URL) envsubst < argocd/apps/postgres.yaml | kubectl apply -f -
	REPO_URL=$(REPO_URL) envsubst < argocd/apps/postgrest.yaml | kubectl apply -f -

destroy:
	tofu -chdir=tofu destroy -auto-approve

clean:
	rm -rf tofu/.plan tofu/.terraform tofu/.terraform.lock.hcl tofu/terraform.tfstate*
