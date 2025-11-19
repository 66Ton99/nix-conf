{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  packages = with pkgs; [
  	poetry
  	(python313.withPackages(p: with p; [ 
  		pip
  		poetry-core
  		pre-commit-hooks
  	]))
  ];
  
  shellHook = ''
    python -m venv .venv
    source .venv/bin/activate
  '';
}
