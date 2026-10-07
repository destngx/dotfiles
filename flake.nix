{
  description = "macOS workstation configuration for destngx";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    herdr.url = "github:herdrdev/herdr/v0.9.3";

    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
  };

  outputs = inputs@{ nix-darwin, ... }:
    let
      machine = import ./nix/hosts/destngx-macbook-air/machine.nix;
    in {
      darwinConfigurations.${machine.hostName} = nix-darwin.lib.darwinSystem {
        system = machine.system;
        specialArgs = { inherit inputs machine; };
        modules = [
          ./nix/hosts/destngx-macbook-air/darwin.nix
          inputs.home-manager.darwinModules.home-manager
          inputs.nix-homebrew.darwinModules.nix-homebrew
          {
            nixpkgs.hostPlatform = machine.system;
            home-manager = {
              backupFileExtension = "hm-backup";
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = { inherit inputs machine; };
              users.${machine.username} = import ./nix/hosts/destngx-macbook-air/home.nix;
            };
          }
        ];
      };
    };
}
