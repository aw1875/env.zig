{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    # git is needed on macOS due to a bug where the system git is not found
    (pkgs.lib.optional pkgs.stdenv.isDarwin git)

    zig
    zls

  ];

  shellHook = ''
    echo "Zig version: $(zig version)"
  '';
}
