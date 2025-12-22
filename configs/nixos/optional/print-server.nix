# Network print server with web interface
# Access at http://<hostname>:631
{ pkgs, ... }:

{
  services.printing = {
    enable = true;
    drivers = [ pkgs.hplip ];
    listenAddresses = [ "*:631" ]; # Listen on all interfaces
    allowFrom = [ "all" ]; # Allow connections from network
    browsing = true; # Advertise printers
    defaultShared = true; # Share all printers by default
    openFirewall = true;
  };

  # Enable web interface administration
  services.printing.extraConf = ''
    DefaultEncryption Never
  '';

  # Pre-configure HP LaserJet M110we (WiFi printer)
  # Uses IPP Everywhere (driverless) - no PPD needed
  hardware.printers = {
    ensureDefaultPrinter = "HP_LaserJet_M110we";
    ensurePrinters = [
      {
        name = "HP_LaserJet_M110we";
        description = "HP LaserJet M110we (WiFi)";
        location = "Home";
        deviceUri = "ipp://192.168.1.234/ipp/print";
        model = "everywhere"; # IPP Everywhere driverless
      }
    ];
  };

  # Avahi for AirPrint / network discovery
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
    publish = {
      enable = true;
      userServices = true;
    };
  };

  # Allow lpadmin group to manage printers via web UI
  users.groups.lpadmin = { };
}
