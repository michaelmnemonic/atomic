{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }: {

    devShell.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.pkgs.mkShell {
      buildInputs = with nixpkgs.legacyPackages.x86_64-linux.pkgs; [
        mkosi
        debootstrap
      ];
    };

    devShell.aarch64-linux = (nixpkgs.legacyPackages.aarch64-linux.pkgs.buildFHSEnv {
      name ="mkosi-env";
      targetPkgs = pkgs: (with pkgs; [
        apt
        debootstrap
        dpkg
        e2fsprogs
        erofs-utils
        gnupg
        mkosi
      ]);
      extraBuildCommands = ''
        ln -s ${./keyrings} $out/usr/share/keyrings
      '';
      runScript = "bash";
    }).env;
  };
}