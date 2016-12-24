{ stdenv, callPackage, recurseIntoAttrs, makeRustPlatform,
  targets ? [], targetToolchains ? [], targetPatches ? [] }:

let
  rustPlatform = recurseIntoAttrs (makeRustPlatform (callPackage ./bootstrap.nix {}));
in

rec {
  rustc = callPackage ./rustc.nix {
    shortVersion = "1.14";
    isRelease = true;
    forceBundledLLVM = false;
    configureFlags = [ "--release-channel=stable" ];
    srcRev = "e8a0123241f0d397d39cd18fcc4e5e7edde22730";
    srcSha = "1sla3gnx9dqvivnyhvwz299mc3jmdy805q2y5xpmpi1vhfk0bafx";

    patches = [ ] ++ stdenv.lib.optional stdenv.needsPax ./patches/grsec.patch;

    inherit targets;
    inherit targetPatches;
    inherit targetToolchains;
    inherit rustPlatform;
  };

  cargo = callPackage ./cargo.nix rec {
    version = "0.15.0";
    srcRev = "298a0127f703d4c2500bb06d309488b92ef84ae1";
    srcSha = "2zm5rzw1mvixnkzr4775pcxx6k235qqxbysyp179cbxsw3dm045s";
    depsSha256 = "3gpn0cpwgpzwhc359qn6qplx371ag9pqbwayhqrsydk1zm5bm3zr";

    inherit rustc; # the rustc that will be wrapped by cargo
    inherit rustPlatform; # used to build cargo
  };
}
