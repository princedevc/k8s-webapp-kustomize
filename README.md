# [![CI - Kustomize validation](https://github.com/princedevc/k8s-webapp-kustomize/actions/workflows/ci.yml/badge.svg)](https://github.com/princedevc/k8s-webapp-kustomize/actions/workflows/ci.yml)

# webapp — Kustomize GitOps-friendly manifests

This repository contains a Kustomize base and overlays for deploying the `webapp` (nginx) across two environments: `staging` and `production`.

Layout

k8s/
- base/          # core resources (Deployment, Service)
- overlays/
  - staging/     # namespace + patches (replicas=1, image=nginx:1.25)
  - production/  # namespace + patches (replicas=3, image=nginx:1.27)

Deployment

- The `Deployment` in `base` references a Secret named `webapp-secret` via `envFrom` (not stored in Git in plaintext).

Deploy commands

Use `kubectl` + `kustomize` (built into `kubectl`) to deploy each environment:

Staging:
```
kubectl apply -k k8s/overlays/staging
```

Production:
```
kubectl apply -k k8s/overlays/production
```

Secret management

I recommend using Bitnami Sealed Secrets for GitOps-safe secrets. Workflow summary:

- Install the Sealed Secrets controller in-cluster (see controller install notes below).
- Locally create a Kubernetes `Secret` (dry-run) and encrypt it with `kubeseal` to produce a `SealedSecret` YAML.
- Commit the `SealedSecret` to the overlay (for example: `k8s/overlays/staging/sealedsecret-webapp.yaml`). The controller will decrypt and create a real `Secret` in-cluster.

Example (create & seal a secret for `staging`):
```
kubectl create secret generic webapp-secret \
  --from-literal=DB_PASSWORD=PLACEHOLDER \
  --from-literal=API_KEY=PLACEHOLDER \
  -n staging \
  --dry-run=client -o yaml \
  | kubeseal --format=yaml > k8s/overlays/staging/sealedsecret-webapp.yaml
```

Helper script and Makefile

This repo includes a reusable helper script at `scripts/seal-secret.sh` and a `Makefile` to simplify secret generation:

- `DB_PASSWORD=... API_KEY=... ./scripts/seal-secret.sh staging`
- `DB_PASSWORD=... API_KEY=... ./scripts/seal-secret.sh production`
- `make seal-secret-staging DB_PASSWORD=... API_KEY=...`
- `make seal-secret-production DB_PASSWORD=... API_KEY=...`

These commands generate `k8s/overlays/<env>/sealedsecret-webapp.yaml` using the cluster's Sealed Secrets public key.

This repository includes example `SealedSecret` files under `k8s/overlays/staging` and `k8s/overlays/production`. Those example files contain placeholder encrypted data and must be regenerated with `kubeseal` against your cluster's Sealed Secrets public key before use.

Important: Do NOT commit plaintext secret manifests. Only commit `SealedSecret` files (they are safe to publish).

Controller install (quick notes)

Install with Helm (example):
```
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm repo update
helm install sealed-secrets sealed-secrets/sealed-secrets
```

Or follow the official manifests at: https://github.com/bitnami-labs/sealed-secrets

Assumptions & trade-offs

- Choice: Bitnami Sealed Secrets — simple GitOps workflow and sealed objects are safe to store in Git.
- Trade-off: Requires installing a controller in-cluster and having the controller's public key available to `kubeseal` (the `kubeseal` client can fetch it from the cluster).
- Alternative approaches: ExternalSecrets (pulls from cloud secret stores), SOPS+Kustomize plugin (encrypts files at rest). Given time, I'd add a small CI step to auto-generate sealed secrets from a secret store.

What I'd improve with more time

- Provide example sealed secret files (generated from a real controller) for both overlays. Example placeholder `SealedSecret` files are included under each overlay.
- Add a tiny CI job that validates `kustomize build` for each overlay and checks there are no plaintext secrets committed.
- Add resource limits/requests, readiness/liveness probes and an Ingress manifest per environment.

Validation

To validate without a cluster run:
```
kustomize build k8s/overlays/staging > build-staging.yaml
kustomize build k8s/overlays/production > build-production.yaml
```

Or use the bundled helper target:
```
make validate
```

These files will show the rendered manifests (note: the `SealedSecret` files are not included by default — create them as explained above).

Included build outputs

- Staging build: [build-staging.yaml](build-staging.yaml)
- Production build: [build-production.yaml](build-production.yaml)

The included `build-*.yaml` files are the result of `kustomize build` of each overlay at the time of this submission; they may contain placeholder `SealedSecret` objects which must be regenerated for your cluster before applying.


---
staging-output
---
apiVersion: v1
kind: Namespace
metadata:
  name: staging
---
apiVersion: v1
kind: Service
metadata:
  name: webapp-webapp
  namespace: staging
spec:
  ports:
  - port: 80
    protocol: TCP
    targetPort: 80
  selector:
    app: webapp
  type: ClusterIP
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-webapp
  namespace: staging
spec:
  replicas: 1
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
      - envFrom:
        - secretRef:
            name: webapp-secret
        image: nginx:1.25
        name: webapp
        ports:
        - containerPort: 80
---
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: webapp-secret
  namespace: staging
spec:
  encryptedData:
    API_KEY: AQICAHjzkFyXLGkR6lEcv7gU7KpeVhMXd2Q48la5CwDgQh8T1gxz1AgkK0n9wfWJHpUz9mQO2RaSx5SgkoiM7uHU2kL0ntxwXONaIZpHnK1XuXvYq4AAAAqjCCAzYwggMrBgkqhkiG9w0BBwaggjswggI6AgEAMIGwBgkqhkiG9w0BBwaggYgwgYMg
    DB_PASSWORD: AQICAHjztkUpr3Y6kTg3MU9YcDBVg2kl4gOeLzjaSzlGj5Cg4Qtq4okVaaiZNtM7tZb/7dYGxAAAAjDCBqQYJKoZIhvcNAQcGoIGeMIGbAgEAMIGXBgkqhkiG9w0BBwEwHgYJYIZIAWUDBAEuMBEEDM/a8kPZ2sH4X-UezQIBEIBWmVUdVv1A9iyzHhPIaO-9X9z3dA8Ue8hU0ZDV7Qk8eKLx2QpRAAWg2g==
  template:
    metadata:
      name: webapp-secret
      namespace: staging


---
production-output
---
apiVersion: v1
kind: Namespace
metadata:
  name: production
---
apiVersion: v1
kind: Service
metadata:
  name: webapp-webapp
  namespace: production
spec:
  ports:
  - port: 80
    protocol: TCP
    targetPort: 80
  selector:
    app: webapp
  type: ClusterIP
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-webapp
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
      - envFrom:
        - secretRef:
            name: webapp-secret
        image: nginx:1.27
        name: webapp
        ports:
        - containerPort: 80
---
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: webapp-secret
  namespace: production
spec:
  encryptedData:
    API_KEY: AQICAHju4ieL8kExdHVN6ko3HwZl0o+st6J6m1+2pH4OzS9ucvNRs3XwZpK8yxY78w4NC6HqvLRT0v5U2Q==
    DB_PASSWORD: AQICAHjotC7sJH9xLb4DYQkz4Y3mBL2KLTnZ/1aZqz1JcGKpYp0D5lZ6gPmA4FxQShkJ6n8yPz9scV9QYg3M1tUdLqv26M1DXY0LZtG5x7vEwYzJ+gAAAAjDCBrQYJKoZIhvcNAQcGoIGYMIGVAgEAMIGXBgkqhkiG9w0BBwEwHgYJYIZIAWUDBAEuMBEEDG4/OL5FcgM3VQgDMhAIBEICvS5B9nV4z5uSVxA8L6GQHiB8H2hPVdW66X36GbWV1I2AnJuQtQmRQ==
  template:
    metadata:
      name: webapp-secret
      namespace: production
