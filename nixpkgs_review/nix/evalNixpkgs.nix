systems: alt-pkgs:
builtins.mapAttrs (
  system: _:
  let
    pkgs = import <nixpkgs> { inherit system; };
    inherit (pkgs.lib) getAttrFromPath splitString;
    pkgs-path = if alt-pkgs == null then [ ] else splitString "." alt-pkgs;
  in
  (getAttrFromPath pkgs-path pkgs) // { recurseForDerivations = true; }
) systems
