{
  description = "Flake-based devShell with LLVM 20 and Bazel helpers";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          llvmPackages = pkgs.llvmPackages_20;
          projectRoot = "${toString ./.}";

          pythonShim = pkgs.writeShellScriptBin "python3" ''
            export LD_LIBRARY_PATH=$NIX_LD_LIBRARY_PATH
            export PYTHONPATH=$PYTHONPATH
            export PATH=$PATH
            exec ${pkgs.python3}/bin/python3 "$@"
          '';

          bazelShim = pkgs.writeShellScriptBin "bazel" ''
            exec ${projectRoot}/scripts/run_bazelisk.py "$@"
          '';

          nixLdLibraryPath = pkgs.lib.makeLibraryPath [
            pkgs.stdenv.cc.cc
            pkgs.zlib
          ];
          nixLd = pkgs.lib.fileContents "${pkgs.stdenv.cc}/nix-support/dynamic-linker";
        in
        {
          default = pkgs.mkShell.override { stdenv = llvmPackages.stdenv; } {
            packages = [
              (pkgs.hiPrio llvmPackages.clang-tools)
              llvmPackages.clangUseLLVM
              llvmPackages.llvm
              llvmPackages.libcxx
              llvmPackages.compiler-rt
              llvmPackages.libunwind
              llvmPackages.bintools
              pkgs.pre-commit
              pkgs.git
              pkgs.gh
              pkgs.ruff
              pkgs.basedpyright
              pythonShim
              bazelShim
            ];

            NIX_LD_LIBRARY_PATH = nixLdLibraryPath;
            NIX_LD = nixLd;

            shellHook = ''
              env_fix="./bazel/version/rules.bzl ./bazel/carbon_rules/defs.bzl"
              if grep -q "NIX" .bazelrc; then
                awk -v k=20 'NR > k { print lines[NR-k] } { lines[NR] = $0 }' .bazelrc > tmprc
                mv tmprc .bazelrc
              fi
              for f in $env_fix
              do
                if ! grep -q "use_default_shell_env" $f; then
                  awk '/ctx.actions.run/ {print; print "use_default_shell_env = True,"; next} {print}' $f > tmprules
                  mv tmprules $f
                fi
              if ! grep -q ".direnv" .bazelignore; then
                awk '1; END { print "\n# Nix Flake\n.direnv" }' .bazelignore > .tmpignore
                mv .tmpignore .bazelignore
              fi
              if ! grep -q ".direnv" .gitignore; then
                awk '1; END { print "\n# Nix Flake\n/.direnv" }' .gitignore > .tmpignore
                mv .tmpignore .gitignore
              fi
              done
              echo "common --action_env=NIX_CFLAGS_COMPILE" >> .bazelrc
              echo "common --host_action_env=NIX_CFLAGS_COMPILE" >> .bazelrc
              echo "common --action_env=NIX_CC_WRAPPER_TARGET_HOST_x86_64_unknown_linux_gnu" >> .bazelrc
              echo "common --host_action_env=NIX_CC_WRAPPER_TARGET_HOST_x86_64_unknown_linux_gnu" >> .bazelrc
              echo "common --action_env=LD" >> .bazelrc
              echo "common --host_action_env=LD" >> .bazelrc
              echo "common --action_env=NIX_LDFLAGS" >> .bazelrc
              echo "common --host_action_env=NIX_LDFLAGS" >> .bazelrc
              echo "common --action_env=NIX_BINTOOLS_WRAPPER_TARGET_HOST_x86_64_unknown_linux_gnu" >> .bazelrc
              echo "common --host_action_env=NIX_BINTOOLS_WRAPPER_TARGET_HOST_x86_64_unknown_linux_gnu" >> .bazelrc
              echo "common --action_env=NIX_LD" >> .bazelrc
              echo "common --host_action_env=NIX_LD" >> .bazelrc
              echo "common --action_env=NIX_BINTOOLS" >> .bazelrc
              echo "common --host_action_env=NIX_BINTOOLS" >> .bazelrc
              echo "common --action_env=PATH" >> .bazelrc
              echo "common --host_action_env=PATH" >> .bazelrc
              echo "common --action_env=NIX_LD_LIBRARY_PATH" >> .bazelrc
              echo "common --host_action_env=NIX_LD_LIBRARY_PATH" >> .bazelrc
              echo "common --action_env=LIBRARY_PATH" >> .bazelrc
              echo "common --host_action_env=LIBRARY_PATH" >> .bazelrc
            '';
          };
        }
      );
    };
}
