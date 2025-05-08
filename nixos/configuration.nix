{ config, lib, pkgs, ... }:
let
  siteConfig = lib.importTOML (./. + "/site/config.toml");
  siteSecrets = lib.importTOML (./. + "/site/secrets.toml");

  # Only merge secrets for hosts that we want to also deploy.
  hosts = lib.mapAttrs (host: data:
    if siteSecrets.irc ? ${host} then
      lib.recursiveUpdate data siteSecrets.irc.${host}
    else
      data) siteConfig.irc;

  domain = siteConfig.serverName;
in {
  # System
  imports = [
    ./hardware-configuration.nix
    ./networking.nix
    (import ./containers.nix { inherit lib pkgs domain hosts; })
  ];

  nix.gc = {
    automatic = true;
    options = "--delete-older-than 30d";
  };

  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;

  # SSH
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
  };
  users.users.root.openssh.authorizedKeys.keys = siteConfig.ssh.pubkeys;

  # TLS certificates
  security.acme = {
    acceptTerms = true;
    defaults = { email = siteConfig.web.acmeEmail; };
  };
  users.users.nginx.extraGroups = [ "acme" ];

  # Web reverse proxy server
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;

    virtualHosts = {
      "${domain}" = {
        forceSSL = true;
        enableACME = true;

        # HTML banner at the root
        locations."=/".extraConfig = "
          default_type text/html;
          charset utf-8;
          return 200 \"${builtins.replaceStrings ["\n" "\""] ["\\n" "\\\""] siteConfig.web.banner}\";
        ";
      };
    } // lib.mapAttrs (domain: target: {
      forceSSL = true;
      enableACME = true;

      locations."/".extraConfig = "
        return 301 ${target}\$request_uri;
      ";
    }) siteConfig.web.redirects;
  };

  # Firewall
  networking.firewall = {
    allowedTCPPorts = [ 80 443 ];
    allowedUDPPorts = [ 80 443 ];
  };

  # Backup
  services.restic.backups = lib.mkIf siteConfig.backup.restic {
    all = {
      repository = siteSecrets.restic.repository;
      passwordFile = "${pkgs.writeText "password" siteSecrets.restic.password}";
      environmentFile = "${pkgs.writeText "environment" siteSecrets.restic.environment}";
      initialize = true;
      paths = [
        "/etc/nixos"
        "/var/backup"
      ];
    };
  };

  system.stateVersion = "23.05";
}
