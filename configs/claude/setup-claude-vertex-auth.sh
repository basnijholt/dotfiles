#!/bin/bash

if [[ -z "$1" ]]; then
    echo "Usage: $0 <PROJECT_ID>"
    echo "Example: $0 my-gcp-project-123"
    exit 1
fi

PROJECT_ID="$1"
SA_NAME="claude-code-vertex"
KEY_FILE="$HOME/.config/claude-vertex-key.json"

set -e

echo "Creating service account..."
gcloud iam service-accounts create "$SA_NAME" \
  --project="$PROJECT_ID" \
  --display-name="Claude Code Vertex AI" 2>/dev/null || echo "Service account already exists, continuing..."

echo "Granting Vertex AI User role..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/aiplatform.user" \
  --quiet

echo "Generating JSON key..."
gcloud iam service-accounts keys create "$KEY_FILE" \
  --iam-account="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo ""
echo "✅ Key saved to: $KEY_FILE"
echo ""
echo "Add these to your shell config:"
echo ""
echo 'export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.config/claude-vertex-key.json"'
echo "export ANTHROPIC_VERTEX_PROJECT_ID=${PROJECT_ID}"
echo "export ANTHROPIC_MODEL='claude-opus-4-6'"
echo "export ANTHROPIC_SMALL_FAST_MODEL='claude-haiku-4-5@20251001'"
echo 'export CLAUDE_CODE_USE_VERTEX=1'
