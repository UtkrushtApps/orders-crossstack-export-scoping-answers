#!/usr/bin/env bash
set -euo pipefail

TASK_DIR="/root/task"
cd "${TASK_DIR}"

echo "[readiness] Setting up Python virtual environment..."
python3 -m venv "${TASK_DIR}/.venv"
source "${TASK_DIR}/.venv/bin/activate"

echo "[readiness] Installing local CloudFormation tooling..."
pip install -q --upgrade pip
pip install -q -r "${TASK_DIR}/requirements.txt"

echo "[readiness] Starting local AWS-compatible support service..."
docker compose up -d

echo "[readiness] Waiting for LocalStack health endpoint..."
ATTEMPTS=0
MAX_ATTEMPTS=30
until curl -sf http://localhost:4566/_localstack/health >/dev/null 2>&1; do
  ATTEMPTS=$((ATTEMPTS + 1))
  if [ "${ATTEMPTS}" -ge "${MAX_ATTEMPTS}" ]; then
    echo "[readiness] ERROR: LocalStack did not become healthy in time." >&2
    docker compose logs --tail 50 localstack || true
    exit 1
  fi
  echo "[readiness] ...not ready yet (attempt ${ATTEMPTS}/${MAX_ATTEMPTS})"
  sleep 3
done
echo "[readiness] LocalStack is healthy."

echo "[readiness] Validating starter templates parse (syntax-only)..."
for tpl in templates/orders-table.yml templates/checkout-api.yml; do
  if [ ! -f "${TASK_DIR}/${tpl}" ]; then
    echo "[readiness] ERROR: missing template ${tpl}" >&2
    exit 1
  fi
  python3 -c "
import yaml
class SafeLineLoader(yaml.SafeLoader):
    pass
SafeLineLoader.add_multi_constructor('!', lambda l, s, n: str(n))
with open('${TASK_DIR}/${tpl}') as f:
    yaml.load(f, Loader=SafeLineLoader)
print('[readiness] parsed OK: ${tpl}')
"
done

echo "[readiness] Running non-fatal cfn-lint report (informational only)..."
cfn-lint templates/orders-table.yml templates/checkout-api.yml || \
  echo "[readiness] cfn-lint reported findings (non-fatal for readiness)."

echo "[readiness] Verifying evidence and parameter files are present..."
for f in \
  parameters/orders-table-staging.json \
  parameters/orders-table-prod.json \
  parameters/checkout-api-staging.json \
  parameters/checkout-api-prod.json \
  evidence/stack-events.txt \
  evidence/change-set-prod.json \
  evidence/review-notes.md; do
  if [ ! -f "${TASK_DIR}/${f}" ]; then
    echo "[readiness] ERROR: missing expected file ${f}" >&2
    exit 1
  fi
done
echo "[readiness] All expected starter files present."

echo "[readiness] Starter project is inspectable. Readiness check passed."
exit 0
