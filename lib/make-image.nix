{ self }:

{
  nixpkgs,
  system,
  device,
  partitions ? { },
  modules ? [ ],
}:

let
  aibModule = {
    aib = {
      enable = true;
      inherit device;
      inherit partitions;
    };
  };

  nixos = nixpkgs.lib.nixosSystem {
    inherit system;
    modules = [
      self.nixosModules.default
      aibModule
    ]
    ++ modules;
  };
in
nixos.config.system.build.image
