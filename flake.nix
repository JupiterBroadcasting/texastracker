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

      # Format index.html with prettier
      format-index = pkgs.writeShellApplication {
        name = "format-index";
        runtimeInputs = [
          pkgs.nodePackages.prettier
        ];
        text = ''
          prettier -w index.html
        '';
      };

      # Deploy index.html
      deploy-index = pkgs.writeShellApplication {
        name = "deploy-index";
        runtimeInputs = [
          pkgs.s5cmd
        ];
        text = ''
          export AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY"
          export AWS_SECRET_ACCESS_KEY="$R2_SECRET_KEY"
          export AWS_ENDPOINT_URL="$R2_ENDPOINT"
          s5cmd --endpoint-url="$AWS_ENDPOINT_URL" cp index.html "s3://$R2_BUCKET/index.html"
        '';
      };

      # Deploy with dotenvx wrapper
      deploy-with-env = pkgs.writeShellApplication {
        name = "deploy-with-env";
        runtimeInputs = [
          pkgs.s5cmd
          pkgs.dotenvx
        ];
        text = ''
          dotenvx run -- ${self.packages.${pkgs.system}.deploy-index}/bin/deploy-index
        '';
      };

      # Combined format and deploy
      format-and-deploy = pkgs.writeShellApplication {
        name = "format-and-deploy";
        runtimeInputs = [
          pkgs.nodePackages.prettier
          pkgs.s5cmd
          pkgs.dotenvx
        ];
        text = ''
          echo "Formatting index.html..."
          prettier -w index.html

          echo "Deploying index.html..."
          dotenvx run -- ${self.packages.${pkgs.system}.deploy-index}/bin/deploy-index
        '';
      };
    });

    apps = forAllPkgs (pkgs: {
      collector = {
        type = "app";
        program = pkgs.lib.getExe (mkCollector pkgs);
        meta = {
          description = "Run the Dawarich collector.";
        };
      };
      format-index = {
        type = "app";
        program = pkgs.lib.getExe self.packages.${pkgs.system}.format-index;
        meta = {
          description = "Format index.html with prettier.";
        };
      };
      deploy-with-env = {
        type = "app";
        program = pkgs.lib.getExe self.packages.${pkgs.system}.deploy-with-env;
        meta = {
          description = "Deploy index.html with dotenvx env injection.";
        };
      };
      format-and-deploy = {
        type = "app";
        program = pkgs.lib.getExe self.packages.${pkgs.system}.format-and-deploy;
        meta = {
          description = "Format and deploy index.html in one command.";
        };
      };
    });

    devShells = forAllPkgs (pkgs: {
      default = pkgs.mkShell {
        buildInputs = [
          pkgs.nodePackages.prettier
          pkgs.dotenvx
          pkgs.s5cmd
          pkgs.python3
        ];
        shellHook = ''
          echo "Texas Tracker dev environment"
          echo "Available commands:"
          echo "  prettier -w index.html       - Format HTML"
          echo "  dotenvx run -- <command>     - Run with .env"
          echo "  s5cmd                         - S3 operations"
          echo ""
          echo "Or use nix run commands:"
          echo "  nix run .#format-index"
          echo "  nix run .#deploy-with-env"
          echo "  nix run .#format-and-deploy"
        '';
      };
    });
  };
}
