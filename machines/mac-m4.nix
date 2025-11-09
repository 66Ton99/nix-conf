{ config, pkgs, programs, ... }: {
  imports = [
    ../pkgs/dev.nix
  ];
  
  environment.systemPackages = with pkgs; [
  	gollama
  	aider-chat-full
  	aider-chat-with-bedrock
  	aider-chat-with-browser
  	aider-chat-with-help
  	aider-chat-with-playwright
  ];
  # lmstudio

}
