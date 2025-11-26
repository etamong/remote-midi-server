{
  description = "Remote MIDI Server - Web-based MIDI controller for QLab";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
          };
        };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Go toolchain
            go
            gopls
            gotools
            go-tools

            # Build tools
            pkg-config
            clang
          ];

          shellHook = ''
            echo "🎹 Remote MIDI Server development environment"
            echo "Go version: $(go version)"
            echo ""
            echo "Available commands:"
            echo "  make build   - Build the server"
            echo "  make run     - Run the server"
            echo "  make install - Install Go dependencies"
            echo ""
            echo "Note: This project uses CGO and requires macOS frameworks for MIDI support."
            echo "The gomidi library includes RtMidi sources, so no external MIDI library is needed."
            echo ""
          '';

          # CGO flags for macOS
          CGO_ENABLED = "1";
        };

        packages.default = pkgs.buildGoModule {
          pname = "remote-midi-server";
          version = "0.1.0";

          src = ./.;

          vendorHash = null;

          nativeBuildInputs = with pkgs; [
            pkg-config
            clang
          ];

          env = {
            CGO_ENABLED = "1";
          };

          ldflags = [
            "-s"
            "-w"
          ];

          postInstall = ''
            mkdir -p $out/share/remote-midi-server
            cp -r web $out/share/remote-midi-server/
            cp config.yaml $out/share/remote-midi-server/
          '';

          meta = with pkgs.lib; {
            description = "Web-based MIDI controller for QLab";
            homepage = "https://github.com/etamong/remote-midi-server";
            license = licenses.mit;
            platforms = platforms.darwin;
          };
        };
      }
    );
}
