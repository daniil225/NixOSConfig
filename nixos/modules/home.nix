{ ... }:
{
  flake.homeModules = {
    base = import ./home/base.nix;
    vscode = import ./home/devtools/vscode.nix;
    nix-tooling = import ./home/nix-tooling.nix;
  };
}
