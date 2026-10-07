# nix-k73SV

NixOS configuration for an **ASUS K73SV** laptop (Intel iGPU, KDE Plasma 6, legacy BIOS GRUB).
Edit the files here on GitHub, then run `nix-update` on the laptop to download and apply them.

## Repo layout

```
configuration.nix          # main system config
scripts/nix-update.nix       # defines the `nix-update` command (fetch from GitHub + rebuild)
scripts/compressall.nix    # helper script imported by configuration.nix
```

`hardware-configuration.nix` is **not** in this repo. It is generated per machine and must stay local.

---

## First-time setup

### 1. Install NixOS

Install NixOS on the laptop (graphical KDE installer is fine). Use hostname `nixos` so it matches the config.

Useful checks from a terminal:

```bash
# Is the laptop booting BIOS or UEFI? (config assumes BIOS)
[ -d /sys/firmware/efi ] && echo UEFI || echo BIOS

# Which disk is the system on? (config assumes /dev/sda)
lsblk
```

### 2. Download the config files

```bash
cd /etc/nixos
sudo mkdir -p scripts

BASE=https://raw.githubusercontent.com/not-a-longneck/nix-k73SV/main

sudo curl -fsSL -o configuration.nix          $BASE/configuration.nix
sudo curl -fsSL -o scripts/nix-update.nix       $BASE/scripts/nix-update.nix
sudo curl -fsSL -o scripts/compressall.nix    $BASE/scripts/compressall.nix
```

### 3. Make sure the hardware config exists

The installer normally creates it. If `ls` shows nothing, regenerate it (this leaves `configuration.nix` untouched):

```bash
ls /etc/nixos/hardware-configuration.nix
sudo nixos-generate-config
```

### 4. Check the bootloader disk

Open `configuration.nix` and confirm `device = "/dev/sda";` matches the disk from `lsblk`
(or switch to the UEFI block in the file if the laptop boots UEFI).

### 5. Build and reboot

```bash
sudo nixos-rebuild switch
reboot
```

From now on the `nix-update` command is available in every terminal.

---

## Daily use

1. Edit `configuration.nix` on GitHub and commit to `main`.
2. On the laptop run:

```bash
nix-update
```

This backs up the current files (`*.bak`), downloads the new ones from GitHub, runs `nixos-rebuild switch`,
and **automatically restores the backups if anything fails**.

> GitHub caches raw files for a few minutes. If `nix-update` seems to pull the old version, wait a bit and run it again.

---

## Rollback and cleanup

```bash
# Go back to the previous generation
sudo nixos-rebuild switch --rollback

# List generations
sudo nix-env --list-generations -p /nix/var/nix/profiles/system

# Free disk space (deletes old generations)
sudo nix-collect-garbage -d
```

If the system won't boot properly, pick an older generation from the GRUB menu at startup.

---

## Syncing more files

Add the path (relative to `/etc/nixos/`) to `filesToSync` in `scripts/nix-update.nix`, and
make sure the file exists in this repo at the same path:

```nix
filesToSync = [
  "configuration.nix"
  "scripts/nix-update.nix"
  "scripts/compressall.nix"
];
```

Never add `hardware-configuration.nix`.

---

## Notes

- **No flakes:** this setup doesn't use a `flake.nix`. `nix-update` runs a plain `sudo nixos-rebuild switch`, which builds from `/etc/nixos/configuration.nix`.
- **Password hash:** `configuration.nix` contains `hashedPassword`. If this repo is public, consider moving it to a local, non-synced file.
- **Failed download?** The script uses `curl -f`, so a typo in a filename shows "Failed to download" instead of saving an error page.