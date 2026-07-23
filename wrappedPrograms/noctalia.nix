{
  flake.wrappers.noctalia-shell =
    {
      wlib,
      pkgs,
      ...
    }:
    {
      imports = [ wlib.wrapperModules.noctalia-shell ];
      package = pkgs.noctalia-shell.overrideAttrs {
        name = "vjnoctalia2";
      };
    };
}
