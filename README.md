# nixcfg

```shell
$ nix-shell -p ssh-to-age --run 'ssh-keyscan flaky | ssh-to-age'
$ nix run github:serokell/deploy-rs -- --remote-build --skip-checks
```
