{ pkgs, lib, config, ... }:
let
  hostName = "matrix";
  domain = "letc.me";
  fqdn = "${hostName}.${domain}";
  baseUrl = "https://${fqdn}";
  clientConfig."m.homeserver".base_url = baseUrl;
  serverConfig."m.server" = "${fqdn}:443";
  mkWellKnown = data: ''
    header Content-Type application/json
    header Access-Control-Allow-Origin *
    respond `${builtins.toJSON data}` 200
  '';
in
{
  nixpkgs.config.permittedInsecurePackages = [
    "olm-3.2.16"
  ];

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  services.postgresql.enable = true;
  services.postgresql.initialScript = pkgs.writeText "synapse-init.sql" ''
    CREATE ROLE "matrix-synapse" WITH LOGIN PASSWORD 'synapse';
    CREATE DATABASE "matrix-synapse" WITH OWNER "matrix-synapse"
      TEMPLATE template0
      LC_COLLATE = "C"
      LC_CTYPE = "C";

    CREATE ROLE "mautrix-telegram" WITH LOGIN PASSWORD 'telegram';
    CREATE DATABASE "mautrix-telegram" WITH OWNER "mautrix-telegram";
  '';

  services.caddy = {
    virtualHosts = {
      "${domain}".extraConfig = ''
        handle /.well-known/matrix/server { ${mkWellKnown serverConfig} }
        handle /.well-known/matrix/client { ${mkWellKnown clientConfig} }
        respond 404
      '';
      "${fqdn}".extraConfig = ''
        route {
          reverse_proxy /_matrix/* http://[::1]:8008
          reverse_proxy /_synapse/client/* http://[::1]:8008
          respond 404
        }
      '';
      "element.${fqdn}" = {
        extraConfig = ''
          encode zstd gzip
          file_server
          root * ${pkgs.element-web.override {
            conf = {
              default_server_config = clientConfig;
            };
          }}
        '';
        serverAliases = [ "element.${domain}" ];
      };
    };
  };

  sops.secrets."matrix-synapse/registration_shared_secret" = { };
  sops.templates."synapse_registration_shared_secret.conf" = {
    content = ''
      registration_shared_secret: ${config.sops.placeholder."matrix-synapse/registration_shared_secret"}
    '';
    owner = "matrix-synapse";
  };
  sops.secrets."matrix-synapse/as_token" = { };
  sops.secrets."matrix-synapse/hs_token" = { };
  sops.secrets."matrix-synapse/sender_localpart" = { };
  sops.templates."mautrix_double_puppet_appservice.conf" = {
    content = ''
      id: doublepuppet
      # intentionally left blank
      url:
      as_token: ${config.sops.placeholder."matrix-synapse/as_token"}
      hs_token: ${config.sops.placeholder."matrix-synapse/hs_token"}
      sender_localpart: ${config.sops.placeholder."matrix-synapse/sender_localpart"}
      rate_limited: false
      namespaces:
        users:
        - regex: '@.*:${lib.strings.escapeRegex domain}'
          exclusive: false
    '';
    owner = "matrix-synapse";
  };

  services.matrix-synapse = {
    enable = true;
    settings.server_name = domain;
    settings.public_baseurl = baseUrl;
    settings.listeners = [
      {
        port = 8008;
        bind_addresses = [ "::1" ];
        type = "http";
        tls = false;
        x_forwarded = true;
        resources = [{
          names = [ "client" "federation" ];
          compress = true;
        }];
      }
    ];
    extraConfigFiles = [
      config.sops.templates."synapse_registration_shared_secret.conf".path
      config.sops.templates."mautrix_double_puppet_appservice.conf".path
    ];
  };

  sops.secrets."mautrix-telegram.env" = {
    sopsFile = ../../secrets/mautrix-telegram.env;
    format = "dotenv";
  };

  services.mautrix-telegram = {
    enable = true;

    environmentFile = config.sops.secrets."mautrix-telegram.env".path;

    settings = {
      homeserver = {
        address = "http://localhost:8008";
        domain = domain;
      };
      appservice = {
        provisioning.enabled = false;
        id = "telegram";
        public = {
          enabled = true;
          prefix = "/public";
          external = "http://${domain}:8080/public";
        };
        database = "postgresql://mautrix-telegram:telegram@localhost/mautrix-telegram";
      };
      bridge = {
        relaybot.authless_portals = false;
        permissions = {
          "@l:${domain}" = "admin";
        };

        animated_sticker = {
          target = "gif";
          args = {
            width = 256;
            height = 256;
            fps = 30;
            background = "020202";
          };
        };
      };
    };
  };

  systemd.services.mautrix-telegram.path = with pkgs; [
    lottieconverter # for animated stickers conversion, unfree package
    ffmpeg # if converting animated stickers to webm (very slow!)
  ];
}
