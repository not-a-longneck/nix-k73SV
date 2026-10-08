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

  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";   # check with: lsblk
    useOSProber = true;
  };

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelModules = [ "fuse" ];

  environment.etc."fuse.conf".text = ''
    user_allow_other
  '';

  # ======================================
  # HARDWARE (Intel CPU/iGPU laptop)
  # ======================================

  hardware.enableRedistributableFirmware = true;
  hardware.cpu.intel.updateMicrocode = true;

  services.xserver.videoDrivers = [ "modesetting" ];
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-vaapi-driver
    ];
  };

  # Enable virtual input devices for Sunshine remote control
  hardware.uinput.enable = true;

  # Laptop essentials
  services.libinput.enable = true;
  hardware.bluetooth.enable = true;
  services.thermald.enable = true;
  services.fstrim.enable = true;
  services.upower.enable = true;

  zramSwap.enable = true;

  # ======================================
  # PRIVACY & SECURITY
  # ======================================

  services.journald.extraConfig = ''
    Storage=volatile
    ForwardToSyslog=no
    ForwardToKMsg=no
    ForwardToConsole=no
    ForwardToWall=no
  '';

  systemd.coredump.enable = false;

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
    networkmanager.enable = true;
    networkmanager.wifi.powersave = false;
  };

  time.timeZone = "Europe/Copenhagen";

  i18n.defaultLocale = "en_DK.UTF-8";
  console.keyMap = "dk";

  # Fully disable physical display managers
  services.displayManager.sddm.enable = false;
  services.desktopManager.plasma6.enable = false;

  # Enable Realtime Scheduling Daemon (Fixes WirePlumber RTKit errors)
  security.rtkit.enable = true;

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

  users.users.streamer = {
    isNormalUser = true;
    description = "Virtual Desktop Streamer";
    extraGroups = [ "audio" "video" "render" "input" "uinput" ];
    hashedPassword = "!";
    linger = true;
  };

  services.udev.extraRules = ''
    KERNEL=="dm-*", ENV{ID_FS_USAGE}=="filesystem", OWNER="admin", GROUP="users", MODE="0775"
  '';

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
    cifs-utils
    veracrypt
    ntfs3g
    kdePackages.kate
    wayfire                  # Headless 3D Wayland compositor
    wayfirePlugins.wf-shell  # Panel and desktop UI
    alacritty                # Terminal emulator
    pcmanfm-qt               # Standalone file manager
    mako                     # Lightweight Wayland notification daemon
  ];

  services.logind.lidSwitch = "ignore";
  services.logind.lidSwitchExternalPower = "ignore";

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

  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;
    settings = {
      encoder = "software"; # Avoid Sandy Bridge hardware encoder crash
    };
  };

  # Headless auto-login for streamer into Wayfire via Cage
  services.displayManager.autoLogin = {
    enable = true;
    user = "streamer";
  };

  services.cage = {
    enable = true;
    user = "streamer";
    program = "${pkgs.wayfire}/bin/wayfire";
  };

  # Desktop integration portal
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-wlr ];
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
