{
  description = "Limboole 1.2 boolean formula checker with PicoSAT";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      packageFor =
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        pkgs.stdenv.mkDerivation (finalAttrs: {
          pname = "limboole";
          version = "1.2";

          src = pkgs.fetchurl {
            url = "https://fmv.jku.at/limboole/limboole${finalAttrs.version}.tgz";
            hash = "sha256-/H7G21CI2ihGk35HJmjSg/ukbKjoQKr28T6hFhljfLY=";
          };

          buildInputs = [ pkgs.picosat ];

          # Upstream configure.sh only looks for backends in sibling source
          # directories. Fill its makefile template with Nix store paths instead.
          configurePhase = ''
            runHook preConfigure
            substitute makefile.in makefile \
              --subst-var-by CC "$CC" \
              --subst-var-by CFLAGS "-O3 -DNDEBUG -DVERSION=${finalAttrs.version} -DLIMBOOLE_USE_PICOSAT -I${pkgs.picosat}/include/picosat" \
              --subst-var-by LIBS "${pkgs.picosat}/lib/libpicosat.a" \
              --subst-var-by DEPS "${pkgs.picosat}/include/picosat/picosat.h ${pkgs.picosat}/lib/libpicosat.a"
            runHook postConfigure
          '';

          enableParallelBuilding = true;
          doCheck = true;
          # The release archive omits the log/ fixtures needed by testlimboole.
          checkPhase = ''
            runHook preCheck
            LIMBOOLE=./limboole DIMACS2BOOLE=./dimacs2boole \
              bash ${./tests/smoke.sh}
            runHook postCheck
          '';

          installPhase = ''
            runHook preInstall
            install -Dm755 limboole "$out/bin/limboole"
            install -Dm755 dimacs2boole "$out/bin/dimacs2boole"
            install -Dm644 README "$out/share/doc/limboole/README"
            install -Dm644 NEWS "$out/share/doc/limboole/NEWS"
            runHook postInstall
          '';

          meta = {
            description = "Check validity or satisfiability of boolean formulas and translate them to CNF";
            homepage = "https://fmv.jku.at/limboole/";
            # Upstream permits any use without warranty; PicoSAT is MIT-licensed.
            license = pkgs.lib.licenses.free;
            mainProgram = "limboole";
            platforms = systems;
          };
        });
    in
    {
      packages = forAllSystems (
        system:
        let
          limboole = packageFor system;
        in
        {
          inherit limboole;
          default = limboole;
        }
      );

      apps = forAllSystems (
        system:
        let
          app = {
            type = "app";
            program = "${packageFor system}/bin/limboole";
            meta.description = "Check validity or satisfiability of boolean formulas";
          };
        in
        {
          default = app;
          limboole = app;
          dimacs2boole = {
            type = "app";
            program = "${packageFor system}/bin/dimacs2boole";
            meta.description = "Translate DIMACS CNF into a boolean formula";
          };
        }
      );

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          limboole = packageFor system;
        in
        {
          smoke = pkgs.runCommand "limboole-smoke-tests" { } ''
            LIMBOOLE=${limboole}/bin/limboole \
              DIMACS2BOOLE=${limboole}/bin/dimacs2boole \
              bash ${./tests/smoke.sh}
            touch "$out"
          '';
        }
      );
    };
}
