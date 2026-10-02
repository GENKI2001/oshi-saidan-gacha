#!/bin/bash
# gen_retry.sh NAME : run codex_image.sh up to 3 times until out_NAME.png exists
cd "$(dirname "$0")"
for i in 1 2 3; do
  [ -f "out_$1.png" ] && exit 0
  ./codex_image.sh "$1" >/dev/null 2>&1
done
