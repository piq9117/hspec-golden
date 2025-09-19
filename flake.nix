{
  inputs.nixpkgs.url = github:NixOS/nixpkgs/nixos-24.05;
  outputs = {self, nixpkgs}: 
    let
      # forAllSystems = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;
      forAllSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux"
      ];
      nixpkgsFor = forAllSystems(system: import nixpkgs {
        inherit system;
        overlays = [ self.overlay ];
      });
    in {
      overlay = final: prev: {
        hsPkgs = prev.haskell.packages.ghc945.override {
          overrides = hfinal: hprev: { };
        }; 
        hspec-golden = final.hsPkgs.callCabal2nix "hspec-golden" ./. {};
      };

      packages = forAllSystems(system: 
        let
          pkgs = nixpkgsFor.${system};
        in {
          hspec-golden = pkgs.hspec-golden;
        });

      devShells = forAllSystems(system: 
        let
          pkgs = nixpkgsFor.${system};
          stack-wrapped = pkgs.symlinkJoin {
            name = "stack";
            paths = [ pkgs.stack ];
            buildInputs = [ pkgs.makeWrapper ];
            postBuild = ''
              wrapProgram $out/bin/stack \
                --add-flags "\
                  --no-nix \
                  --system-ghc \
                  --no-install-ghc \
                "
            '';
          };

          devTools = with pkgs; [
                zlib
                hsPkgs.ghc
                hsPkgs.haskell-language-server
                hsPkgs.hpack
                stack-wrapped
                hsPkgs.cabal-install
                # self.packages.${system}.hspec-golden
          ];
        in {
          default = pkgs.mkShell {
            buildInputs = devTools;
            withHoogle = true;
            shellHook = ''
              export PS1='[$PWD]\n❄ '
              export NIX_GHC="${pkgs.hsPkgs.ghc}/bin/ghc"
            '';
            LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath devTools;
          };
        });
    };
}
