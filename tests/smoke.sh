#!/usr/bin/env bash
set -euo pipefail

L=${LIMBOOLE:-limboole}
D=${DIMACS2BOOLE:-dimacs2boole}

check() {
  local formula=$1 expected=$2 output
  shift 2
  output=$(printf '%s\n' "$formula" | "$L" "$@")
  if ! grep -Fxq "$expected" <<< "$output"; then
    printf 'Unexpected result for %s:\n%s\n' "$formula" "$output" >&2
    exit 1
  fi
}

"$L" --version | grep -Fx 'This is Limboole version 1.2'
"$L" -h | grep -F 'usage: limboole'
check 'a | !a' '% VALID formula'
check 'a' '% INVALID formula (falsifying assignment follows)'
check '(a -> b) <-> (!b -> !a)' '% VALID formula'
check 'a & b' '% SATISFIABLE formula (satisfying assignment follows)' -s
check 'a & !a' '% UNSATISFIABLE formula' -s
check '(a -> b) & a & !b' '% UNSATISFIABLE formula' -s

if output=$(printf 'a &\n' | "$L" 2>&1); then
  echo 'Invalid input unexpectedly accepted' >&2
  exit 1
else
  test "$?" -eq 1
  grep -Fq 'parse error' <<< "$output"
fi

if "$L" --not-an-option > /dev/null 2>&1; then
  echo 'Invalid option unexpectedly accepted' >&2
  exit 1
else
  test "$?" -eq 1
fi

# CNF encodes the original formula with -s, its negation without -s.
output=$(printf 'a\n' | "$L" -s -d)
test "$output" = "$(printf 'c 1 a\np cnf 1 1\n1 0\n')"
output=$(printf 'a\n' | "$L" -d)
test "$output" = "$(printf 'c 1 a\np cnf 1 1\n-1 0\n')"

boole=$(printf 'c smoke\np cnf 1 1\n1 0\n' | "$D")
test "$boole" = '(v1)'
check "$boole" '% SATISFIABLE formula (satisfying assignment follows)' -s
boole=$(printf 'p cnf 1 2\n1 0\n-1 0\n' | "$D")
check "$boole" '% UNSATISFIABLE formula' -s

# Exercise file input and output as well as stdin.
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
printf 'a | !a\n' > "$work/formula.boole"
"$L" -o "$work/result" "$work/formula.boole"
grep -Fxq '% VALID formula' "$work/result"

echo 'Limboole smoke tests passed'
