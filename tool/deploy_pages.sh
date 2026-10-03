#!/bin/bash
# Builds the web version and publishes it on GitHub Pages (gh-pages branch):
#   tool/deploy_pages.sh
#   → https://genki2001.github.io/oshi-saidan-gacha/
# (.github/workflows/pages.yml does the same on every push once the GitHub
#  token has the `workflow` scope: gh auth refresh -s workflow)
set -euo pipefail
cd "$(dirname "$0")/.."
flutter build web --release --base-href /oshi-saidan-gacha/
rev=$(git rev-parse --short HEAD)
tmp=$(mktemp -d)
rsync -a build/web/ "$tmp/"
touch "$tmp/.nojekyll"
cd "$tmp"
git init -q -b gh-pages
git add -A
git -c user.name="$(git -C "$OLDPWD" config user.name)" -c user.email="$(git -C "$OLDPWD" config user.email)" commit -q -m "Web build of $rev"
git push -q -f https://github.com/GENKI2001/oshi-saidan-gacha.git gh-pages
echo "published $rev → https://genki2001.github.io/oshi-saidan-gacha/"
