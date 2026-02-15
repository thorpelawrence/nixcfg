{
  pkgs,
  lib,
  config,
  ...
}:
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

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  services.postgresql.enable = true;
  services.postgresql.initialScript = pkgs.writeText "synapse-init.sql" ''
    CREATE ROLE "matrix-synapse" WITH LOGIN PASSWORD 'synapse';
    CREATE DATABASE "matrix-synapse" WITH OWNER "matrix-synapse"
      TEMPLATE template0
      LC_COLLATE = "C"
      LC_CTYPE = "C";
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
          root * ${
            pkgs.element-web.override {
              conf = {
                default_server_config = clientConfig;
              };
            }
          }
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

  services.matrix-synapse = {
    enable = true;
    settings.server_name = domain;
    # The public base URL value must match the `base_url` value set in `clientConfig` above.
    # The default value here is based on `server_name`, so if your `server_name` is different
    # from the value of `fqdn` above, you will likely run into some mismatched domain names
    # in client applications.
    settings.public_baseurl = baseUrl;
    settings.listeners = [
      {
        port = 8008;
        bind_addresses = [ "::1" ];
        type = "http";
        tls = false;
        x_forwarded = true;
        resources = [
          {
            names = [
              "client"
              "federation"
            ];
            compress = true;
          }
        ];
      }
    ];
    extraConfigFiles = [
      config.sops.templates."synapse_registration_shared_secret.conf".path
    ];
  };
}
