{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-23.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    deploy-rs.url = "github:serokell/deploy-rs";
  };

  outputs = { self, nixpkgs, home-manager, sops-nix, deploy-rs }: {
    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;
    nixosConfigurations.flaky = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hosts/flaky/configuration.nix
        sops-nix.nixosModules.default
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.lawrence = import ./hosts/flaky/home.nix;
        }
      ];
    };

    deploy.nodes.flaky = {
      hostname = "flaky";
      profiles.system = {
        sshUser = "root";
        user = "root";
        path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.flaky;
      };
    };

    checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;
  };
}
