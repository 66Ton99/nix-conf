{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  packages = with pkgs; [
    poetry
  	python312
  	python312Packages.pip
  	python312Packages.poetry-core
  	python312Packages.pre-commit-hooks
  ];
  
  shellHook = ''
    python -m venv .venv
    source .venv/bin/activate
  '';
}

