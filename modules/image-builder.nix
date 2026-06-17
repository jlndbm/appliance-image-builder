{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:
let
  cfg = config.aib;

  getLabel = mountPoint: lib.removePrefix "/" mountPoint;

  generateFileSystem =
    mountPoint: partition:
    lib.nameValuePair mountPoint {
      device = "/dev/disk/by-partlabel/${getLabel mountPoint}";
      fsType = partition.format;
    };

  partitionType =
    label:
    if
      builtins.elem label [
        "home"
        "srv"
        "var"
        "tmp"
        "usr"
        "swap"
        "root"
      ]
    then
      label
    else
      "linux-generic";

  generateRepartPartition =
    mountPoint: partition:
    let
      label = lib.removePrefix "/" mountPoint;
    in
    lib.nameValuePair label {
      Format = partition.format;
      Label = label;
      Type = partitionType label;
      Weight = partition.weight;
    };
in
{
  imports = [
    (modulesPath + "/profiles/image-based-appliance.nix") # Disable rebuilding and nix toolchain
    (modulesPath + "/image/repart.nix")
  ];

  options.aib = {
    enable = lib.mkEnableOption "Enable the image builder configuration";

    device = lib.mkOption {
      type = lib.types.str;
      description = ''
        The device that will be repartitioned during the first boot.
        Prefer /dev/disk/by-id paths over /dev/sdX paths.
      '';
    };

    partitions = lib.mkOption {
      description = "Partitions created by systemd-repart on first boot.";

      default = { };

      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            format = lib.mkOption {
              type = lib.types.str;
              example = "ext4";
            };

            weight = lib.mkOption {
              type = lib.types.int;
              default = 1000;
            };
          };
        }
      );
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.all (p: lib.hasPrefix "/" p) (lib.attrNames cfg.partitions);
        message = "aib.partitions keys must be mount points (e.g. /var, /home)";
      }
      {
        assertion = lib.all (p: builtins.match "^/[^/]+$" p != null) (lib.attrNames cfg.partitions);
        message = "aib.partitions keys must be mount points in /";
      }
    ];

    # The configuration will use EFI directly to boot.
    boot.loader.grub.enable = false;

    # Enable all storage interface kernel modules at startup.
    boot.initrd.kernelModules = [
      "xhci_pci"
      "ehci_pci"
      "ahci"
      "usb_storage"
      "uas"
      "sd_mod"
    ];

    # Wait for the root partition to be mounted
    boot.kernelParams = [ "rootwait" ];

    # This increases the image size by about 1GB, but makes it work on virtually
    # all devices.
    hardware.enableRedistributableFirmware = true;
    hardware.enableAllHardware = true;

    fileSystems = {
      "/" = {
        fsType = "tmpfs";
        options = [ "size=100m" ];
      };
      "/boot" = {
        device = "/dev/disk/by-partlabel/boot";
        fsType = "vfat";
      };
      "/nix/store" = {
        device = "/dev/disk/by-partlabel/nix-store";
        fsType = "squashfs";
      };
    }
    // (lib.mapAttrs' generateFileSystem cfg.partitions);

    image.repart =
      let
        inherit (pkgs.stdenv.hostPlatform) efiArch;
      in
      {
        name = "image";

        partitions = {
          esp = {
            contents = {
              "/EFI/BOOT/BOOT${lib.toUpper efiArch}.EFI".source =
                "${pkgs.systemd}/lib/systemd/boot/efi/systemd-boot${efiArch}.efi";

              "/EFI/Linux/${config.system.boot.loader.ukiFile}".source =
                "${config.system.build.uki}/${config.system.boot.loader.ukiFile}";
            };
            repartConfig = {
              Format = "vfat";
              Label = "boot";
              SizeMinBytes = "200M";
              Type = "esp";
            };
          };
          nix-store = {
            storePaths = [ config.system.build.toplevel ];
            nixStorePrefix = "/";
            repartConfig = {
              Format = "squashfs";
              Label = "nix-store";
              Minimize = "guess";
              ReadOnly = "yes";
              Type = "linux-generic";
            };
          };
        };
      };

    systemd.repart.partitions = lib.mapAttrs' generateRepartPartition cfg.partitions;

    boot.initrd.systemd.repart.enable = true;
    boot.initrd.systemd.repart.device = cfg.device;

    # Before initialization we want to mount the nix store and var to avoid a
    # racecondition.
    boot.initrd.systemd.services.systemd-repart.before = [
      "sysroot-nix-store.mount"
    ]
    ++ map (mountPoint: "sysroot-${getLabel mountPoint}.mount") (lib.attrNames cfg.partitions);
  };
}
