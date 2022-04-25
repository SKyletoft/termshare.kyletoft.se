{
	description = "A Rust web server including a NixOS module";

	inputs = {
		nixpkgs.url = github:NixOS/nixpkgs;
		import-cargo.url = github:edolstra/import-cargo;
	};

	outputs = { self, nixpkgs, import-cargo }:
	let
		lastModifiedDate = self.lastModifiedDate or self.lastModified or "19700101";
		version = "${builtins.substring 0 8 lastModifiedDate}-${self.shortRev or "dirty"}";
		supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
		forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);
		nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; overlays = [ self.overlay ]; });
	in {
		overlay = final: prev: {
			rust-web-server = with final; final.callPackage ({ inShell ? false }: stdenv.mkDerivation rec {
				name = "rust-web-server-${version}";
				src = if inShell then null else ./.;
				buildInputs =
					(if inShell then [
						rustup
					] else [
						rustc
						cargo
						(import-cargo.builders.importCargo {
							lockFile = ./Cargo.lock;
							inherit pkgs;
						}).cargoHome
					]);
				target = "--release";
				buildPhase = "cargo build ${target} --frozen --offline";
				doCheck = true;
				checkPhase = "cargo test ${target} --frozen --offline";
				installPhase = ''
					mkdir -p $out
					cargo install --frozen --offline --path . --root $out
					rm $out/.crates.toml
				'';
			}) {};

		};

		packages = forAllSystems (system:{
			inherit (nixpkgsFor.${system}) rust-web-server;
		});
		defaultPackage = forAllSystems (system: self.packages.${system}.rust-web-server);
		devShell = forAllSystems (system: self.packages.${system}.rust-web-server.override { inShell = true; });
		nixosModules.rust-web-server = { pkgs, ... }: {
			nixpkgs.overlays = [ self.overlay ];
			systemd.services.rust-web-server = {
				wantedBy = [ "multi-user.target" ];
				serviceConfig.ExecStart = "${pkgs.rust-web-server}/bin/rust-web-server";
			};
		};

		# Tests run by 'nix flake check' and by Hydra.
		checks = forAllSystems (system:
			with nixpkgsFor.${system};
			{
				inherit (self.packages.${system}) rust-web-server;
				vmTest =
					with import (nixpkgs + "/nixos/lib/testing-python.nix") {
						inherit system;
					};
				makeTest {
					nodes = {
						client = { ... }: {
							imports = [ self.nixosModules.rust-web-server ];
						};
					};
					testScript = ''
						start_all()
						client.wait_for_unit("multi-user.target")
						assert "Hello Nixers" in client.wait_until_succeeds("curl --fail http://localhost:8080/")
					'';
				};
			}
		);
	};
}
