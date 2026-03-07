#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ID="${FIREBASE_PROJECT_ID:-clearify-5414d}"

if [[ -z "${OPENAI_API_KEY:-}" ]]; then
  echo "OPENAI_API_KEY is required."
  exit 1
fi

if ! npx firebase-tools@latest login:list >/tmp/clearify-firebase-login.txt 2>&1; then
  cat /tmp/clearify-firebase-login.txt
  echo "Firebase CLI is not authenticated. Run: npx firebase-tools@latest login"
  exit 1
fi

cd "$ROOT_DIR/backend/functions"
npm ci
npm run lint
npm run test
npm run build

printf '%s' "$OPENAI_API_KEY" | \
  npx firebase-tools@latest functions:secrets:set OPENAI_API_KEY \
    --project "$PROJECT_ID" \
    --data-file=-

cd "$ROOT_DIR"
npx firebase-tools@latest deploy \
  --project "$PROJECT_ID" \
  --only functions,firestore:rules,firestore:indexes,storage

cd "$ROOT_DIR/backend/functions"
GCLOUD_PROJECT="$PROJECT_ID" npm run seed:scenarios

echo "Deployment complete for ${PROJECT_ID}."
