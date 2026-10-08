{ pkgs, ... }:

let
  baseUrl = "https://raw.githubusercontent.com/not-a-longneck/nix-k73SV/main";
  apiUrl = "https://api.github.com/repos/not-a-longneck/nix-k73SV/commits/main";
  configDir = "/etc/nixos";

  filesToSync = [
    "configuration.nix"
    "scripts/nix-update.nix"
    # "scripts/compressall.nix"
  ];
in
{
  # Ensure jq and curl are available in system environment
  environment.systemPackages = [ pkgs.jq pkgs.curl ];

  environment.interactiveShellInit = ''
    nix-update() {
      echo "📦 Step 1: Creating backups..."
      for file in ${builtins.concatStringsSep " " filesToSync}; do
        if [ -f "${configDir}/$file" ]; then
          sudo mkdir -p "$(dirname "${configDir}/$file.bak")"
          sudo cp "${configDir}/$file" "${configDir}/$file.bak"
        fi
      done

      echo "🔄 Step 2: Downloading files from GitHub..."
      commit_msg=$(${pkgs.curl}/bin/curl -sSL "${apiUrl}" | ${pkgs.jq}/bin/jq -r '.commit.message' | head -n 1)
      if [ -n "$commit_msg" ]; then
        echo "($commit_msg)"
      fi

      local download_failed=0
      for file in ${builtins.concatStringsSep " " filesToSync}; do
        sudo mkdir -p "$(dirname "${configDir}/$file")"

        if ! sudo curl -fsSL -o "${configDir}/$file" "${baseUrl}/$file"; then
          echo "❌ Failed to download $file"
          download_failed=1
          break
        fi
      done

      if [ $download_failed -eq 0 ]; then
        echo "❄️ Step 3: Rebuilding NixOS..."
        if sudo nixos-rebuild switch; then
          gen_num=$(readlink /nix/var/nix/profiles/system | cut -d- -f2)
          echo "✨ Success! Updated to Generation $gen_num!"
          return 0
        fi
      fi

      echo "❌ Update failed! Restoring backups..."
      for file in ${builtins.concatStringsSep " " filesToSync}; do
        if [ -f "${configDir}/$file.bak" ]; then
          sudo cp "${configDir}/$file.bak" "${configDir}/$file"
        fi
      done
      return 1
    }
  '';
}
