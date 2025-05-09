{ config, lib, ... }:
{
  sops.secrets."tailscale-auth-key" = { };
  sops.secrets."gluetun-protonvpn.env" = {
    sopsFile = ../../secrets/gluetun-protonvpn.env;
    format = "dotenv";
  };
  sops.secrets."tailscale-gluetun.env" = {
    sopsFile = ../../secrets/tailscale-gluetun.env;
    format = "dotenv";
  };
  virtualisation = {
    oci-containers =
      let
        tailscale_exit_node_protonvpn =
          { type ? "openvpn"
          , countries
          , cities ? [ ]
          , isps ? [ ]
          , hostnames ? [ ]
          , shortname ? lib.strings.toLower builtins.head countries
          }: {
            "gluetun-protonvpn-${shortname}" = {
              image = "qmcgaw/gluetun:latest";
              environment = {
                VPN_SERVICE_PROVIDER = "protonvpn";
                VPN_TYPE = type;
                SERVER_COUNTRIES = lib.strings.concatStringsSep "," countries;
                SERVER_CITIES = lib.strings.concatStringsSep "," cities;
                SERVER_HOSTNAMES = lib.strings.concatStringsSep "," hostnames;
                ISP = lib.strings.concatStringsSep "," isps;
                UPDATER_PERIOD = "24h";
              };
              environmentFiles = [ config.sops.secrets."gluetun-protonvpn.env".path ];
              extraOptions = [
                "--cap-add=NET_ADMIN"
                "--device=/dev/net/tun"
              ];
            };
            "tailscale-gluetun-protonvpn-${shortname}" = {
              dependsOn = [ "gluetun-protonvpn-${shortname}" ];
              image = "tailscale/tailscale:latest";
              environment = {
                TS_HOSTNAME = "gluetun-protonvpn-${shortname}";
                # TS_AUTH_ONCE = "true";
                TS_STATE_DIR = "/var/lib/tailscale";
                TS_EXTRA_ARGS = "--advertise-exit-node --advertise-tags=tag:gluetun";
                TS_NO_LOGS_NO_SUPPORT = "true";
              };
              environmentFiles = [ config.sops.secrets."tailscale-gluetun.env".path ];
              volumes = [
                # "/dev/net/tun:/dev/net/tun"
                "tailscale-gluetun-protonvpn-${shortname}:/var/lib/tailscale"
              ];
              extraOptions = [
                "--network=container:gluetun-protonvpn-${shortname}"
                "--cap-add=NET_ADMIN"
                "--cap-add=SYS_MODULE"
              ];
            };
          };
      in
      {
        containers = { }
          // tailscale_exit_node_protonvpn {
          countries = [ "Finland" ];
          type = "wireguard";
          shortname = "fin";
        }
          // tailscale_exit_node_protonvpn {
          countries = [ "United Kingdom" ];
          type = "wireguard";
          shortname = "lon";
        };
      };
  };
}
