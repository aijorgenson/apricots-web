{
  description = "Dev shell for building Apricots to a single-file WebAssembly page";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              emscripten
              python3
              nodejs
            ];

            shellHook = ''
              # The nixpkgs emscripten wrapper already points EM_CACHE at a
              # writable location (locate_cache.sh), so emcc can compile the
              # SDL2/OpenAL ports it needs without touching the nix store.
              # Do not override EM_CACHE here: a path under $HOME would leak
              # into the wasm via __FILE__ in port sources.
              echo "Build with: wasm/build.sh"
            '';
          };
        }
      );
    };
}
