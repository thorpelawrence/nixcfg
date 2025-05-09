{ config, lib, pkgs, inputs, ... }: rec {
  imports = [
    ./hardware-configuration.nix
    ./networking.nix # generated at runtime by nixos-infect
    ./hosting.nix
    ./matrix.nix
  ];

  time.timeZone = "Europe/London";

  system.autoUpgrade = {
    enable = true;
    flake = inputs.self.outPath;
    flags = [
      "--update-input"
      "nixpkgs"
      "-L" # print build logs
    ];
    dates = "02:00";
    randomizedDelaySec = "45min";
  };

  systemd.services."nixos-upgrade".postStop = ''
    ${pkgs.curlMinimal}/bin/curl -fsS -m 10 --retry 5 -o /dev/null \
      "$(cat ${config.sops.secrets."nixos-upgrade-webhook".path})/$EXIT_STATUS"
  '';

  nix.optimise.automatic = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  sops.defaultSopsFile = ../../secrets/common.yaml;
  sops.secrets."passwords/lawrence".neededForUsers = true;
  sops.secrets."nixos-upgrade-webhook" = { };
  sops.secrets."tailscale-auth-key" = { };
  sops.secrets."gluetun-protonvpn.env" = {
    sopsFile = ../../secrets/gluetun-protonvpn.env;
    format = "dotenv";
  };
  sops.secrets."tailscale-gluetun.env" = {
    sopsFile = ../../secrets/tailscale-gluetun.env;
    format = "dotenv";
  };

  system.stateVersion = "23.11";
  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;
  networking.hostName = "flaky";
  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "tailscale0" ];
    allowedUDPPorts = [ config.services.tailscale.port ];
    allowedTCPPorts = [ 22 ];
  };
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
  };
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
    extraUpFlags = [ "--ssh" "--advertise-exit-node" ];
    authKeyFile = config.sops.secrets.tailscale-auth-key.path;
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
        backend = "docker";
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
  environment.systemPackages = [ ];
  programs.fish.enable = true;
  users.mutableUsers = false;
  users.users.lawrence = {
    isNormalUser = true;
    hashedPasswordFile = config.sops.secrets."passwords/lawrence".path;
    extraGroups = [ "wheel" "docker" ];
    shell = pkgs.fish;
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCtxdBlDGBWLeUUWberZaklLhWJ0tSXzRPhVJi12Y2DQ0ojdz3gULkOuBeYF3O1reaw3CM9tN8LBzP73JOeuONyUYkA0FjsbYRcZ/dJxFNEMfgpKNNWBLBgy9hkl0eAIWipIlf0Ld1TOH4332JjH19otGuclZO1erIrTD9YJIZA5LhPYzOG8aS5EzPhILZxy+uWmAaeeOoxMEBbj/l8oTnU6e1Sr3CVtoFL2g2WiwxdATvAM3O0B3BsZ3IQuVAaqB+Ij8jDqHKwNzDOULuSCRltDGRQtiJavT/f4SGjyMLanGTtVGGWUpZL66ZmXHz3ayPnYF6qQebXp7PyZau9htrgK1ouL6z7SCQWRy25fFiFTox2m+spb7OLSfwNBN6XKRQ/SXbV5O3VLJNl91EDvMUS82ubYq7fKuuC162hIJlMqOa+K8vnYxHR5pDB81FAIT5LNlqP7RQ12W1xT+fN9QL/tj6uTsB8YqYOmToT7zQH6CgaNYq1JL3zOpB/HY1H55taCZLfYwZ0AxNA/4FjYKnyoYrGAUAvNbEfQW+8361ciT2ZVwap1fokhspoNXsNPW78Nimrshx4kK/4NIDBmR2b9/kjz6Oc0cAdylD9mo99U9unh/lIeieFmJc6Dz42pI5Zygs4m2lIfmTBRmEdVesbNzic7nqhVLvLI7GtsVFgJQ== openpgp:0xAB82976A"
    ];
  };
}
