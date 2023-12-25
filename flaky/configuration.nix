{ config, pkgs, ... }: rec {
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

  age.secrets."gluetun_mullvad.env.age".file = ../secrets/gluetun_mullvad.env.age;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "23.11";
  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;
  networking.hostName = "flaky";
  networking.firewall = {
    # TODO
    enable = false;
    trustedInterfaces = [ "tailscale0" ];
    allowedUDPPorts = [ config.services.tailscale.port ];
    #allowedTCPPorts = [ 22 ];
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
      tailscale_exit_node_mullvad = { city, shortname ? city }: {
        "gluetun-${shortname}" = {
          image = "qmcgaw/gluetun:latest";
          environment = {
            VPN_SERVICE_PROVIDER = "mullvad";
            VPN_TYPE = "openvpn";
            OPENVPN_IPV6 = "on";
            SERVER_CITIES = "${city}";
            DOT_PROVIDERS = "quad9";
          };
          environmentFiles = [ config.age.secrets."gluetun_mullvad.env.age".path ];
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
        // tailscale_exit_node_mullvad { city = "london"; shortname = "lon"; }
        // tailscale_exit_node_mullvad { city = "oslo"; };
    };
    podman = {
      enable = true;
      defaultNetwork.settings.dns_enabled = true;
    };
  };
  environment.systemPackages = [ ];
  programs.fish.enable = true;
  users.users.lawrence = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.fish;
    openssh.authorizedKeys.keys = [ ];
  };
}
