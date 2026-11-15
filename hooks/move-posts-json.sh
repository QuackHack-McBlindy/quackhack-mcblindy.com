#!/usr/bin/env bash
set -euo pipefail

src="$HOME/QuackHack-McBlindy.com/posts/posts.json"
dst="$HOME/QuackHack-McBlindy.com/posts.json"

if [ -f "$src" ]; then
  mv -f "$src" "$dst"
  echo "moved posts.json → webroot"
else
  echo "posts/posts.json not found, nothing to move"
fi
