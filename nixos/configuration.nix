{ pkgs, lib, config, ... }:
let
  siteConfig = lib.importTOML (./. + "/site/config.toml");
  siteSecrets = lib.importTOML (./. + "/site/secrets.toml");
in {
  system.stateVersion = "23.05";

  # System
  imports = [
    ./hardware-configuration.nix
    ./networking.nix
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
  users.users.nginx.extraGroups = ["acme"];

  # Web reverse proxy server
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;

    virtualHosts = {
      "${siteConfig.serverName}" = {
        forceSSL = true;
        enableACME = true;

        # HTML banner at the root
        locations."=/".extraConfig = "
          default_type text/html;
          charset utf-8;
          return 200 \"${builtins.replaceStrings ["\n" "\""] ["\\n" "\\\""] siteConfig.web.banner}\";
        ";
      };
    };
  };

  # Firewall
  networking.firewall = {
    allowedTCPPorts = [ 80 443 ];
    allowedUDPPorts = [ 80 443 ];
  };

  # Backup
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) ["tarsnap"];
  services.tarsnap = {
    enable = siteConfig.backup.enable;
    keyfile = "${pkgs.writeText "tarsnap.key" siteSecrets.tarsnap.keyfile}";
    archives."${siteConfig.serverName}" = {
      directories = [
        "/etc/nixos"
        "/var/backup"
      ];
      excludes = [];
    };
  };
}
