{ pkgs, lib, config, ... }:
let
  domain = "letc.me";
in
{
  services.caddy = {
    enable = true;
    virtualHosts  = {
      "plik.${domain}".extraConfig = ''
        reverse_proxy http://100.88.233.89:1612
      '';
      "pcopy.${domain}".extraConfig = ''
        reverse_proxy http://100.88.233.89:2586
      '';
    };
  };
}
