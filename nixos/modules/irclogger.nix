{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.irclogger;
  format = pkgs.formats.yaml { };
  configFile = format.generate "config.yaml" ({
    files = cfg.files;
    watchdog = {
      timeout = cfg.watchdog.timeout;
      respawn = false;
    };

    database = "postgres://${cfg.postgres.host}:${builtins.toString cfg.postgres.port}/${cfg.postgres.database}";
    redis = "redis://${cfg.redis.host}:${builtins.toString cfg.redis.port}";
    web = "${cfg.socket}";

    daemonize = false;
  } // cfg.config);

  additionalTargets = []
    ++ optional cfg.redis.createLocally "redis-irclogger.service"
    ++ optional cfg.postgres.createLocally "postgresql.service";
in
{
  options = {
    services.irclogger = {
      enable = mkEnableOption "Enable irclogger.";

      package = mkOption {
        default = pkgs.irclogger;
        type = types.package;
        description = "The irclogger derivation to use.";
      };

      user = mkOption {
        default = "irclogger";
        type = types.str;
        description = "The user to run under.";
      };

      group = mkOption {
        default = "irclogger";
        type = types.str;
        description = "The group to run under.";
      };

      socket = mkOption {
        default = "/run/irclogger/viewer.sock";
        type = types.str;
        description = "Path to the unix socket for ircviewer.";
      };

      runtimeDirectory = mkOption {
        default = "irclogger";
        type = types.str;
        description = "The runtime directory for irclogger and ircviewer.";
      };

      enableLogger = mkOption {
        default = true;
        type = types.bool;
        description = "Whether to enable the logger.";
      };

      config = {
        server = mkOption {
          type = types.str;
          default = "irc.libera.chat";
          description = "IRC server to connect to.";
        };

        port = mkOption {
          type = types.int;
          default = 6667;
          description = "IRC server port to connect to.";
        };

        ssl = mkOption {
          type = types.bool;
          default = false;
          description = "Whether or not the IRC server supports SSL.";
        };

        username = mkOption {
          type = types.str;
          default = "irclogger-test";
          description = "IRC username to use. This is used for WHOIS.";
        };

        password = mkOption {
          type = types.str;
          default = "";
          description = "Password (if applicable) for the username.";
        };

        realname = mkOption {
          type = types.str;
          default = "whitequark's logger bot";
          description = "IRC realname to use. This is used for WHOIS. Put operator information here.";
        };

        nickname = mkOption {
          type = types.str;
          default = "logger_test";
          description = "IRC nickname to use. The bot appears under this name in the logged channels.";
        };

        channels = mkOption {
          type = with types; listOf str;
          default = [ ];
          description = "List of IRC channels to join.";
        };

        hidden_channels = mkOption {
          type = with types; listOf str;
          default = [ ];
          description = "List of hidden IRC channels to join.";
        };

        legacy_escaping_scheme = mkOption {
          type = with types; listOf str;
          default = [ ];
          description = "List of IRC channels to make available under legacy URLs. Leave empty for new installations.";
        };

        domain = mkOption {
          type = types.str;
          default = "example.com";
          description = ''
            Primary DNS name for the log viewer.
            The viewer will accept requests with other DNS names and render the UI without the channel selector.
          '';
        };
      };

      files = {
        log = mkOption {
          type = types.str;
          default = "/var/log/irclogger";
          description = "Default log directory for irclogger.";
        };

        tmp = mkOption {
          type = types.str;
          default = "/tmp/irclogger";
          description = "Default temp directory for irclogger.";
        };
      };

      watchdog = {
        timeout = mkOption {
          type = types.int;
          default = 600;
          description = ''
            Watchdog timeout. If no messages are logged for this many seconds, the logger will be restarted.
            The default value may be too low for low-traffic networks; raise it if the logger's JOIN/QUIT messages are a nuisance.
          '';
        };

        interval = mkOption {
          type = types.str;
          default = "5m";
          description = "Systemd calendar expression for when to run the watchdog.";
        };
      };

      redis = {
        host = mkOption {
          type = types.str;
          default = "127.0.0.1";
          description = "Redis host.";
        };

        port = mkOption {
          type = types.port;
          default = 6379;
          description = "Redis port.";
        };

        createLocally = mkOption {
          type = types.bool;
          default = true;
          description = "Configure local Redis server.";
        };
      };

      postgres = {
        host = mkOption {
          type = types.str;
          default = "127.0.0.1";
          description = "Postgres host.";
        };

        port = mkOption {
          type = types.port;
          default = 5432;
          description = "Postgres port.";
        };

        database = mkOption {
          type = types.str;
          default = "irclogs";
          description = "Postgres database.";
        };

        createLocally = mkOption {
          type = types.bool;
          default = true;
          description = "Configure local Postgres database.";
        };

        backup = mkOption {
          type = types.bool;
          default = true;
          description = "Whether to back up the database.";
        };
      };

      logrotate = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable logrotate for irclogger.";
        };

        frequency = mkOption {
          type = types.str;
          default = "daily";
          description = "How often to rotate the logs.";
        };

        keep = mkOption {
          type = types.int;
          default = 30;
          description = "How many rotations to keep.";
        };
      };
    };
  };

  config = mkIf cfg.enable {
    systemd.services = {
      irclogger = mkIf cfg.enableLogger rec {
        description = "irclogger";
        wantedBy = [ "multi-user.target" ];

        after = [ "network-online.target" ] ++ additionalTargets;
        requires = after;

        environment = {
          IRCLOGGER_CONFIG = "${configFile}";
        };

        serviceConfig = {
          User = "${cfg.user}";
          Restart = "on-failure";
          RestartSec = "5s";

          ExecStart = "${cfg.package}/bin/logger";
          WorkingDirectory = cfg.package;
          RuntimeDirectory = cfg.runtimeDirectory;
        };
      };

      watchdog = mkIf cfg.enableLogger rec {
        description = "irclogger watchdog";
        wantedBy = [ "multi-user.target" ];

        after = [ "network-online.target" "irclogger.service" ];
        requires = after;

        environment = {
          IRCLOGGER_CONFIG = "${configFile}";
        };

        serviceConfig = {
          Type = "oneshot";
          User = "${cfg.user}";

          ExecStart = "${cfg.package}/bin/watchdog";
          WorkingDirectory = cfg.package;
          RuntimeDirectory = cfg.runtimeDirectory;
        };
      };

      ircviewer = rec {
        description = "irclogger viewer";
        wantedBy = [ "multi-user.target" ];

        after = [ "network-online.target" ] ++
          (if cfg.enableLogger then [ "irclogger.service" ] else additionalTargets);
        requires = after;

        environment = {
          IRCLOGGER_CONFIG = "${configFile}";
        };

        serviceConfig = {
          User = "${cfg.user}";
          Restart = "on-failure";
          RestartSec = "5s";

          ExecStart = "${cfg.package}/bin/viewer";
          WorkingDirectory = cfg.package;
          RuntimeDirectory = cfg.runtimeDirectory;
        };
      };
    };

    systemd.timers = {
      watchdog = mkIf cfg.enableLogger rec {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = cfg.watchdog.interval;
          OnUnitActiveSec = cfg.watchdog.interval;
          Unit = "watchdog.service";
        };
      };
    };

    services.redis.servers.irclogger = mkIf cfg.redis.createLocally {
      enable = true;
      port = cfg.redis.port;
      bind = cfg.redis.host;
    };

    services.postgresql = mkIf cfg.postgres.createLocally {
      enable = true;

      initialScript = pkgs.writeText "irclogger-init-db" ''
        CREATE EXTENSION btree_gin;

        CREATE USER ${cfg.user};
        CREATE DATABASE ${cfg.postgres.database} OWNER ${cfg.user};
        GRANT ALL PRIVILEGES ON DATABASE ${cfg.postgres.database} TO ${cfg.user};

        \c ${cfg.postgres.database} ${cfg.user};

        CREATE TABLE irclog (
          id SERIAL,
          channel VARCHAR(30),
          nick VARCHAR(40),
          opcode VARCHAR(20),
          timestamp INT,
          line TEXT,
          oper_nick VARCHAR(40),
          payload TEXT,
          PRIMARY KEY(id)
        );

        CREATE INDEX irclog_timestamp_index ON irclog (timestamp);
        CREATE INDEX irclog_channel_timestamp_index ON irclog (channel, timestamp);
        CREATE INDEX irclog_channel_opcode_index ON irclog (channel, opcode);
        CREATE INDEX irclog_channel_nick_index ON irclog (channel, nick);
        CREATE INDEX irclog_fulltext_index ON irclog
          USING gin(channel, to_tsvector('english', nick || ' ' || line));
      '';

      authentication = mkForce ''
        # Generated file; do not edit!
        # TYPE  DATABASE        USER            ADDRESS                 METHOD
        local   all             all                                     trust
        host    all             all             127.0.0.1/32            trust
        host    all             all             ::1/128                 trust
      '';
    };

    services.postgresqlBackup = mkIf cfg.postgres.backup {
      enable = true;
      compression = "none";
      pgdumpOptions = "--data-only";
      databases = [ cfg.postgres.database ];
      location = "/var/backup";
    };

    services.logrotate = mkIf cfg.logrotate.enable {
      enable = true;
      settings = {
        "${cfg.files.log}/*.log" = {
          copytruncate = true;
          missingok = true;
          frequency = cfg.logrotate.frequency;
          rotate = cfg.logrotate.keep;
        };
      };
    };

    system.activationScripts.irclogger = stringAfter [ "var" ] ''
      if [ ! -d ${cfg.files.log} ]; then
        install -g ${cfg.group} -o ${cfg.user} -d ${cfg.files.log}
      fi
    '';

    users.users.${cfg.user} = {
      group = "${cfg.group}";
      createHome = false;
      description = "irclogger user";
      home = cfg.package;
      isSystemUser = true;
    };

    users.groups.${cfg.group} = { };
  };
}
