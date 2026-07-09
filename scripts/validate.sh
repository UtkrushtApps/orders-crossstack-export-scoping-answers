#!/usr/bin/env bash
# Local inspection helper. Parses templates and runs an informational lint pass.
# This is NOT the grader; it only helps you inspect the repository.
set -euo pipefail

TASK_DIR="/root/task"
cd "${TASK_DIR}"

# Activate venv if present
if [ -f "${TASK_DIR}/.venv/bin/activate" ]; then
  source "${TASK_DIR}/.venv/bin/activate"
fi

echo "== YAML parse check (syntax-only) =="
for tpl in templates/orders-table.yml templates/checkout-api.yml; do
  python3 -c "
import yaml
class SafeLineLoader(yaml.SafeLoader):
    pass
SafeLineLoader.add_multi_constructor('!', lambda l, s, n: str(n))
with open('${tpl}') as f:
    yaml.load(f, Loader=SafeLineLoader)
print('parsed OK:', '${tpl}')
"
done

echo
echo "== cfn-lint (informational) =="
cfn-lint templates/orders-table.yml templates/checkout-api.yml || \
  echo "cfn-lint reported findings (informational)."

echo
echo "== Grep: exports, imports, and environment constraints =="
grep -n "Export:\|ImportValue\|AllowedValues\|shopfluent-orders-\|OrdersTableName\|OrdersTableArn" templates/orders-table.yml templates/checkout-api.yml || true

