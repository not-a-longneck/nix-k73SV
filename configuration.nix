{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # ------------------------------------------------------------
  # Boot
  # ------------------------------------------------------------

  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
    useOSProber = true;
  };

  boot.kernelPackages = pkgs.linuxPackages_latest;

  # ------------------------------------------------------------
  # Nix
  # ------------------------------------------------------------

  nix.settings.experimental-features = [
    "nix-command"
  ];

  # ------------------------------------------------------------
  # Hardware
  # ASUS K73SV: Intel Sandy Bridge graphics
  # ------------------------------------------------------------

  hardware.enableRedistributableFirmware = true;
  hardware.cpu.intel.updateMicrocode = true;

  services.xserver.videoDrivers = [ "modesetting" ];

  hardware.graphics = {
    enable = true;
  };

  environment.systemPackages = with pkgs; [
    intel-vaapi-driver
    libva-utils
  ];

  # ------------------------------------------------------------
  # Input / devices
  # ------------------------------------------------------------

  hardware.uinput.enable = true;

  services.libinput.enable = true;

  # ------------------------------------------------------------
  # Networking
  # ------------------------------------------------------------

  networking.networkmanager.enable = true;

  networking.wireless.enable = false;

  # ------------------------------------------------------------
  # Time / locale
  # ------------------------------------------------------------

  time.timeZone = "Europe/Copenhagen";

  i18n.defaultLocale = "en_DK.UTF-8";

  console = {
    keyMap = "dk";
  };

  # ------------------------------------------------------------
  # Audio
  # ------------------------------------------------------------

  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;

    alsa.enable = true;
    alsa.support32Bit = true;

    pulse.enable = true;

    wireplumber.enable = true;
  };

  # ------------------------------------------------------------
  # Users
  # ------------------------------------------------------------

  users.users.admin = {
    isNormalUser = true;

    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "render"
      "storage"
      "disk"
    ];

    # Put your existing hashed password here.
    # Do not use a plaintext password in this file.
    hashedPassword = "REPLACE_WITH_YOUR_EXISTING_HASH";
  };

  users.users.streamer = {
    isNormalUser = true;

    extraGroups = [
      "audio"
      "video"
      "render"
      "input"
      "uinput"
    ];

    # Disable password login for the streaming account.
    hashedPassword = "!";

    linger = true;
  };

  # ------------------------------------------------------------
  # KDE Plasma 6 / KWin
  # ------------------------------------------------------------

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  services.desktopManager.plasma6.enable = true;

  services.displayManager.autoLogin = {
    enable = true;
    user = "streamer";
  };

  # Plasma is a Wayland compositor, so do not use Cage.
  environment.sessionVariables = {
    QT_QPA_PLATFORM = "wayland";
  };

  # ------------------------------------------------------------
  # Permanent virtual monitor for Sunshine
  #
  # KWin sees this as:
  #     Virtual-Sunshine
  #
  # Resolution:
  #     1920x1080
  #
  # The physical laptop display is NOT disabled.
  # ------------------------------------------------------------

  systemd.user.services.sunshine-virtual-monitor = {
    description = "Permanent virtual monitor for Sunshine";

    wantedBy = [
      "graphical-session.target"
    ];

    after = [
      "graphical-session.target"
    ];

    serviceConfig = {
      ExecStart =
        "${pkgs.kdePackages.krfb}/bin/krfb-virtualmonitor "
        + "--resolution 1920x1080 "
        + "--name Sunshine "
        + "--password sunshine-local "
        + "--port 5921";

      Restart = "on-failure";
      RestartSec = 2;
    };
  };

  # ------------------------------------------------------------
  # Sunshine
  # ------------------------------------------------------------

  services.sunshine = {
    enable = true;
    autoStart = true;

    openFirewall = true;

    settings = {
      # KDE Plasma / KWin Wayland capture.
      capture = "kwin";

      # krfb-virtualmonitor creates:
      #     Virtual-Sunshine
      output_name = "Virtual-Sunshine";

      # The K73SV is old. Use the Intel GPU for encoding
      # rather than hammering the CPU with software encoding.
      encoder = "vaapi";

      # Keep the stream modest for the old hardware.
      #
      # Moonlight can request lower resolutions if desired.
      # 1080p60 is the ceiling.
      min_threads = 2;
    };
  };

  # ------------------------------------------------------------
  # Power / laptop behaviour
  # ------------------------------------------------------------

  services.thermald.enable = true;

  services.fstrim.enable = true;

  services.upower.enable = true;

  # Ignore the lid so closing the lid doesn't kill the
  # streaming desktop.
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
  };

  # ------------------------------------------------------------
  # ZRAM
  # ------------------------------------------------------------

  zramSwap.enable = true;

  # ------------------------------------------------------------
  # SSH
  # ------------------------------------------------------------

  services.openssh.enable = true;

  # ------------------------------------------------------------
  # Firewall
  # Sunshine opens its own required ports above.
  # ------------------------------------------------------------

  networking.firewall.enable = true;

  # ------------------------------------------------------------
  # Misc.
  # ------------------------------------------------------------

  programs.fuse.userAllowOther = true;

  services.fstrim.enable = true;

  # ------------------------------------------------------------
  # System state version
  # ------------------------------------------------------------

  system.stateVersion = "25.11";
}
