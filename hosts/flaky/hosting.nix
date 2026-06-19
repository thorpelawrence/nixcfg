{
  pkgs,
  lib,
  config,
  ...
}:
let
  domain = "letc.me";
in
{
  services.caddy = {
    enable = true;
    virtualHosts = {
      "go.${domain}".extraConfig = ''
        vars upstream "https://github.com/thorpelawrence"

        handle / {
          redir {vars.upstream}
        }

        handle /* {
          @goget query go-get=1

          vars repo_name {path.0}

          handle @goget {
            header Content-Type "text/html; charset=utf-8"
            respond <<HTML
              <html>
                <head>
                  <meta name="go-import" content="https://{host}/{vars.repo_name} git {vars.upstream}/{vars.repo_name}">
                </head>
              </html>
              HTML
          }

          handle {
            redir https://pkg.go.dev/{host}{uri}
          }
        }
      '';
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
