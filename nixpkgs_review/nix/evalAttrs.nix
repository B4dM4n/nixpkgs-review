{ allowAliases ? false, attr-json, maxDepth ? 1, recurseAll ? false }:

with builtins;
let
  pkgs = import <nixpkgs> { config = { checkMeta = true; allowUnfree = true; inherit allowAliases; }; };

  inherit (pkgs.lib) attrByPath concatLists concatMap hasAttrByPath isAttrs isDerivation
    listToAttrs mapAttrsToList nameValuePair splitString;

  attrs = fromJSON (readFile attr-json);

  recurseName = name:
    recurseAttrs 1 name (attrByPath (splitString "." name) null pkgs);

  recurseAttrs = depth: name: pkg:
    let
      maybeIsDerivation = tryEval (isDerivation pkg);
      pkgIsDerivation = maybeIsDerivation.success && maybeIsDerivation.value;
      pkgIsAttrs = maybeIsDerivation.success && isAttrs pkg;

      pkgProperties = [ (getProperties name pkg maybeIsDerivation) ];
    in
    # pkg evaluated to a derivation, so return it's properties
    if pkgIsDerivation then pkgProperties
    # pkg evaluated to a set. Check the recursion filters and recurse for each attribute
    else if pkgIsAttrs && (depth <= maxDepth) && pkg.recurseForDerivations or recurseAll then
      concatLists (mapAttrsToList (n: v: recurseAttrs (depth + 1) "${name}.${n}" v) pkg)
    # If we recursed already once, don't treat invalid values as broken
    else if depth > 1 then [ ]
    # Otherwise (for entries in the attr-json file) the properties will report the entry
    # as non existent/invalid/broken
    else pkgProperties;

  getProperties = name: pkg: maybeIsDerivation:
    let
      attrPath = splitString "." name;
      maybePath = tryEval "${pkg}";
    in
    nameValuePair name rec {
      exists = hasAttrByPath attrPath pkgs;
      invalid = maybeIsDerivation.success && !maybeIsDerivation.value;
      broken = !exists || invalid || !maybePath.success;
      path = if !broken then maybePath.value else null;
      drvPath = if !broken then pkg.drvPath else null;
    };
in
listToAttrs (concatMap recurseName attrs)
