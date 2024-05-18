#!/bin/sh

ssh root@catirclogs.org "nix-channel --update && nixos-rebuild boot && reboot"
