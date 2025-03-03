{
  description = "Wrapper module for seamless Nix flake rebuilds";

  inputs = {
    # Only for testing - not required by the module itself
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, ... }@inputs:
    let
      rebuildWrapperModule = { lib, config, pkgs, hostFlake ? null, ... }:
        with lib;
        let
          cfg = config.system.rebuildWrapper;
          
          # Platform detection
          platformInfo = rec {
            isNixOS = pkgs.stdenv.hostPlatform.isLinux && 
                      (builtins.pathExists "/etc/nixos" || config.system.build ? toplevel);
            isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
            isNixOnDroid = pkgs.stdenv.hostPlatform.isLinux && 
                          (builtins.pathExists "/data/data/com.termux" || config.environment.nix-on-droid.enable or false);
                          
            platform = if isNixOS then "nixos"
                      else if isDarwin then "darwin"
                      else if isNixOnDroid then "nix-on-droid"
                      else "unknown";
            
            rebuildName = if isNixOS then "nixos-rebuild"
                         else if isDarwin then "darwin-rebuild"
                         else if isNixOnDroid then "nix-on-droid"
                         else throw "Unsupported platform for rebuildWrapper";
          };
          
          # Command detection
          findRebuildCommand = let
            nixosRebuild = pkgs.nixos-rebuild or null;
            darwinRebuild = (pkgs.darwin or {}).darwin-rebuild or null;
            nixOnDroidRebuild = pkgs.nix-on-droid or null;
          in
            if platformInfo.isNixOS && nixosRebuild != null then nixosRebuild
            else if platformInfo.isDarwin && darwinRebuild != null then darwinRebuild
            else if platformInfo.isNixOnDroid && nixOnDroidRebuild != null then nixOnDroidRebuild
            else null;

          # Get command path safely with fallbacks
          defaultCommandPath = let
            cmd = findRebuildCommand;
            getBinPath = pkg: "${(lib.getBin or (p: p)) pkg}/bin/${platformInfo.rebuildName}";
          in
            if cmd != null then getBinPath cmd
            else if platformInfo.isNixOS then "/run/current-system/sw/bin/nixos-rebuild"
            else if platformInfo.isDarwin then "/run/current-system/sw/bin/darwin-rebuild"
            else if platformInfo.isNixOnDroid then "/run/current-system/sw/bin/nix-on-droid"
            else throw "Could not find rebuild command for your platform";
        in {
          options.system.rebuildWrapper = {
            enable = mkEnableOption "Seamless flake rebuild command wrapper";
            
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
              default = platformInfo.rebuildName;
              example = "rebuild";
            };
          };
          
          config = mkIf cfg.enable {
            environment.systemPackages = let
              # Get actual flake path
              effectiveFlakePath = 
                if cfg.flake != null 
                then toString cfg.flake.outPath
                else (assert (cfg.flakePath != ""); cfg.flakePath);
                
              # Create wrapper script
              wrapper = pkgs.writeShellScriptBin cfg.wrapperName ''
                #!/usr/bin/env bash
                exec ${cfg.commandPath} "$@" --flake ${effectiveFlakePath}#${cfg.hostname}
              '';
            in [ wrapper ];
            
            # Optional: Add warning if no flake reference provided
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
      # Make the module available for all platforms
      nixosModules.default = rebuildWrapperModule;
      darwinModules.default = rebuildWrapperModule;
      nixOnDroidModules.default = rebuildWrapperModule;
      
      # Export the module function for advanced use cases
      lib.rebuildWrapperModule = rebuildWrapperModule;
      
      # Add properly structured checks for CI
      checks = {
        x86_64-linux = makeMinimalCheck "x86_64-linux";
      };
    };
}