# limboole-nix

Builds [Limboole](https://fmv.jku.at/limboole/) **1.2** from the upstream
`limboole1.2.tgz` source archive, with the PicoSAT 965 SAT backend from Nixpkgs.
The archive's hash and the Nixpkgs revision (`flake.lock`) are pinned.

Requires Nix with `nix-command` and `flakes` enabled.

## Use

Run directly from GitHub without cloning:

```sh
nix run github:rschaffar/limboole-nix -- -h
printf 'a | !a\n' | nix run github:rschaffar/limboole-nix
```

Or, from a local checkout:

```sh
nix build                          # result/bin/{limboole,dimacs2boole}
nix run . -- -h                    # command-line help
nix run . -- --version
printf 'a | !a\n' | nix run .       # % VALID formula (default: validity)
printf 'a & !a\n' | nix run . -- -s # % UNSATISFIABLE formula
nix run . -- formula.boole         # read a file instead of stdin
printf 'a & b\n' | nix run . -- -s -d # translate to DIMACS CNF
printf 'p cnf 1 1\n1 0\n' | nix run .#dimacs2boole
```

`nix run .#limboole` is an explicit alias for the default app. Both executables
are included in the default package. PicoSAT is linked statically; no separate
solver installation is necessary.

The formula syntax supports `!`, `&`, `|`, `->`, `<-`, `<->`, and parentheses.
Without `-s`, `-d` generates CNF for the **negation** of the input formula.
Successful SAT, UNSAT, VALID and INVALID results all exit with status 0; parse
and command-line errors exit with status 1. Quantified formulas/DepQBF and the
Lingeling backend are not enabled in this package.

## Tests

```sh
nix flake check -L
LIMBOOLE=./result/bin/limboole DIMACS2BOOLE=./result/bin/dimacs2boole \
  bash tests/smoke.sh
```

The smoke suite runs during the package build and again against the installed
executables in `nix flake check`. It covers validity, invalidity, SAT, UNSAT,
implication/equivalence, malformed input/options, CNF polarity, DIMACS conversion,
and file input/output.

The upstream archive contains `test.c` but omits its required `log/` fixtures;
its golden-output suite cannot run as shipped. The smoke suite does not depend
on particular solver assignments.

The flake exposes x86_64/aarch64 Linux and macOS outputs. Build and runtime tests
have been performed on **x86_64-linux** only.

Upstream permits any use of Limboole without warranty and specifies no formal
license. The linked PicoSAT backend is MIT-licensed.
