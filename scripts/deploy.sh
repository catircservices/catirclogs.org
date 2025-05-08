#!/bin/sh

rsync -vrt --delete --delete-excluded nixos/ root@catirclogs.org:/etc/nixos
ssh root@catirclogs.org "nixos-rebuild switch --show-trace"
