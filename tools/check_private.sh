#!/usr/bin/env bash
# Scan the repository for data that should not be published.
#
# 1. Generic patterns: e-mail addresses, private IPv4 addresses, MAC-like hex IDs,
#    long hex strings (API keys), "password:" with a literal value.
# 2. Your own private terms (names, town, device serials …) from tools/private_terms.txt,
#    one term per line. That file is in .gitignore and never committed.
#
# Usage:  tools/check_private.sh            (exit code 1 if something was found)
#         Tip: run it as a git pre-commit hook.

set -u
cd "$(dirname "$0")/.."

found=0
excl=(--exclude-dir=.git --exclude=check_private.sh --exclude=private_terms.txt --exclude=secrets.example.yaml)

check() {  # $1 = description, $2 = extended regex
  local out
  out=$(grep -rInE "${excl[@]}" -e "$2" . || true)
  if [ -n "$out" ]; then
    echo "== $1"; echo "$out"; echo; found=1
  fi
}

check "E-mail addresses"          '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
check "Private IPv4 addresses"    '\b(10|192\.168|172\.(1[6-9]|2[0-9]|3[01]))\.[0-9]{1,3}\.[0-9]{1,3}'
check "MAC-like device IDs"       '[0-9a-fA-F]{12}([^0-9a-fA-F]|$)'
check "Long base64 secrets"       '[A-Za-z0-9+]{32,}={0,2}'
check "Literal passwords/keys"    '(password|key):[[:space:]]*"?[^!"$ ][^"]{3,}'

if [ -f tools/private_terms.txt ]; then
  while IFS= read -r term; do
    [ -z "$term" ] && continue
    case "$term" in \#*) continue ;; esac
    check "Private term: $term" "$(printf '%s' "$term" | sed 's/[][\.*^$+?(){}|/]/\\&/g')"
  done < tools/private_terms.txt
else
  echo "Hint: create tools/private_terms.txt (one private term per line) for a personal check."
fi

if [ "$found" -eq 0 ]; then echo "OK – nothing suspicious found."; fi
exit "$found"
