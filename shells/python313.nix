{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  packages = with pkgs; [
  	poetry
  	(python313.withPackages (ps: [ 
  		ps.pip
  		ps.poetry-core
  		ps.pre-commit-hooks
  	]))
  ];
  
  shellHook = ''
    python -m venv .venv
    source .venv/bin/activate
  '';
}
