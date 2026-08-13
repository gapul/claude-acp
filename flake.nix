{
  description = "claude-acp — an ACP adapter that lets Hermes run inference on a Claude subscription";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      forAll = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAll (pkgs: rec {
        # The shebang is pinned rather than left as /usr/bin/env python3: the adapter is stdlib-only,
        # so nothing is gained by inheriting whichever interpreter happens to be first on the PATH of
        # the process that spawned it — and on macOS that would be the system 3.9.
        claude-acp = pkgs.runCommand "claude-acp" { } ''
          mkdir -p $out/bin
          substitute ${./claude-acp} $out/bin/claude-acp \
            --replace '#!/usr/bin/env python3' '#!${pkgs.python3}/bin/python3'
          chmod +x $out/bin/claude-acp
        '';
        default = claude-acp;
      });
    };
}
