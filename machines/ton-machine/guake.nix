{ ... }:
{
  nixpkgs.overlays = [
    (_final: prev: {
      guake = prev.guake.overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''
          terminal_py=$(find "$out/lib" -type f -path '*/guake/terminal.py' -print -quit)
          if [ -z "$terminal_py" ]; then
            echo "Guake terminal.py was not found for the Super-click patch" >&2
            exit 1
          fi
          substituteInPlace "$terminal_py" \
            --replace-fail \
            'if event.button == 1 and (event.get_state() & Gdk.ModifierType.CONTROL_MASK):' \
            'if event.button == 1 and (event.get_state() & (Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.SUPER_MASK)):'
          find "$out" -type f -name '*.pyc' -delete
        '';
      });
    })
  ];
}
