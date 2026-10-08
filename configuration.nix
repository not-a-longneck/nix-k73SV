# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:

let
  # UID of the user Sunshine runs as (admin). Pinned so the system-level
  # Sunshine service can point at this user's PipeWire socket. Verify with
  # `id admin` BEFORE rebuilding; if it differs, use the real value.
  sunshineUid = 1000;

  # Sunshine config. Written here (rather than via services.sunshine.settings)
  # because the module's generated file is not exposed to a custom system unit.
  sunshineConf = pkgs.writeText "sunshine.conf" ''
    capture = kms
    encoder = software
    sw_preset = ultrafast
  '';
in
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

  # Disable the phantom VGA-1 connector (card0). The kernel reports it as
  # connected with nothing plugged in, which made KWin turn off the laptop
  # panel on lid close and killed the stream. Remove if you ever use that port.
  boot.kernelParams = [ "video=VGA-1:d" ];

  # Replaces the manual /etc/fuse.conf and the fuse kernel module entry
  programs.fuse.userAllowOther = true;

  # ======================================
  # HARDWARE (Intel CPU/iGPU laptop)
  # ======================================

  hardware.enableRedistributableFirmware = true;
  hardware.cpu.intel.updateMicrocode = true;

  hardware.graphics = {
    enable = true;
    # Used for video decoding in apps. Sunshine itself encodes in software
    # because the Sandy Bridge hardware encoder crashes.
    extraPackages = with pkgs; [ intel-vaapi-driver ];
  };

  # Virtual input devices for Sunshine remote control
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
  services.xserver.xkb.layout = "dk";   # keyboard layout for the SDDM greeter and Plasma

  # ======================================
  # AUDIO (PIPEWIRE)
  # ======================================

  # Realtime scheduling daemon (fixes WirePlumber RTKit errors)
  security.rtkit.enable = true;

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
    uid = sunshineUid;
    extraGroups = [
      "networkmanager" "wheel" "video" "render" "storage" "disk"
      "audio" "input" "uinput"   # audio and virtual input for Sunshine
    ];
    hashedPassword = "$6$Osqk1/PTMVPFxz.R$xnhXNz5ePRgPQZtGMaXlSDInDsrwNocuRqVmTfZcq4ujAer6PiesG27vZpkxdMJh3gtSzP9qOlTs8CTP9Pf.f/";

    # Starts the user manager (and PipeWire) at boot, so audio exists
    # before anyone logs in.
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
  # DESKTOP: PLASMA 6 + SDDM LOGIN SCREEN
  # ======================================

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  services.desktopManager.plasma6.enable = true;
  services.displayManager.defaultSession = "plasma";

  # No autologin: the SDDM greeter is what you see (and stream) after boot.

  # ======================================
  # SUNSHINE (SYSTEM-LEVEL, STREAMS THE LOGIN SCREEN)
  # ======================================

  # The module is kept for the package, firewall ports, avahi and uinput udev
  # rules. Its user service is disabled; the system service below replaces it.
  services.sunshine = {
    enable = true;
    autoStart = false;
    openFirewall = true;
  };

  systemd.services.sunshine = {
    description = "Sunshine stream host (starts at boot, before login)";
    wantedBy = [ "multi-user.target" ];
    wants = [ "user@${toString sunshineUid}.service" ];
    after = [
      "network-online.target"
      "systemd-logind.service"
      "user@${toString sunshineUid}.service"
    ];

    # Audio: attach to admin's PipeWire (kept alive by linger)
    environment = {
      XDG_RUNTIME_DIR = "/run/user/${toString sunshineUid}";
      PULSE_SERVER = "unix:/run/user/${toString sunshineUid}/pulse/native";
    };

    serviceConfig = {
      User = "admin";
      ExecStart = "${lib.getExe config.services.sunshine.package} ${sunshineConf}";

      # KMS capture needs CAP_SYS_ADMIN; granting only this avoids running as root
      AmbientCapabilities = [ "CAP_SYS_ADMIN" ];
      CapabilityBoundingSet = [ "CAP_SYS_ADMIN" ];

      Restart = "on-failure";
      RestartSec = 3;
    };
  };

  # ======================================
  # POWER & LID
  # ======================================

  # Lid closed = keep running
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
  };

  # Never suspend: a sleeping laptop cannot be reached by Moonlight
  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };

  # ======================================
  # SECURE SSH & FIREWALL (LAN ONLY)
  # ======================================

  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      PasswordAuthentication = true;   # TODO: switch to keys, then set false
      KbdInteractiveAuthentication = true;
      PermitRootLogin = "no";
    };
    extraConfig = ''
      AllowUsers admin
    '';
  };

  # TODO: users.users.admin.openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAA..." ];

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
