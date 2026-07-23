{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # The framework I use to structure the flake, module imports are automatic via custom function below
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:Mic92/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    wrapper-modules = {
      url = "github:BirdeeHub/nix-wrapper-modules";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # disko = {
    #   url = "github:nix-community/disko";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
  };

  # Import all .nix files from current directory except flake.nix recursively
  outputs =
    inputs:
    let
      inherit (inputs.nixpkgs) lib;
      inherit (lib.fileset) toList fileFilter;
      isNixModule = file: file.hasExt "nix" && file.name != "flake.nix" && !lib.hasPrefix "_" file.name;
      excludeHome = pathList: builtins.filter (p: !lib.hasInfix "/modules/home/" (toString p)) pathList;

      importTree = path: excludeHome (toList (fileFilter isNixModule path));

      mkFlake = inputs.flake-parts.lib.mkFlake { inherit inputs; };
    in
    mkFlake { imports = importTree ./.; };
}
