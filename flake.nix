{
  description = "Dawarich points collector";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-25.05";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    supportedSystems = ["x86_64-linux" "aarch64-linux"];
    pkgsBySystem = nixpkgs.lib.getAttrs supportedSystems nixpkgs.legacyPackages;
    forAllPkgs = fn: nixpkgs.lib.mapAttrs (_: pkgs: fn pkgs) pkgsBySystem;

    gitRev =
      if self ? rev
      then builtins.substring 0 8 self.rev
      else "dirty";

    mkCollector = pkgs:
      pkgs.writeShellApplication {
        name = "collector";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.curl
          pkgs.jq
          pkgs.s5cmd
        ];
        text = builtins.readFile ./collector.sh;
        meta = with pkgs.lib; {
          description = "Dawarich data collector script";
          maintainers = [maintainers.yourGithubUser];
          platforms = supportedSystems;
        };
      };

    mkImage = pkgs: tag:
      pkgs.dockerTools.buildImage {
        name = "collector";
        inherit tag;
        config = {
          Entrypoint = [(pkgs.lib.getExe (mkCollector pkgs))];
          # N.B. https://fzakaria.com/2025/02/28/nix-migraines-nix-ssl-cert-file
          Env = let
            certFile = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
          in [
            "SSL_CERT_FILE=${certFile}"
            "NIX_SSL_CERT_FILE=${certFile}"
          ];
          Cmd = []; # empty so users can override at docker run
        };
      };
  in {
    formatter = forAllPkgs (pkgs: pkgs.alejandra);

    overlays.default = final: prev: {
      collector = mkCollector final;
    };

    packages = forAllPkgs (pkgs: {
      collector = (self.overlays.default pkgs pkgs).collector;
      collector-image-latest = mkImage pkgs "latest";
      collector-image-gitrev = mkImage pkgs gitRev;
      default = self.packages.${pkgs.system}.collector-image-gitrev;
    });

    apps = forAllPkgs (pkgs: {
      collector = {
        type = "app";
        program = pkgs.lib.getExe (mkCollector pkgs);
        meta = {
          description = "Run the Dawarich collector.";
        };
      };
    });
  };
}
