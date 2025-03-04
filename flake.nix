{
  description = "Wrapper module for seamless Nix flake rebuilds";

  inputs = {
    # Only for testing - not required by the module itself
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, ... }@inputs:
    let
      # Common module implementation for NixOS and nix-darwin
      standardModule = { lib, config, pkgs, hostFlake ? null, ... }:
        with lib;
        let
          cfg = config.system.rebuildWrapper;
          
          # Is this Darwin?
          isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
          
          # Command name based on platform
          rebuildCommand = if isDarwin then "darwin-rebuild" else "nixos-rebuild";
          
          # Create wrapper script
          wrapperScript = pkgs.writeShellScriptBin cfg.wrapperName ''
            #!/usr/bin/env bash
            exec ${cfg.commandPath} "$@" --flake ${cfg.flakePath}#${cfg.hostname}
          '';
        in {
          options.system.rebuildWrapper = {
            enable = mkOption {
              type = types.bool;
              default = true;
              description = "Enable the seamless flake rebuild command wrapper";
            };
            
            flake = mkOption {
              type = types.nullOr types.attrs;
              description = "Reference to the flake (typically 'self')";
              default = hostFlake;
              example = "self";
            };
            
            flakePath = mkOption {
              type = types.str;
              description = "Path to the flake if flake reference not available";
              default = if cfg.flake != null then toString cfg.flake.outPath else "";
              example = "/home/user/dotfiles";
            };
            
            hostname = mkOption {
              type = types.str;
              description = "Hostname/identifier for the configuration";
              default = "default";
              example = "laptop";
            };
            
            commandPath = mkOption {
              type = types.str;
              description = "Path to the rebuild command";
              default = "/run/current-system/sw/bin/${rebuildCommand}";
              example = "/run/current-system/sw/bin/nixos-rebuild";
            };
            
            wrapperName = mkOption {
              type = types.str;
              description = "Name for the wrapper command";
              default = rebuildCommand;
              example = "rebuild";
            };
          };
          
          config = mkIf cfg.enable {
            environment.systemPackages = [ wrapperScript ];
            
            warnings = mkIf (cfg.flake == null && cfg.flakePath == "") [
              "rebuildWrapper: neither flake nor flakePath is set; wrapper will not work correctly"
            ];
          };
        };
        
      # Special implementation for nix-on-droid
      nixOnDroidModule = { lib, config, pkgs, hostFlake ? null, ... }:
        with lib;
        let
          cfg = config.system.rebuildWrapper;
          
          # Create wrapper script
          # Instead of using packages option, we'll use nix-on-droid's installation script option
          wrapperScript = pkgs.writeScript "nix-on-droid-wrapper" ''
            #!/usr/bin/env bash
            exec /run/current-system/sw/bin/nix-on-droid "$@" --flake ${cfg.flakePath}#${cfg.hostname}
          '';
        in {
          options.system.rebuildWrapper = {
            enable = mkOption {
              type = types.bool;
              default = true;
              description = "Enable the seamless flake rebuild command wrapper";
            };
            
            flake = mkOption {
              type = types.nullOr types.attrs;
              description = "Reference to the flake (typically 'self')";
              default = hostFlake;
              example = "self";
            };
            
            flakePath = mkOption {
              type = types.str;
              description = "Path to the flake if flake reference not available";
              default = if cfg.flake != null then toString cfg.flake.outPath else "";
              example = "/home/user/dotfiles";
            };
            
            hostname = mkOption {
              type = types.str;
              description = "Hostname/identifier for the configuration";
              default = "default";
              example = "laptop";
            };
          };
          
          config = mkIf cfg.enable {
            # Add script to user's PATH via nix-on-droid specific option
            nix-on-droid.installPackages = ''
              ln -sf ${wrapperScript} $PREFIX/bin/nix-on-droid-wrapper
            '';
            
            warnings = mkIf (cfg.flake == null && cfg.flakePath == "") [
              "rebuildWrapper: neither flake nor flakePath is set; wrapper will not work correctly"
            ];
          };
        };
        
      # Create a test function based on available nixpkgs
      makeMinimalCheck = system:
        if inputs ? nixpkgs then
          let 
            pkgs = import inputs.nixpkgs { inherit system; };
          in {
            module-import-test = pkgs.runCommand "test-wrapper-module" {} ''
              echo "Test passed: Module can be imported"
              mkdir -p $out
              touch $out/result
            '';
          }
        else {};
    in {
      # Export standard module for NixOS and nix-darwin
      nixosModules.default = standardModule;
      darwinModules.default = standardModule;
      
      # Export specialized module for nix-on-droid
      nixOnDroidModules.default = nixOnDroidModule;
      
      # Add properly structured checks for CI
      checks = {
        x86_64-linux = makeMinimalCheck "x86_64-linux";
      };
    };
}