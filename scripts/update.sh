#!/bin/sh

ssh root@catircservices.org "nix-channel --update && nixos-rebuild boot && reboot"
