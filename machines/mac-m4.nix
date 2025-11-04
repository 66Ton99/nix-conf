{ config, pkgs, programs, ... }: {
  imports = [
    ../pkgs/dev.nix
  ];
  
  environment.systemPackages = with pkgs; [
  	zstd
  	ffmpeg-full
  	opencore-amr
  	vo-amrwbenc
  	portaudio
  	xz
  	python312
  	python312Packages.tkinter
  	python312Packages.pylzma
  	python312Packages.pip
  	python312Packages.poetry-core
  	python312Packages.huggingface-hub
  	python312Packages.hf-xet
  	python312Packages.conda
  	python312Packages.libmambapy
  	python312Packages.xonsh
  	python312Packages.pre-commit-hooks
  ];
}
