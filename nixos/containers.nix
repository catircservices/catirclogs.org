{ config, lib, pkgs, domain, hosts, ... }:

let
  irclogger = pkgs.callPackage ./pkgs/irclogger { ruby = pkgs.ruby_3_1; };

  mkConfig = { idx, cfg }: name: value:
    let
      hostAddress = "172.16.0.${toString (idx * 2)}";
      localAddress = "172.16.0.${toString (idx * 2 + 1)}";

      subdomain = "${name}.${domain}";
      port = 4000;

      defaultMeta = {
        enableLogger = true;
        enableBackup = true;
        watchdogTimeout = 600; # Copied from modules/irclogger.nix
        indexKey = "";
        channelKeys = {};
      };

      # Right hand side value has precedence in `lib.recursiveUpdate`.
      meta = if value ? meta then (lib.recursiveUpdate defaultMeta value.meta) else defaultMeta;
    in
    {
      idx = idx + 1;
      cfg = lib.recursiveUpdate cfg {
        # Create a new container per instance.
        containers = {
          "${name}-irclogger" = {
            autoStart = true;
            privateNetwork = true;

            inherit hostAddress localAddress;

            bindMounts = {
              "/var/backup" = {
                hostPath = "/var/backup/${name}";
                isReadOnly = false;
              };
            };

            config = { config, lib, pkgs, ... }: {
              imports = [
                ./modules/irclogger.nix
              ];

              services.irclogger = {
                enable = true;
                enableLogger = meta.enableLogger;
                package = irclogger;

                socket = "${localAddress}:${toString port}";

                # Strip out attributes we don't use directly.
                config = (removeAttrs value [ "meta" ] // {
                  domain = subdomain;
                });

                postgres.backup = meta.enableBackup;

                watchdog.timeout = meta.watchdogTimeout;
              };

              networking.firewall = {
                allowedTCPPorts = [ port ];
              };

              system.stateVersion = "24.05";
            };
          };
        };

        # Ensure the path exists on the host.
        # There seems to be a race condition here, although in the absolute worst
        # case the paths can be created manually. Far from ideal, but it works.
        systemd = {
          tmpfiles.rules = [ "d /var/backup/${name} 700 - - -" ];
        };

        # Add an entry to nginx.
        services.nginx = {
          virtualHosts = {
            "${subdomain}" = {
              forceSSL = true;
              enableACME = true;

              root = "${irclogger}/opt/irclogger/public";

              locations = {
                "/".extraConfig = ''
                  set $allow 1;

                  if ($uri ~ ^/[^/]+/index/) {
                    set $allow 0;
                  }
                  if ($cookie_access_key = "${meta.indexKey}") {
                    set $allow 1;
                  }

                  ${
                    lib.foldlAttrs (acc: channel: access_key:
                    let
                      fragment = ''
                        if ($uri ~ ^/${channel}/) {
                          set $allow 0;
                        }
                        if ($cookie_access_key = "${access_key}") {
                          set $allow 1;
                        }
                      '';
                    in
                      fragment + acc) "" meta.channelKeys
                  }

                  if ($allow = 0) {
                    return 401;
                  }

                  # Some search queries execute extremely slowly.
                  proxy_send_timeout 180s;
                  proxy_read_timeout 180s;
                  if (!-f $request_filename) {
                    proxy_pass http://unix:${config.services.anubis.instances.${name}.settings.BIND};
                  }
                '';

                "~ ^/([^/\\s]+)/access_key/([A-Za-z0-9]+)".extraConfig = ''
                  add_header Set-Cookie "access_key=$2; Max-Age=315360000; Path=/; HttpOnly";
                  return 303 "$scheme://$host/$1/";
                '';
              };
            };
          };
        };

        # Configure anubis.
        services.anubis = {
          instances.${name} = {
            settings = {
              TARGET = "http://${localAddress}:${toString port}";
            };
          };
        };
      };
    };
in
  (lib.foldlAttrs mkConfig ({ idx = 0; cfg = { }; }) hosts).cfg
