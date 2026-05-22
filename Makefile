SHELL := /usr/bin/env bash

.PHONY: seal-secret-staging seal-secret-production validate

seal-secret-staging:
	@DB_PASSWORD=$${DB_PASSWORD:?DB_PASSWORD required} API_KEY=$${API_KEY:?API_KEY required} ./scripts/seal-secret.sh staging

seal-secret-production:
	@DB_PASSWORD=$${DB_PASSWORD:?DB_PASSWORD required} API_KEY=$${API_KEY:?API_KEY required} ./scripts/seal-secret.sh production

validate:
	@command -v kustomize >/dev/null 2>&1 || command -v kubectl >/dev/null 2>&1
	@if command -v kustomize >/dev/null 2>&1; then \
	  kustomize build k8s/overlays/staging >/dev/null; \
	  kustomize build k8s/overlays/production >/dev/null; \
	else \
	  kubectl kustomize k8s/overlays/staging >/dev/null; \
	  kubectl kustomize k8s/overlays/production >/dev/null; \
	fi
