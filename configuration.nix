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

  # --- If your machine is actually booting UEFI, use this instead: ---
  # boot.loader.grub = {
  #   enable = true;
  #   device = "nodev";
  #   efiSupport = true;
  #   useOSProber = true;
  # };
  # boot.loader.efi.canTouchEfiVariables = true;
  # (and mount the EFI partition at /boot)

  # Use latest kernel (fine here since we are not using the legacy NVIDIA driver)
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

  # Intel integrated graphics via the modesetting driver.
  # The GeForce GT 540M-class dGPU is too old for current NVIDIA drivers (390xx
  # does not work with recent kernels), so we run on the Intel iGPU only and
  # leave the NVIDIA chip to nouveau, which can power it down when idle.
  services.xserver.videoDrivers = [ "modesetting" ];
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-vaapi-driver   # VA-API video decode for Sandy Bridge
    ];
  };

  # Laptop essentials
  services.libinput.enable = true;        # touchpad
  hardware.bluetooth.enable = true;
  services.thermald.enable = true;        # Intel thermal management
  services.fstrim.enable = true;          # if the laptop has an SSD
  services.upower.enable = true;
  # Plasma 6 uses power-profiles-daemon for the battery/performance slider.

  # Compressed swap in RAM; helpful on older laptops with limited memory
  zramSwap.enable = true;

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
  # (lower this to 512M if the laptop has 4 GB of RAM or less)
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
  };

  time.timeZone = "Europe/Copenhagen";

  i18n.defaultLocale = "en_DK.UTF-8";
  console.keyMap = "dk";

  # ======================================
  # DESKTOP & GRAPHICS (KDE)
  # ======================================

  services.xserver = {
    enable = true;
    xkb = {
      layout = "dk";
      variant = "";
    };
  };

  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Global defaults to disable Dolphin previews and Taskbar thumbnail popups
  environment.etc = {
    "xdg/dolphinrc".text = ''
      [PreviewSettings]
      Plugins=
    '';

    "xdg/plasmarc".text = ''
      [TaskManager]
      ShowTooltips=false
    '';
  };

  # ======================================
  # AUDIO (PIPEWIRE)
  # ======================================

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
    # Extra configuration to stabilize the clock and handle choppiness
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

  programs.firefox.enable = true;

  environment.systemPackages = with pkgs; [
    cifs-utils      # SMB/CIFS mount support
    veracrypt       # Encryption management
    ntfs3g          # Windows filesystem support
    kdePackages.kate
    rustdesk-flutter
  ];


# Optional, but recommended for a laptop: don't suspend when the lid closes
services.logind.lidSwitch = "ignore";
services.logind.lidSwitchExternalPower = "ignore";


  # ======================================
  # MOUNTS
  # ======================================

  # Network Storage Mount (CIFS Tower Share)
  # A laptop is often away from home, so "nofail" + short timeout keep boot
  # and shutdown from hanging when the share is unreachable.
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
  # HEADLESS SUNSHINE (dedicated streaming session)
  # ======================================

  # Locked-down user: no wheel, password login disabled (autologin only)
  users.users.streamer = {
    isNormalUser = true;
    description = "Sunshine streaming session";
    extraGroups = [ "video" "render" "input" ];
    hashedPassword = "!";
  };

  services.sunshine = {
    enable = true;
    autoStart = false;       # we launch it from the session script below
    capSysAdmin = true;      # needed for KMS capture on Wayland
    openFirewall = true;
    settings = {
      capture = "kms";
      # encoder = "vaapi";   # or "software"; see notes below
    };
    applications = {
      apps = [
        { name = "Terminal"; cmd = "${pkgs.foot}/bin/foot"; }
        { name = "Firefox";  cmd = "${pkgs.firefox}/bin/firefox"; }
      ];
    };
  };

  # Session script: start Sunshine in the background, then keep Cage alive
  # with a program that does nothing. Apps launched from Moonlight appear
  # as Wayland clients inside Cage.
  services.displayManager.sessionPackages = let
    streamSession = pkgs.writeShellScript "sunshine-cage-session" ''
      ${config.security.wrapperDir}/sunshine &
      exec ${pkgs.coreutils}/bin/sleep infinity
    '';
  in [
    ((pkgs.writeTextDir "share/wayland-sessions/sunshine-cage.desktop" ''
      [Desktop Entry]
      Name=Sunshine (Cage)
      Exec=${pkgs.cage}/bin/cage -s -- ${streamSession}
      Type=Application
    '').overrideAttrs (old: {
      passthru = (old.passthru or { }) // { providedSessions = [ "sunshine-cage" ]; };
    }))
  ];

  services.displayManager.autoLogin = {
    enable = true;
    user = "streamer";
  };
  services.displayManager.defaultSession = "sunshine-cage";



  # ======================================
  # SYSTEM STATE VERSION
  # ======================================

  system.stateVersion = "25.11";
}
