{ ... }:
let
  inherit (import ./constants.nix) chatPublishedPath;
in
{
  # MindRoom Chat is a static build published from another machine into
  # releases/<ts>-<ref>-<sha>; `current` points at the live one (caddy.nix).
  systemd.tmpfiles.rules = [
    "d ${chatPublishedPath} 0755 basnijholt users -"
    "d ${chatPublishedPath}/releases 0755 basnijholt users -"
  ];
}
