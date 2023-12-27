{ config, lib, pkgs, ... }: rec {
  imports = [
    ./hardware-configuration.nix
    ./networking.nix # generated at runtime by nixos-infect
  ];

  nix.optimise.automatic = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  sops.defaultSopsFile = ../secrets/common.yaml;
  sops.secrets."passwords/lawrence".neededForUsers = true;
  sops.secrets."gluetun-mullvad.env" = {
    sopsFile = ../secrets/gluetun-mullvad.env;
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
    #authKeyFile = "/tmp/tailscale.key";
  };
  virtualisation = {
    oci-containers = let
      tailscale_exit_node_mullvad = {
        type ? "openvpn",
        countries,
        cities ? [ ],
        shortname ? lib.strings.toLower builtins.head countries
      }: {
        "gluetun-${shortname}" = {
          image = "qmcgaw/gluetun:latest";
          environment = {
            VPN_SERVICE_PROVIDER = "mullvad";
            VPN_TYPE = type;
            OPENVPN_IPV6 = "on";
            SERVER_COUNTRIES = lib.strings.concatStringsSep "," countries;
            SERVER_CITIES = lib.strings.concatStringsSep "," cities;
          };
          environmentFiles = [ config.sops.secrets."gluetun-mullvad.env".path ];
          extraOptions = [
            "--cap-add=NET_ADMIN"
            "--device=/dev/net/tun"
          ];
        };
        "tailscale-mullvad-${shortname}" = {
          dependsOn = [ "gluetun-${shortname}" ];
          image = "tailscale/tailscale:latest";
          hostname = "flaky-mullvad-${shortname}";
          environment = {
            TS_AUTH_ONCE = "true";
            TS_STATE_DIR= "/var/lib/tailscale";
            TS_EXTRA_ARGS = "--advertise-exit-node";
          };
          volumes = [
            "tailscale-mullvad-${shortname}:/var/lib/tailscale"
          ];
          extraOptions = [
            "--network=container:gluetun-${shortname}"
          ];
        };
      };
    in {
      containers = {}
        // tailscale_exit_node_mullvad { countries = [ "UK" ]; cities = [ "London" ]; shortname = "lon"; }
        // tailscale_exit_node_mullvad { countries = [ "Finland" ]; shortname = "fin"; }
        // tailscale_exit_node_mullvad { countries = [ "Norway" ]; type = "wireguard"; shortname = "nor"; };
    };
    podman = {
      enable = true;
      defaultNetwork.settings.dns_enabled = true;
    };
  };
  environment.systemPackages = [ ];
  programs.fish.enable = true;
  users.mutableUsers = false;
  users.users.lawrence = {
    isNormalUser = true;
    hashedPasswordFile = config.sops.secrets."passwords/lawrence".path;
    extraGroups = [ "wheel" ];
    shell = pkgs.fish;
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCtxdBlDGBWLeUUWberZaklLhWJ0tSXzRPhVJi12Y2DQ0ojdz3gULkOuBeYF3O1reaw3CM9tN8LBzP73JOeuONyUYkA0FjsbYRcZ/dJxFNEMfgpKNNWBLBgy9hkl0eAIWipIlf0Ld1TOH4332JjH19otGuclZO1erIrTD9YJIZA5LhPYzOG8aS5EzPhILZxy+uWmAaeeOoxMEBbj/l8oTnU6e1Sr3CVtoFL2g2WiwxdATvAM3O0B3BsZ3IQuVAaqB+Ij8jDqHKwNzDOULuSCRltDGRQtiJavT/f4SGjyMLanGTtVGGWUpZL66ZmXHz3ayPnYF6qQebXp7PyZau9htrgK1ouL6z7SCQWRy25fFiFTox2m+spb7OLSfwNBN6XKRQ/SXbV5O3VLJNl91EDvMUS82ubYq7fKuuC162hIJlMqOa+K8vnYxHR5pDB81FAIT5LNlqP7RQ12W1xT+fN9QL/tj6uTsB8YqYOmToT7zQH6CgaNYq1JL3zOpB/HY1H55taCZLfYwZ0AxNA/4FjYKnyoYrGAUAvNbEfQW+8361ciT2ZVwap1fokhspoNXsNPW78Nimrshx4kK/4NIDBmR2b9/kjz6Oc0cAdylD9mo99U9unh/lIeieFmJc6Dz42pI5Zygs4m2lIfmTBRmEdVesbNzic7nqhVLvLI7GtsVFgJQ== openpgp:0xAB82976A"
    ];
  };
}
