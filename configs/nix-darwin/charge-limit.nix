# Battery charge limit from System Settings > Battery (macOS 26.4+).
# macOS has no CLI or readable preference for it, so activation calls the
# private PowerUISmartChargeClient that System Settings (and batt) use.
{ config, lib, pkgs, ... }:

let
  cfg = config.local.chargeLimit;
  setLimit = pkgs.writeText "set-charge-limit.js" ''
    function run(argv) {
      ObjC.import('Foundation');
      $.NSBundle.bundleWithPath('/System/Library/PrivateFrameworks/PowerUI.framework').load;
      var cls = $.NSClassFromString('PowerUISmartChargeClient');
      if (cls.isNil()) return 'charge limit: PowerUI client unavailable, skipping';
      var client = cls.alloc.initWithClientName('nix-darwin');
      if (!client.isMCLSupported) return 'charge limit: not supported here, skipping';
      var want = parseInt(argv[0], 10);
      if (client.getMCLLimitWithError(null) == want && client.isMCLCurrentlyEnabled(null) == 1)
        return 'charge limit: already ' + want + '%';
      var err = Ref();
      if (client.setMCLLimitError(want, err)) return 'charge limit: set to ' + want + '%';
      return 'charge limit: failed: ' + (err[0] ? ObjC.unwrap(err[0].localizedDescription) : 'unknown error');
    }
  '';
in
{
  options.local.chargeLimit = lib.mkOption {
    type = lib.types.nullOr (lib.types.enum [ 80 85 90 95 100 ]);
    default = null;
    description = "Maximum battery charge in percent, or null to leave it alone.";
  };

  config = lib.mkIf (cfg != null) {
    system.activationScripts.postActivation.text = ''
      /usr/bin/osascript -l JavaScript ${setLimit} ${toString cfg} >&2 || true
    '';
  };
}
