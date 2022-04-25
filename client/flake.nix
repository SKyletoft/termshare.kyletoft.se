{
	description = "A Rust program";

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
			termshare = with final; final.callPackage ({ inShell ? false }: stdenv.mkDerivation rec {
				name = "termshare-${version}";
				src = if inShell then null else ./.;
				buildInputs =
					[
						rustc
						cargo
					] ++ (if inShell then [
						rustfmt
						clippy
					] else [
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
			inherit (nixpkgsFor.${system}) termshare;
		});
		defaultPackage = forAllSystems (system: self.packages.${system}.termshare);
		devShell = forAllSystems (system: self.packages.${system}.termshare.override { inShell = true; });
	};
}
