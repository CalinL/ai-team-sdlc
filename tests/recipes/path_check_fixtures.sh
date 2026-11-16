#!/usr/bin/env bash
# Tier 2 — path-check fixtures (bash), run against the recipe as published in the plugin reference.
# 1–15 are spec 1.1.1 §8.3; 16–23 are the 1.1.1 review findings (aliases, spaces, literal status, clean
# baseline, case, combined aliases, case-aliased receipts, status without a colon). 24–28 guard bash/PowerShell
# parity of the watch-list glob expansion.
# Usage: bash tests/recipes/path_check_fixtures.sh <lib.sh> <work-dir>
set -u
LIB=$1; WORK=$2
# shellcheck disable=SC1090
source "$LIB"
OK=0; BAD=0
mkdir -p "$WORK" && WORK=$(cd "$WORK" && pwd) || exit 2
export GIT_CEILING_DIRECTORIES=$(cd "$WORK" && { pwd -W 2>/dev/null || pwd; })   # native path (Git Bash: C:/...)   # git never walks up into a parent repository

setup() {   # fresh repo with the spec 1.1.1 §5.1 config
  cd "$WORK" || exit 2; rm -rf "$WORK/r"; [ ! -e "$WORK/r" ] || { echo "cannot remove $WORK/r"; exit 2; }
  mkdir -p "$WORK/r" && cd "$WORK/r" || exit 2
  git init -q && [ "$(git rev-parse --git-dir)" = .git ] || { echo "not an isolated repo: $(pwd)"; exit 2; }
  git config user.name t; git config user.email t@example.com; git config core.autocrlf false
  git config core.ignorecase false
  mkdir -p .github delivery specs architecture/adr src
  printf '.copilot-tracking/\ndelivery/brief.md\n' > .gitignore
  printf 'contract:\n  brief: delivery/brief.md\n' > .github/ai-sdlc.yml
  printf '# Brief\n' > delivery/brief.md
  printf '# PRD\n- REQ-1\n' > specs/prd.md
  printf '# ADR-003\nStatus: Accepted\n' > architecture/adr/003-x.md
  printf '# Overview\n' > architecture/overview.md
  printf '# Approvals\n- sign-off\n' > delivery/approvals.md
  printf 'a\n' > src/app.js; printf 'keep\n' > src/dirty.js
  git add -A && git commit -qm base
  printf 'dirty before baseline\n' > src/dirty.js          # fixture 12: dirty at baseline, left alone
  export PC_FROZEN='' PC_PROTECTED='architecture/' PC_DECISIONS_DIR='architecture/adr/' PC_PROPOSED='Proposed' PC_COMMAND=''
  export PC_INPUTS=$'delivery/brief.md\nspecs/prd.md\n.github/ai-sdlc.yml\ndelivery/approvals.md'
  export PC_GATES=$'specs/ui/ACCEPTED.md\ndelivery/conformance/*.md\ndelivery/results/acceptance-*.md'
  W=(delivery/brief.md specs/prd.md .github/ai-sdlc.yml delivery/approvals.md specs/ui/ACCEPTED.md 'delivery/conformance/*.md' 'delivery/results/acceptance-*.md')
  B=.copilot-tracking/run/baselines/T-001
}
base() { path_check baseline "$B" "${W[@]}"; }
run() {   # $1 = fixture name, $2 = expected (pass|fail)
  local res rc got
  res=$(path_check changed "$B" "${W[@]}" | path_check_classify "$B"); rc=$?
  got=pass; [ $rc -ne 0 ] && got=fail
  if [ "$got" = "$2" ]; then OK=$((OK + 1)); s=OK; else BAD=$((BAD + 1)); s=BAD; fi
  printf '%-4s %-72s expected=%-4s got=%-4s %s\n' "$s" "$1" "$2" "$got" "$(echo "$res" | tr '\n' ';')"
}

setup; base; mkdir -p delivery/results; echo r > delivery/results/qa-001.md;             run "01 adds delivery/results/qa-001.md" pass
setup; base; mkdir -p delivery/results; echo r > delivery/results/acceptance-abc123.md; run "02 adds delivery/results/acceptance-abc123.md" fail
setup; base; mkdir -p delivery/conformance; echo r > delivery/conformance/001-x.md;     run "03 adds delivery/conformance/001-x.md" fail
setup; base; mkdir -p specs/ui; echo r > specs/ui/ACCEPTED.md;                         run "04 adds specs/ui/ACCEPTED.md" fail
setup; base; echo edited >> delivery/brief.md;                                          run "05 edits gitignored delivery/brief.md" fail
setup; base; echo '- REQ-2' >> specs/prd.md; git commit -qam prd;                      run "06 commits an edit to specs/prd.md" fail
setup; base; rm .github/ai-sdlc.yml;                                                    run "07 deletes .github/ai-sdlc.yml" fail
setup; base; printf '# ADR-014\nStatus: Proposed\n' > architecture/adr/014-cache.md;     run "08 adds Proposed architecture/adr/014-cache.md" pass
setup; base; echo 'more' >> architecture/adr/003-x.md;                                 run "09 edits Accepted architecture/adr/003-x.md" fail
setup; base; echo t > architecture/threat-model.md;                                     run "10 adds architecture/threat-model.md" fail
setup; export PC_DECISIONS_DIR='delivery/'; base; mkdir -p delivery/results; printf 'status: Proposed\n' > delivery/results/acceptance-v1.md
                                                                                         run "11 decisions.dir=delivery/, adds Proposed acceptance-v1.md" fail
setup; base;                                                                            run "12 dirty-at-baseline file left alone" pass
setup; base; echo '- waiver' >> delivery/approvals.md;                                  run "13 appends a waiver to delivery/approvals.md" fail
setup; export PC_COMMAND='exit 1'; base;                                                run "14 no changes, path_check exits 1" fail
setup; export PC_COMMAND='exit 1'; base; printf '# ADR-015\nStatus: Proposed\n' > architecture/adr/015-x.md
                                                                                         run "15 adds Proposed adr/015-x.md, path_check exits 1" fail
setup; export PC_FROZEN='./tests/contract/'; base; mkdir -p tests/contract; echo x > tests/contract/eval.json
                                                                                         run "16 frozen ./tests/contract/, adds tests/contract/eval.json" fail
setup; printf 'delivery receipts/\n' >> .gitignore; git commit -qam ign; export PC_GATES="$PC_GATES"$'\ndelivery receipts/*.md'
W+=('delivery receipts/*.md'); mkdir -p 'delivery receipts'; echo old > 'delivery receipts/001-x.md'; base
echo new > 'delivery receipts/001-x.md'; echo r > 'delivery receipts/002-y.md';         run "17 gitignored gate folder with a space: edits and adds receipts" fail
setup; export PC_PROPOSED='Proposed (unapproved)'; base; printf '# ADR-016\nStatus: Proposed (unapproved)\n' > architecture/adr/016-x.md
                                                                                         run "18 proposed_status 'Proposed (unapproved)', adds such a record" pass
setup; git checkout -q -- src/dirty.js; base; mkdir -p delivery/results; echo r > delivery/results/qa-002.md
                                                                                         run "19 clean tree at baseline, adds delivery/results/qa-002.md" pass
setup; git config core.ignorecase true; export PC_PROTECTED='Architecture/'; base; echo t > architecture/threat-model.md
                                                                                         run "20 protected Architecture/ (ignorecase), adds architecture/threat-model.md" fail
setup; export PC_FROZEN='.//tests/contract/'; base; mkdir -p tests/contract; echo x > tests/contract/eval.json
                                                                                         run "21 frozen .//tests/contract/, adds tests/contract/eval.json" fail
setup; git config core.ignorecase true; printf 'delivery/results/\n' >> .gitignore; git commit -qam ign; base
mkdir -p delivery/results; echo r > delivery/results/ACCEPTANCE-abc.md;                 run "22 ignorecase, gitignored results/, adds ACCEPTANCE-abc.md" fail
setup; base; printf '# ADR-017\nstatus: Accepted\nStatusProposed\n' > architecture/adr/017-x.md
                                                                                         run "23 new record 'status: Accepted' + line 'StatusProposed'" fail
setup; printf 'delivery/results/\n' >> .gitignore; git commit -qam ign; mkdir -p delivery/results/acceptance-x; echo old > delivery/results/acceptance-x/n.md; base
echo new > delivery/results/acceptance-x/n.md;                                           run "24 parity: watch glob '*' does not cross '/' (ignored nested file)" pass
setup; printf 'evidence/\n' >> .gitignore; git commit -qam ign; export PC_GATES="$PC_GATES"$'\nevidence/**/*.md'; W+=('evidence/**/*.md')
mkdir -p evidence/x; echo old > evidence/x/y.md; base; echo new > evidence/x/y.md;      run "25 parity: a whole '**' component spans folders (ignored nested gate file)" fail
setup; printf 'logs/\n' >> .gitignore; git commit -qam ign; export PC_GATES="$PC_GATES"$'\nlogs/**/gate/*.md'; W+=('logs/**/gate/*.md')
mkdir -p logs/a/gate/sub; echo old > logs/a/gate/sub/x.md; base; echo new > logs/a/gate/sub/x.md
                                                                                         run "26 parity: '*' after '**' still stays in one folder" pass
setup; base; mkdir -p delivery/results/acceptance-x; echo r > delivery/results/acceptance-x/n.md
                                                                                         run "27 tracked: a file one folder below a gate glob is not a receipt" pass
setup; export PC_GATES="$PC_GATES"$'\ndelivery/results/acceptance[!x]*.md\ndelivery/results/acceptance[^y]*.md'; base; mkdir -p delivery/results/acceptance; echo r > delivery/results/acceptance/n.md
                                                                                         run "28 a negated bracket ('[!x]' or '[^y]') never matches '/'" pass

echo; echo "path-check (bash): $OK/$((OK + BAD)) fixtures as expected"
[ "$BAD" -eq 0 ]
