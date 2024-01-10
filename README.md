# nixcfg

```shell
$ nix-shell -p ssh-to-age --run 'ssh-keyscan flaky | ssh-to-age'
$ nix-shell -p deploy-rs --run "deploy --remote-build [--skip-checks]"
```
