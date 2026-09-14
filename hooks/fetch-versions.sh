#!/usr/bin/env bash
set -euo pipefail

OUT="static/versions.json"
UA="quackhack-mcblindy.com build"

crates=(
  yo-esp
  barely-fuzzy
  tinyapi
  es8311
  es7210
)

repos=(
  quackhack-mcblindy/zigduck
  quackhack-mcblindy/yo
  quackhack-mcblindy/ESP32-S3-WATCH-rs
  quackhack-mcblindy/ESP32-S3-BOX-3-rs
)

declare -A versions

if [[ -f "$OUT" ]]; then
  while IFS="=" read -r k v; do
    versions["$k"]="$v"
  done < <(jq -r 'to_entries[] | "\(.key)=\(.value)"' "$OUT")
fi


for crate in "${crates[@]}"; do
  version=$(
    curl -fsSL -A "$UA" \
      "https://crates.io/api/v1/crates/$crate" |
      jq -r '.crate.max_stable_version // .crate.newest_version // empty'
  )

  if [[ -z "$version" ]]; then
    echo "ERROR: failed to fetch crates.io version for $crate" >&2
    continue
  fi

  old="${versions[$crate]:-}"

  if [[ "$old" != "$version" ]]; then
    echo "$crate: ${old:-<missing>} -> $version"
    versions["$crate"]="$version"
  fi
done


for repo in "${repos[@]}"; do
  name="${repo##*/}"

  version=$(
    curl -fsSL -A "$UA" \
      "https://api.github.com/repos/$repo/tags?per_page=100" |
      jq -r '
        .[]
        | .name
        | sub("^v"; "")
        | select(test("^[0-9]+\\.[0-9]+\\.[0-9]+$"))
      ' |
      sort -V |
      tail -n 1
  )

  if [[ -z "$version" ]]; then
    echo "ERROR: no version tag found for $repo" >&2
    continue
  fi

  old="${versions[$name]:-}"

  if [[ "$old" != "$version" ]]; then
    echo "$name: ${old:-<missing>} -> $version"
    versions["$name"]="$version"
  fi
done

tmp=$(mktemp)

jq -n \
  --argjson versions "$(
    printf '%s\n' "${!versions[@]}" |
      while read -r key; do
        jq -n \
          --arg key "$key" \
          --arg value "${versions[$key]}" \
          '{($key): $value}'
      done |
      jq -s 'add'
  )" \
  '$versions | to_entries | sort_by(.key) | from_entries' \
  > "$tmp"

if ! cmp -s "$tmp" "$OUT"; then
  mv "$tmp" "$OUT"
  echo "versions.json updated"
else
  rm "$tmp"
fi
