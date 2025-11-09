{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  packages = with pkgs; [
  	python313
  	python313Packages.tkinter
  	python313Packages.pylzma
  	python313Packages.pip
  	python313Packages.poetry-core
  	python313Packages.huggingface-hub
  	python313Packages.hf-xet
  	python313Packages.conda
  	python313Packages.libmambapy
  	python313Packages.xonsh
  	python313Packages.pre-commit-hooks
  ];
}
