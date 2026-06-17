{
  description = "Description for the project";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    inputs@{
      self,
      flake-parts,
      nixpkgs,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
      ];
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      perSystem =
        {
          config,
          self',
          inputs',
          pkgs,
          system,
          ...
        }:
        {
          packages = {

            test-image = self.lib.makeImage {
              inherit nixpkgs;
              system = "x86_64-linux";
              # Prefer /dev/disk/by-id/, but for qemu /dev/sda is fine.
              device = "/dev/sda";
              modules = [
                {
                  # Auto login to root user
                  users.users.root.initialPassword = "";
                  services.getty.autologinUser = "root";

                  # Enable wireless networking.
                  networking.networkmanager.enable = true;
                  networking.wireless.enable = true;
                }
              ];
              partitions = {
                "/var" = {
                  format = "ext4";
                  weight = 1000;
                };
              };
            };

            default = pkgs.callPackage ./lib/run-image.nix {
              inherit pkgs;
              image = self.packages.x86_64-linux.test-image;
            };

          };

          devShells.default = pkgs.mkShell {
            packages = [
              pkgs.nil
            ];
          };

        };

      flake = {
        nixosModules.default = import ./modules/image-builder.nix;
        lib.makeImage = import ./lib/make-image.nix { inherit self; };
        lib.runImage = import ./lib/run-image.nix;
      };
    };
}
