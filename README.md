# nixcfg

```shell
$ nix shell nixpkgs#ssh-to-age --command sh -c 'ssh-keyscan flaky | ssh-to-age'
$ nix run nixpkgs#deploy-rs -- --remote-build [--skip-checks]
# alternatively
$ nix run nixpkgs#nixos-rebuild -- --flake .#flaky --build-host lawrence@flaky --target-host lawrence@flaky --use-remote-sudo switch
```
