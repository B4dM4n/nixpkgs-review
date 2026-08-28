{
  config ? (
    let configFile = builtins.getEnv "NIXPKGS_CONFIG";
    in
      if configFile != "" && builtins.pathExists configFile then
        import configFile
      else
        { }),
  system ? null, # deadnix: skip
}@args:
with import ./config.nix;
let
  currentSystem = if system != null then system else builtins.currentSystem;

  stdenv = {
    inherit mkDerivation;
  };

  mkShell = attrs: mkDerivation (attrs // {
    name = attrs.name or "shell";
    buildCommand = "echo 'mock shell' > $out";
  });

  bashInteractive = mkDerivation {
    name = "bash-interactive";
    buildCommand = ''
      mkdir -p $out/bin
      ln -s ${shell} $out/bin/bash
    '';
  };

  buildEnv = args: mkDerivation {
    inherit (args) name paths;
    buildCommand = ''
      mkdir -p $out
      ln -s $paths $out
    '';
  };

  mkPackage = i: prefix: mkDerivation ({
    name = "${prefix}${toString i}";
    buildCommand = ''
      cat ${./pkg1.txt} > $out
    '';
  } // lib.optionalAttrs (i == 1) {
    passthru.tests."${prefix}${toString i}" = mkDerivation {
      name = "${prefix}${toString i}-test";
      buildCommand = ''
        touch $out
      '';
    };
  });
in
lib.genAttrs' (lib.range 1 (config.pkgCount or 1)) (
  i:
  lib.nameValuePair "pkg${toString i}" (mkPackage i "pkg")) // {
  inherit lib mkShell bashInteractive stdenv buildEnv;
  pkgsAlt = lib.genAttrs' (lib.range 1 (config.pkgCount or 1)) (
    i:
    lib.nameValuePair "pkg${toString i}" (mkPackage i "alt-pkg")
  );
}
