let
  flaky = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFVpqXix9d74Uc6KSZqjhMP7P6Tvo6DsCe9P2Mz8/ztP";
in
{
  "gluetun_mullvad.env.age".publicKeys = [ flaky ];
}
