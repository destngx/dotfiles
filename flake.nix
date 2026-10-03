{
  description = "macOS workstation configuration for destngx";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";

    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    homebrew-services = {
      url = "github:homebrew/homebrew-services";
      flake = false;
    };
    aerospace-tap = {
      url = "github:nikitabobko/homebrew-tap";
      flake = false;
    };
    vjeantet-tap = {
      url = "github:vjeantet/homebrew-tap";
      flake = false;
    };
  };

  outputs = inputs@{ nix-darwin, ... }:
    let
      machine = import ./nix/machine.nix;
    in {
      darwinConfigurations.${machine.hostName} = nix-darwin.lib.darwinSystem {
        system = machine.system;
        specialArgs = { inherit inputs machine; };
        modules = [
          ./nix/darwin/configuration.nix
          inputs.home-manager.darwinModules.home-manager
          inputs.nix-homebrew.darwinModules.nix-homebrew
          {
            nixpkgs.hostPlatform = machine.system;
            home-manager = {
              backupFileExtension = "hm-backup";
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = { inherit machine; };
              users.${machine.username} = import ./nix/home/configuration.nix;
            };
          }
        ];
      };
    };
}
