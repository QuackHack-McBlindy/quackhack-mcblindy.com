#!/usr/bin/env bash
# hooks/build-similar.sh
# creates similar posts links

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POSTS_JSON="$ROOT/posts.json"
OUT_JSON="$ROOT/similar.json"
TOP_N=3

command -v jq  >/dev/null || { echo "need jq"  >&2; exit 1; }
command -v awk >/dev/null || { echo "need awk" >&2; exit 1; }
[ -f "$POSTS_JSON" ]      || { echo "missing $POSTS_JSON" >&2; exit 1; }


jq -r '
  .[]
  | select(.link != null)
  | [ .link,
      (.title       // ""),
      (.description // ""),
      ((.tags // []) | join(" "))
    ]
  | @tsv
' "$POSTS_JSON" \
| awk -v top_n="$TOP_N" '
  BEGIN {
    FS = "\t"
    split("a an and are as at be but by for from has have he her his i in is it its my of on or that the their them they this to was were will with you your we us our me so if do does did not no yes can could would should may might must just also into out up down over under about than then when where which who whom what why how all any some more most much many very too only own same other another such been being am had", sw, " ")
    for (i in sw) stop[sw[i]] = 1
  }

  function tokenize(text, weight,    i, n, arr, t, cleaned) {
    cleaned = tolower(text)
    gsub(/[^a-z0-9 -]/, " ", cleaned)
    n = split(cleaned, arr, /[ ]+/)
    for (i = 1; i <= n; i++) {
      t = arr[i]
      if (length(t) < 3) continue
      if (t in stop)     continue
      tf[t] += weight
    }
  }

  function json_escape(s) {
    gsub(/\\/, "\\\\", s)
    gsub(/"/,  "\\\"", s)
    return s
  }

  NF < 1 { next }

  { n++; links[n]=$1; titles[n]=$2; descs[n]=$3; tags[n]=$4 }

  END {
    if (n == 0) { print "{}"; exit }


    for (i = 1; i <= n; i++) {
      delete tf
      tokenize(titles[i], 3)
      tokenize(descs[i],  1)
      nt = split(tags[i], tagarr, /[ \t]+/)
      for (k = 1; k <= nt; k++) {
        if (tagarr[k] == "") continue
        tokenize(tagarr[k], 5)
      }

      total = 0
      delete seen
      for (term in tf) {
        total += tf[term]
        tf_store[i, term] = tf[term]
        if (!(term in seen)) {
          terms_list[i] = terms_list[i] " " term
          seen[term] = 1
          df[term]++
        }
      }
      total_tokens[i] = (total > 0 ? total : 1)
    }

    for (i = 1; i <= n; i++) {
      sum_sq = 0
      nterms = split(terms_list[i], tl, " ")
      for (k = 1; k <= nterms; k++) {
        term = tl[k]
        if (term == "") continue
        idf = log((n + 1) / (df[term] + 1)) + 1
        w = (tf_store[i, term] / total_tokens[i]) * idf
        vec[i, term] = w
        sum_sq += w * w
      }
      norm[i] = sqrt(sum_sq)
      if (norm[i] == 0) norm[i] = 1
    }

    for (i = 1; i <= n; i++) {
      for (k = 1; k <= top_n; k++) { best_sim[i,k] = -1; best_idx[i,k] = 0 }
      nti = split(terms_list[i], ti, " ")
      for (j = 1; j <= n; j++) {
        if (i == j) continue
        dot = 0
        for (k = 1; k <= nti; k++) {
          term = ti[k]
          if (term == "") continue
          if ((j, term) in vec) dot += vec[i, term] * vec[j, term]
        }
        sim = dot / (norm[i] * norm[j])
        if (sim <= 0) continue
        for (slot = 1; slot <= top_n; slot++) {
          if (sim > best_sim[i, slot]) {
            for (s2 = top_n; s2 > slot; s2--) {
              best_sim[i, s2] = best_sim[i, s2-1]
              best_idx[i, s2] = best_idx[i, s2-1]
            }
            best_sim[i, slot] = sim
            best_idx[i, slot] = j
            break
          }
        }
      }
    }


    print "{"
    first = 1
    for (i = 1; i <= n; i++) {
      if (!first) print ","
      first = 0
      printf "  \"%s\": [", json_escape(links[i])
      emitted = 0
      for (k = 1; k <= top_n; k++) {
        if (best_idx[i, k] == 0) continue
        if (emitted) printf ", "
        printf "\"%s\"", json_escape(links[best_idx[i, k]])
        emitted++
      }
      printf "]"
    }
    print ""
    print "}"
  }
' > "$OUT_JSON"

echo "similar.json written ($(jq 'keys | length' "$OUT_JSON") entries)"
