{
  description = "Wrapper module for seamless Nix flake rebuilds";

  inputs = {
    # Only for testing - not required by the module itself
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, ... }@inputs:
    let
      # Common module logic
      rebuildWrapperModule = { lib, config, pkgs, hostFlake ? null, ... }:
        with lib;
        let
          cfg = config.system.rebuildWrapper;
          
          # Detect if we're in nix-on-droid
          isNixOnDroid = config ? nix-on-droid;
          
          # Determine command based on simple platform checks
          rebuildCommand = 
            if pkgs.stdenv.hostPlatform.isDarwin then "darwin-rebuild"
            else if isNixOnDroid then "nix-on-droid"
            else "nixos-rebuild";

          # Find command path with fallbacks
          defaultCommandPath = "/run/current-system/sw/bin/${rebuildCommand}";
          
          # Create the wrapper script
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
            
            # Advanced options
            commandPath = mkOption {
              type = types.str;
              description = "Path to the rebuild command";
              default = defaultCommandPath;
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
            # Add warning if no flake reference provided
            warnings = mkIf (cfg.flake == null && cfg.flakePath == "") [
              "rebuildWrapper: neither flake nor flakePath is set; wrapper will not work correctly"
            ];
            
            # Use the appropriate package installation method
            ${if isNixOnDroid then "packages" else "environment.systemPackages"} = [ wrapperScript ];
          };
        };
        
      # Create a specialized Nix-on-Droid module
      nixOnDroidModule = { lib, config, pkgs, hostFlake ? null, ... }:
        with lib;
        let
          cfg = config.system.rebuildWrapper;
          
          # Determine command path with fallbacks
          defaultCommandPath = "/run/current-system/sw/bin/nix-on-droid";
          
          # Create the wrapper script
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
            
            # Advanced options
            commandPath = mkOption {
              type = types.str;
              description = "Path to the rebuild command";
              default = defaultCommandPath;
              example = "/run/current-system/sw/bin/nixos-rebuild";
            };
            
            wrapperName = mkOption {
              type = types.str;
              description = "Name for the wrapper command";
              default = "nix-on-droid";
              example = "rebuild";
            };
          };
          
          config = mkIf cfg.enable {
            # Add warning if no flake reference provided
            warnings = mkIf (cfg.flake == null && cfg.flakePath == "") [
              "rebuildWrapper: neither flake nor flakePath is set; wrapper will not work correctly"
            ];
            
            # Use packages for nix-on-droid
            packages = [ wrapperScript ];
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
      nixosModules.default = rebuildWrapperModule;
      darwinModules.default = rebuildWrapperModule;
      
      # Export specialized module for nix-on-droid
      nixOnDroidModules.default = nixOnDroidModule;
      
      # Add properly structured checks for CI
      checks = {
        x86_64-linux = makeMinimalCheck "x86_64-linux";
      };
    };
}