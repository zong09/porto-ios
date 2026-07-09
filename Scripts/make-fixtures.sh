#!/usr/bin/env bash
# Capture live GET responses from the local backend into test fixtures.
# Prereq: backend running at localhost:3002 with ENABLE_DEMO=true (from the sibling `porto` repo).
set -euo pipefail

BASE="${API_BASE_URL:-http://localhost:3002/api}"
OUT="$(cd "$(dirname "$0")/.." && pwd)/Packages/PortoKit/Tests/PortoKitTests/Fixtures"
mkdir -p "$OUT"

echo "==> Creating demo session at $BASE"
TOKEN=$(curl -fsS -X POST "$BASE/auth/demo" | python3 -c 'import sys,json;print(json.load(sys.stdin)["token"])')
AUTH=(-H "Authorization: Bearer $TOKEN")

grab() { # name  path
  echo "==> GET $2"
  curl -fsS "${AUTH[@]}" "$BASE$2" -o "$OUT/$1.json"
}

grab auth-config          /auth/config
grab me                   /auth/me
grab portfolios           /portfolios
grab assets               /assets
grab transactions         /transactions
grab liabilities          /liabilities
grab liability-transactions /liabilities/transactions
grab net-worth-summary    /net-worth/summary
grab net-worth-history    "/net-worth/history?days=365"

echo "==> Fixtures written to $OUT"
ls -1 "$OUT"/*.json
