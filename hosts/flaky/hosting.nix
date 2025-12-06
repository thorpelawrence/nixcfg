{ pkgs, lib, config, ... }:
let
  domain = "letc.me";
in
{
  services.caddy = {
    enable = true;
    virtualHosts = {
      "ok.${domain}".extraConfig = ''
        reverse_proxy http://100.71.198.32:11212
      '';
      "plik.${domain}".extraConfig = ''
        reverse_proxy http://100.71.198.32:1612
      '';
      "pcopy.${domain}".extraConfig = ''
        reverse_proxy http://100.71.198.32:2586
      '';
      "gotify.${domain}".extraConfig = ''
        reverse_proxy http://100.71.198.32:7152
      '';
      "freshrss.${domain}".extraConfig = ''
        reverse_proxy http://100.71.198.32:18191
      '';
      "notesx.${domain}".extraConfig = ''
        reverse_proxy http://100.71.198.32:14192
      '';
    };
  };
}
