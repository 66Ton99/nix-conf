{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  packages = with pkgs; [
  	poetry
  	python313
  	python313Packages.pip
  	python313Packages.poetry-core
  ];
}
