# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix   # REGENERATE on the laptop: sudo nixos-generate-config
    ./scripts/nix-update.nix
    ./scripts/compressall.nix
  ];

  # Enable the modern `nix` CLI (flakes are not used in this setup)
  nix.settings.experimental-features = [ "nix-command" ];

  # ======================================
  # SYSTEM & BOOTLOADER
  # ======================================

  # The ASUS K73-series is a 2011 Sandy Bridge laptop and normally boots in
  # legacy BIOS mode. Set `device` to the DISK (not a partition) you install to.
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";   # check with: lsblk
    useOSProber = true;
  };

  # Use latest kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelModules = [ "fuse" ];

  # Allow non-root users to use the allow_other mount option
  environment.etc."fuse.conf".text = ''
    user_allow_other
  '';

  # ======================================
  # HARDWARE (Intel CPU/iGPU laptop)
  # ======================================

  hardware.enableRedistributableFirmware = true;   # Wi-Fi / Bluetooth firmware
  hardware.cpu.intel.updateMicrocode = true;

  services.xserver.videoDrivers = [ "modesetting" ];
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-vaapi-driver   # VA-API video decode for Sandy Bridge
    ];
  };

  # Virtual input device capability for Sunshine remote input
  hardware.uinput.enable = true;

  # Laptop essentials
  services.libinput.enable = true;        # touchpad
  hardware.bluetooth.enable = true;
  services.thermald.enable = true;        # Intel thermal management
  services.fstrim.enable = true;          # if the laptop has an SSD
  services.upower.enable = true;

  # Compressed swap in RAM; helpful on older laptops with limited memory
  zramSwap.enable = true;

  # Disable sleep on lid close
  services.logind.settings = {
    Login = {
      HandleLidSwitch = "ignore";
      HandleLidSwitchExternalPower = "ignore";
    };
  };

  # ======================================
  # PRIVACY & SECURITY
  # ======================================

  # Store system logs only in volatile memory (wiped on restart)
  services.journald.extraConfig = ''
    Storage=volatile
    ForwardToSyslog=no
    ForwardToKMsg=no
    ForwardToConsole=no
    ForwardToWall=no
  '';

  # Disable core dumps on application crashes
  systemd.coredump.enable = false;

  # Mount local cache to RAM disk to clear history/trackers instantly on power-off
  fileSystems."/home/admin/.cache" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [ "nosuid" "nodev" "relatime" "size=1G" ];
  };

  # ======================================
  # NETWORKING & LOCALIZATION
  # ======================================

  networking = {
    hostName = "nixos";
    networkmanager.enable = true;   # handles Wi-Fi as well
    networkmanager.wifi.powersave = false; # prevents Wi-Fi dropouts on idle
  };

  time.timeZone = "Europe/Copenhagen";

  i18n.defaultLocale = "en_DK.UTF-8";
  console.keyMap = "dk";

  # Disable default physical display managers (headless boot)
  services.displayManager.sddm.enable = false;
  services.desktopManager.plasma6.enable = false;

  # ======================================
  # AUDIO (PIPEWIRE)
  # ======================================

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
    extraConfig.pipewire."92-low-latency" = {
      "context.properties" = {
        "default.clock.rate" = 48000;
        "default.clock.quantum" = 1024;
        "default.clock.min-quantum" = 512;
        "default.clock.max-quantum" = 2048;
      };
    };
  };

  # ======================================
  # USERS & SECURITY
  # ======================================

  users.users.admin = {
    isNormalUser = true;
    description = "admin";
    extraGroups = [ "networkmanager" "wheel" "video" "render" "storage" "disk" ];
    hashedPassword = "$6$Osqk1/PTMVPFxz.R$xnhXNz5ePRgPQZtGMaXlSDInDsrwNocuRqVmTfZcq4ujAer6PiesG27vZpkxdMJh3gtSzP9qOlTs8CTP9Pf.f/";
  };

  # Dedicated background streaming account for virtual desktop session
  users.users.streamer = {
    isNormalUser = true;
    description = "Virtual Desktop Streamer";
    extraGroups = [ "audio" "video" "render" "input" "uinput" ];
    hashedPassword = "!";
    linger = true; # Keeps background session active on boot
  };

  # Grant admin sudo rights to VeraCrypt/virtual drives
  services.udev.extraRules = ''
    KERNEL=="dm-*", ENV{ID_FS_USAGE}=="filesystem", OWNER="admin", GROUP="users", MODE="0775"
  '';

  # Ensure user ownership over local nix folder permissions
  system.activationScripts.nixosFolderPermissions = {
    text = ''
      chown -R admin:users /etc/nixos
      chmod -R 755 /etc/nixos
    '';
  };

  # ======================================
  # ENVIRONMENT & PACKAGES
  # ======================================

  nixpkgs.config.allowUnfree = true;
  services.flatpak.enable = true;
  xdg.portal.enable = true;

  programs.firefox.enable = true;

  environment.systemPackages = with pkgs; [
    cifs-utils      # SMB/CIFS mount support
    veracrypt       # Encryption management
    ntfs3g          # Windows filesystem support
    kdePackages.kate
    rustdesk-flutter
    wayfire         # Standalone 3D Wayland desktop environment
    wf-shell        # Panel, dock, and launchers for Wayfire
    alacritty       # Terminal emulator inside virtual desktop
    pcmanfm-qt      # Standalone file manager inside virtual desktop
  ];


  # ======================================
  # MOUNTS
  # ======================================

  fileSystems."/mnt/tower/backups" = {
    device = "//192.168.1.53/backups";
    fsType = "cifs";
    options = [
      "guest"
      "uid=1000"
      "gid=100"
      "rw"
      "forceuid"
      "forcegid"
      "noperm"
      "nobrl"
      "cache=none"
      "iocharset=utf8"
      "vers=3.0"
      "soft"
      "nofail"
      "_netdev"
      "x-systemd.automount"
      "x-systemd.idle-timeout=60"
      "x-systemd.mount-timeout=10"
    ];
  };

  # ======================================
  # HEADLESS VIRTUAL DESKTOP & SUNSHINE
  # ======================================

  # System-wide Sunshine streaming server
  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;
  };

  # Auto-login the streamer user into Cage running Wayfire as a virtual desktop
  services.displayManager.autoLogin = {
    enable = true;
    user = "streamer";
  };

  services.cage = {
    enable = true;
    user = "streamer";
    program = "${pkgs.wayfire}/bin/wayfire";
  };

  # ======================================
  # SECURE SSH & FIREWALL (LAN ONLY)
  # ======================================

  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      PasswordAuthentication = true;
      KbdInteractiveAuthentication = true;
      PermitRootLogin = "no";
    };
    extraConfig = ''
      AllowUsers admin
    '';
  };

  networking.firewall.allowPing = true;

  # Allow local network SSH access at position 1 in iptables chain
  networking.firewall.extraCommands = ''
    iptables -I INPUT 1 -p tcp --dport 22 -s 192.168.1.0/24 -j ACCEPT
  '';
  networking.firewall.extraStopCommands = ''
    iptables -D INPUT -p tcp --dport 22 -s 192.168.1.0/24 -j ACCEPT || true
  '';

  # ======================================
  # SYSTEM STATE VERSION
  # ======================================

  system.stateVersion = "25.11";
}
