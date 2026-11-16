#!/usr/bin/env sh
# The app reads its legal texts from assets/legal. This copies them to docs/legal
# with readable names. Run it after editing the texts.
set -e
cd "$(dirname "$0")/.."
mkdir -p docs/legal
for lang in en fr ar; do
  cp "assets/legal/terms_$lang.md" "docs/legal/TERMS_OF_USE.$lang.md"
  cp "assets/legal/privacy_$lang.md" "docs/legal/PRIVACY_POLICY.$lang.md"
done
echo "docs/legal updated"
