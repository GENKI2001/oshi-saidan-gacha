#!/bin/bash
# Generate or edit one image through Codex CLI's built-in image_gen tool.
#
#   codex_image.sh NAME          (run inside a work folder)
#
# Reads NAME.txt (the prompt) and optional NAME.refs (one reference/edit
# image path per line), writes out_NAME.png and log_NAME.txt. Run several at
# once with:  printf "a\nb\nc\n" | xargs -P 5 -L 1 /path/to/codex_image.sh
# Each image takes roughly 5-10 minutes.
cd "${WORK_DIR:-$(dirname "$0")}"
n=$1; args=()
if [ -f "$n.refs" ]; then while read -r r; do [ -n "$r" ] && args+=(--image "$r"); done < "$n.refs"; fi
for try in 1 2 3; do
  [ -f "out_$n.png" ] && break
  { cat "$n.txt"; echo; echo "Use the image_gen tool. When done, copy the final PNG (keep alpha if transparent) to $PWD/out_$n.png and reply only with DONE."; } | codex exec --skip-git-repo-check --dangerously-bypass-approvals-and-sandbox -C "$PWD" "${args[@]}" - > "log_$n.txt" 2>&1
done
ls -la "out_$n.png"
