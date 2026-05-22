#!/usr/bin/env bash
set -euo pipefail

# print usage instructions and exit with non-zero code
usage() {
  cat <<EOF
Usage: $0 <staging|production>

Environment variables:
  DB_PASSWORD
  API_KEY

Example:
  DB_PASSWORD=secret123 API_KEY=token123 $0 staging
EOF
  exit 1
}

# require exactly one environment argument
if [[ $# -ne 1 ]]; then
  usage
fi

env="$1"
case "$env" in
  staging|production) ;;
  *) echo "ERROR: unknown env '$env'" >&2; usage ;;
esac

# require secret values in environment variables
if [[ -z "${DB_PASSWORD:-}" || -z "${API_KEY:-}" ]]; then
  echo "ERROR: DB_PASSWORD and API_KEY must be set" >&2
  usage
fi

# output path is inside the selected overlay
out="k8s/overlays/$env/sealedsecret-webapp.yaml"

# create a Kubernetes Secret manifest, then seal it with kubeseal
kubectl create secret generic webapp-secret \
  --from-literal=DB_PASSWORD="$DB_PASSWORD" \
  --from-literal=API_KEY="$API_KEY" \
  -n "$env" \
  --dry-run=client -o yaml \
  | kubeseal --format=yaml > "$out"

echo "Generated $out"
