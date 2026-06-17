{
  pkgs,
  image,
  architecture ? "x86_64",
  extraStorageGB ? 8,
}:
pkgs.writeShellScriptBin "repart-image-qemu" ''
  set -euo pipefail

  DISK_IMAGE="$(mktemp).raw"

  cp ${image}/image.raw "$DISK_IMAGE"
  chmod +w "$DISK_IMAGE"

  ${pkgs.qemu}/bin/qemu-img resize -f raw "$DISK_IMAGE" "+${builtins.toString extraStorageGB}G"

  ${pkgs.qemu}/bin/qemu-system-${architecture} \
    -smp 4 \
    -m 2048 \
    --enable-kvm \
    -cpu host \
    -bios "${pkgs.OVMF.fd}/FV/OVMF.fd" \
    -hda "$DISK_IMAGE" \
    -serial stdio \
    -display gtk
''
