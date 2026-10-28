{
  description = "A minimal Mation counter";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    purs-nix.url = "github:purs-nix/purs-nix/ps-0.15";
    shelpers.url = "gitlab:platonic/shelpers";

    mation = {
      url = "github:Quelklef/mation";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.purs-nix.follows = "purs-nix";
    };
  };

  outputs = inputs@{ flake-utils, nixpkgs, purs-nix, shelpers, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        purs-nix' = purs-nix { inherit pkgs system; };
        mation = purs-nix'.build {
          name = "mation";
          src.path = inputs.mation;
          info = {
            src = "mation";
            dependencies = [
              "prelude"
              "console"
              "effect"
              "maybe"
              "either"
              "tuples"
              "strings"
              "foreign"
              "foldable-traversable"
              "profunctor-lenses"
              "unlift"
              "nullable"
              "aff-promise"
            ];
          };
        };
        ps = purs-nix'.purs {
          dir = ./.;
          dependencies = [
            mation
            "prelude"
            "effect"
            "contravariant"
          ];
        };
        purs-command = ps.command {
          output = "out/purs-cache";
          bundle.esbuild = {
            format = "iife";
            outfile = "out/main.js";
          };
        };
        page = pkgs.writeText "index.html" ''
          <!doctype html>
          <html lang="en">
            <head>
              <meta charset="utf-8">
              <meta name="viewport" content="width=device-width, initial-scale=1">
              <title>Mation counter</title>
              <script defer src="main.js"></script>
            </head>
            <body></body>
          </html>
        '';
        site = pkgs.runCommand "mation-counter" { } ''
          mkdir -p $out
          cp ${ps.bundle { esbuild.format = "iife"; }} $out/main.js
          cp ${page} $out/index.html
        '';
        shelpers' = (shelpers.lib pkgs).eval-shelpers [
          ({ config, shelp, ... }: {
            shelpers."."."Development" = {
              inherit shelp;

              compile = {
                description = "Build the browser app into ./out";
                make-app = true;
                script = ''
                  mkdir -p out
                  ${purs-command}/bin/purs-nix bundle
                  # The Nix store page is read-only, so materialize a replaceable local copy
                  rm -f out/index.html
                  ${pkgs.coreutils}/bin/install -m 644 ${page} out/index.html
                  echo "Built ./out/index.html"
                '';
              };

              watch = {
                description = "Rebuild the app whenever a PureScript source file changes";
                make-app = true;
                script = ''
                  ${config.apps.compile.program}
                  find src -type f -name '*.purs' -print \
                    | ${pkgs.entr}/bin/entr -nps ${config.apps.compile.program}
                '';
              };
            };
          })
        ];
      in
      {
        apps = shelpers'.apps;
        packages.default = site;
        shelpers = shelpers'.files;

        devShells.default = pkgs.mkShell {
          packages = [
            purs-command
            pkgs.entr
          ];
          shellHook = ''
            ${shelpers'.functions}
            shelp
          '';
        };
      });
}
