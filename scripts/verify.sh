#!/usr/bin/env bash
# Re-checks this repository against index.json (format xvm-sources/1):
#   * every submodule gitlink (git ls-tree HEAD <path>) is the commit index.json names, and
#     .gitmodules carries the same path and url (= repo + .git);
#   * every committed file listed under `files` has the sha256 index.json names, and no file under
#     alpine/ (other than ORIGIN.md) is missing from index.json;
#   * prints the archive table (the archives the xvm build consumed, by sha256).
# Options:
#   --remote        also ask each fork (git ls-remote) that its tag resolves to the pinned commit
#   --locks <dir>   also check that every hosted row of <dir>/guest/licenses/sources.lock for these
#                   components and the archive of <dir>/guest/kernel/linux.lock appear here with the
#                   same sha256 (<dir> = an xvm checkout; this repository is its submodule sources/)
# Needs only bash, git, sed/awk and sha256sum or shasum (curl is not used; --remote uses git).
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
INDEX="$ROOT/index.json"
REMOTE=0
LOCKS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --remote) REMOTE=1 ;;
    --locks) LOCKS="$2"; shift ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "verify.sh: unknown argument $1" >&2; exit 2 ;;
  esac
  shift
done

if command -v sha256sum >/dev/null 2>&1; then
  sha256() { sha256sum "$1" | cut -d' ' -f1; }
else
  sha256() { shasum -a 256 "$1" | cut -d' ' -f1; }
fi

fail=0
bad() { echo "FAIL $*"; fail=1; }
ok() { echo "ok   $*"; }

# index.json is written one value per line (components) and one object per line (files, archives);
# field() extracts "key": "value" or "key": number from one line.
field() { sed -n "s/.*\"$1\": *\"\{0,1\}\([^\",}]*\)\"\{0,1\}.*/\1/p" <<<"$2"; }

grep -q '"format": "xvm-sources/1"' "$INDEX" || bad "index.json: format is not xvm-sources/1"

if git -C "$ROOT" rev-parse -q --verify HEAD >/dev/null; then
  tree() { git -C "$ROOT" ls-tree HEAD -- "$1"; }
else
  tree() { git -C "$ROOT" ls-files -s -- "$1" | awk '{print $1, "commit", $2 "\t" $4}'; }
fi

ncomp=0; nfiles=0; narch=0
listed=""; archives=""; hashes=""   # newline-separated (no temp files)
name=""; path=""; repo=""; ref=""; commit=""

check_component() {
  [ -n "$name" ] || return 0
  ncomp=$((ncomp + 1))
  local t mode sha
  t=$(tree "$path")
  mode=$(awk '{print $1}' <<<"$t"); sha=$(awk '{print $3}' <<<"$t")
  if [ "$mode" = 160000 ] && [ "$sha" = "$commit" ]; then
    ok "$name: gitlink $path = $commit ($ref)"
  else
    bad "$name: gitlink $path is '${mode:-none} ${sha:-none}', index.json says $commit"
  fi
  local gm_path gm_url
  gm_path=$(git -C "$ROOT" config -f .gitmodules --get "submodule.$path.path" || true)
  gm_url=$(git -C "$ROOT" config -f .gitmodules --get "submodule.$path.url" || true)
  [ "$gm_path" = "$path" ] && [ "$gm_url" = "$repo.git" ] \
    || bad "$name: .gitmodules has path='$gm_path' url='$gm_url', expected '$path' '$repo.git'"
  if [ "$REMOTE" = 1 ]; then
    local refs peeled
    if refs=$(git ls-remote "$repo.git" "refs/tags/$ref" "refs/tags/$ref^{}" 2>&1); then
      peeled=$(awk -v r="refs/tags/$ref^{}" '$2==r {print $1}' <<<"$refs")
      [ -n "$peeled" ] || peeled=$(awk -v r="refs/tags/$ref" '$2==r {print $1}' <<<"$refs")
      if [ "$peeled" = "$commit" ]; then ok "$name: $repo tag $ref -> $commit"
      else bad "$name: $repo tag $ref -> '${peeled:-missing}', expected $commit"; fi
    else
      bad "$name: git ls-remote $repo.git failed: $(head -1 <<<"$refs")"
    fi
  fi
}

while IFS= read -r line; do
  case "$line" in
    '      "name": '*) check_component; name=$(field name "$line"); path=""; repo=""; ref=""; commit="" ;;
    '      "path": '*) path=$(field path "$line") ;;
    '      "repo": '*) repo=$(field repo "$line") ;;
    '      "ref": '*) ref=$(field ref "$line") ;;
    '      "commit": '*) commit=$(field commit "$line") ;;
    '        {"path": '*)
      nfiles=$((nfiles + 1))
      p=$(field path "$line"); want=$(field sha256 "$line")
      listed+="$p"$'\n'; hashes+="$want"$'\n'
      if [ ! -f "$ROOT/$p" ]; then bad "$name: $p missing"
      elif [ "$(sha256 "$ROOT/$p")" != "$want" ]; then bad "$name: $p sha256 differs from index.json"
      fi ;;
    '        {"file": '*)
      narch=$((narch + 1))
      archives+="$name	$(field file "$line")	$(field size "$line")	$(field sha256 "$line")	$(field url "$line")"$'\n'
      hashes+="$(field sha256 "$line")"$'\n' ;;
  esac
done <"$INDEX"
check_component

[ "$ncomp" -gt 0 ] && [ "$nfiles" -gt 0 ] && [ "$narch" -gt 0 ] \
  || bad "index.json: parsed $ncomp components, $nfiles files, $narch archives (layout changed?)"
[ "$fail" = 0 ] && ok "$nfiles files: sha256 = index.json"

# Every committed file under alpine/ is in index.json (ORIGIN.md excepted).
while IFS= read -r f; do
  case "$f" in */ORIGIN.md) continue ;; esac
  grep -qxF "$f" <<<"$listed" || bad "$f is committed but not listed in index.json"
done < <(git -C "$ROOT" ls-files -- alpine)

# Gitlinks in the tree that index.json does not describe.
while IFS= read -r p; do
  grep -q "^      \"path\": \"$p\"," "$INDEX" || bad "gitlink $p is not a component of index.json"
done < <(git -C "$ROOT" ls-files -s | awk '$1 == 160000 {print $4}')

if [ -n "$LOCKS" ]; then
  lock="$LOCKS/guest/licenses/sources.lock"; klock="$LOCKS/guest/kernel/linux.lock"
  n=0
  while read -r comp kind fname size sha url hosted; do
    case "$comp" in busybox|openjdk25) ;; *) continue ;; esac
    [ "$hosted" = yes ] || continue
    n=$((n + 1))
    grep -qxF "$sha" <<<"$hashes" || bad "sources.lock: $comp $kind $fname ($sha) has no entry in index.json"
  done < <(grep -v '^#' "$lock")
  ksha=$(sed -n 's/^LINUX_SHA256=//p' "$klock")
  grep -qxF "$ksha" <<<"$hashes" || bad "linux.lock: LINUX_SHA256 $ksha has no entry in index.json"
  [ "$n" -gt 0 ] || bad "sources.lock: no hosted busybox/openjdk25 rows read from $lock"
  ok "locks: $n hosted rows of sources.lock (busybox, openjdk25) + linux.lock all in index.json"
fi

echo
echo "Archives the xvm build consumed (each is git archive of the component's tag; see README.md):"
awk -F'\t' '{printf "  %-8s %-26s %11s  %s\n           %s\n", $1, $2, $3, $4, $5}' <<<"${archives%$'\n'}"
echo
if [ "$fail" = 0 ]; then echo "RESULT: ok ($ncomp components, $nfiles files, $narch archives)"; else echo "RESULT: FAILED"; exit 1; fi
