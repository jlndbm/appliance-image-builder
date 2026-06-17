# Appliance Image Builder

Small NixOS library to create a flake output for building an
image that can be flashed to a USB or tested in QEMU.

When the image boots up, it uses systemd-repart to repartition
the USB so it uses the full disk.

Largely inspired by this blog post:
[[https://nixcademy.com/posts/auto-growing-nixos-appliance-images-with-systemd-repart/]].


## Installation

Add `aib.url = github:jlndbm/appliance-image-builder;` to a
`flake.nix` file.


## Usage

There is an example in the `flake.nix` file.
