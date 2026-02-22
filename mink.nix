{ config, lib, pkgs, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  # Boot
  boot.loader.systemd-boot.enable = false;
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "nodev";
  boot.loader.grub.useOSProber = true;
  boot.loader.grub.efiSupport = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot";
  boot.kernelPackages = pkgs.linuxPackages_zen;   # same as your Arch
  boot.kernelParams = [
      "loglevel=3" "quiet"
      "nvidia_drm.modeset=1"
      "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
      "mem_sleep_default=deep"                            # forces deeper sleep — fixes most black-screen wakes
      "nvidia_drm.fbdev=1"                               # helps mixed internal/HDMI resume 
      "mem_encrypt=on"
      "kvm_amd.sev=1"
      ];

  # ====================== GRAPHICS - NVIDIA + AMD HYBRID (your exact hardware) ======================

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    };

hardware.nvidia = {
  # Modesetting is required for PRIME and Wayland
  modesetting.enable = true;
  # Power management — enables nvidia-suspend/resume services automatically
  powerManagement = {
    enable = true;        # matches Arch + Hyprland wiki requirement
    finegrained = true;   # turns dGPU completely off when idle (critical for hybrid laptops)
  };
  # Keeps driver resident for faster resume
  nvidiaPersistenced = true;
  # You are already using open drivers (best for RTX 50-series)
  open = true;
  package = config.boot.kernelPackages.nvidiaPackages.stable;
  nvidiaSettings = true;
  # PRIME offload (your exact bus IDs)
  prime = {
    offload.enable = true;
    offload.enableOffloadCmd = true;
    amdgpuBusId = "PCI:106:0:0";
    nvidiaBusId   = "PCI:1:0:0";
  };
};

# Required for PRIME compatibility on Wayland (keep this)
  services.xserver.videoDrivers = [ "modesetting" "nvidia" ];

  services.power-profiles-daemon.enable = true; 
    
  environment.variables = {
    AMD_VULKAN_ICD = "RADV";
    NIXOS_OZONE_WL = "1";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";   # from your hyprland.conf
    GBM_BACKEND = "nvidia-drm";
    LIBVA_DRIVER_NAME = "nvidia";
    __GL_VRR_ALLOWED = "1";
    __GL_GSYNC_ALLOWED = "1";
  };

  # NVIDIA offload wrapper (use for games: nvidia-offload steam / nvidia-offload lutris)


  # ====================== HYPR LAND ======================
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  # ====================== ASUS ROG TOOLS (exact match to Arch) ======================
  services.asusd = {
    enable = true;
    enableUserService = true;
  };
  
  systemd.services.supergfxd.path = [ pkgs.pciutils ];  # critical fix

  services.supergfxd = {
    enable = true;
    # mode is controlled by /etc/supergfxd.conf (keeps your Hybrid setting)
  };

  programs.rog-control-center.enable = true;

  # ====================== AUDIO ======================
  services.pipewire = {
    enable = true;
    pulse.enable = true;
    jack.enable = true;
    alsa.enable = true;
  };
  security.rtkit.enable = true;
  
  # Restart PipeWire after rebuild
  systemd.user.services.pipewire.restartIfChanged = true;

  sound.extraConfig = ''
  pcm.!default {
    type hw
    card 0   Your sound card (check with aplay -l)
  }
  ctl.!default {
    type hw
    card 0
  }
'';

    # === 1. Hi-Res Audio (96 kHz default) ===
   services.pipewire = {
   extraConfig.pipewire."99-hires-audio" = {
      "context.properties" = {
        "default.clock.rate" = 96000;
        "default.clock.allowed-rates" = [ 44100 48000 96000 192000 ];
        "default.clock.quantum" = 1024;
        "default.clock.min-quantum" = 32;
        "default.clock.max-quantum" = 2048;
      };
    };

    # === 2. PulseAudio low-latency / less crackling ===
    extraConfig.pipewire-pulse."99-pulse-low-latency" = {
      "pulse.properties" = {
        "pulse.min.quantum" = "1024/48000";
      };
    };
};
  
  # === 3. Battery-Aware Dynamic Rate Switch (48 kHz on battery, 96 kHz on charger) ===
  systemd.user.services.pipewire-rate-switch = {
    description = "Switch PipeWire sample rate on AC/Battery change";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.writeShellScript "pipewire-rate-switch.sh" ''
        #!/usr/bin/env bash
        if grep -q "Discharging" /sys/class/power_supply/BAT0/status 2>/dev/null; then
          pw-metadata -n settings 0 clock.force-rate 48000
          echo "Battery mode → 48 kHz"
        else
          pw-metadata -n settings 0 clock.force-rate 96000
          echo "AC mode → 96 kHz"
        fi
      ''}";
      RemainAfterExit = true;
    };
  };

  # Trigger on power change (plug/unplug)
  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", ATTR{status}=="Discharging", RUN+="${pkgs.systemd}/bin/systemctl --user restart pipewire-rate-switch.service"
    SUBSYSTEM=="power_supply", ATTR{status}=="Charging", RUN+="${pkgs.systemd}/bin/systemctl --user restart pipewire-rate-switch.service"
    SUBSYSTEM=="power_supply", ATTR{online}=="0", RUN+="${pkgs.systemd}/bin/systemctl --user restart pipewire-rate-switch.service"
    SUBSYSTEM=="power_supply", ATTR{online}=="1", RUN+="${pkgs.systemd}/bin/systemctl --user restart pipewire-rate-switch.service"
  '';

   
   # for better wayland portals (screen sharing)
   xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];
      configPackages = [ pkgs.xdg-desktop-portal-hyprland ];

   };
   
   #For bluetooth
   services.blueman.enable = true;

   #polkit (for password prompts in apps)
   security.polkit.enable = true;

  environment.systemPackages = with pkgs; [
      (writeShellScriptBin "nvidia-offload" ''
      export __NV_PRIME_RENDER_OFFLOAD=1
      export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
      export __GLX_VENDOR_LIBRARY_NAME=nvidia
      exec "$@"
    '')

    # Hyprland core (matches your hyprland.conf)
    hyprland hyprcursor hyprpaper swww waybar swaynotificationcenter rofi wl-clipboard grim slurp
    dunst cliphist wlogout networkmanagerapplet brightnessctl pamixer playerctl
    foot wezterm kitty alacritty
    nautilus easyeffects polkit_gnome blueman alsa-utils
                        
    # NVIDIA + gaming
    mangohud gamemode steam lutris wine wineWowPackages.full protonup-ng obs-studio mpv

    # Your CLI/dev tools
    bat eza fd fzf ripgrep yazi fastfetch btop neovim git lazygit curl wget aria2 yt-dlp qbittorrent zathura

    # Fonts + misc
    noto-fonts noto-fonts-color-emoji nerd-fonts.fira-code nerd-fonts.jetbrains-mono nerd-fonts.hack
    firefox ungoogled-chromium code

    # ASUS & utils
    asusctl supergfxctl
  ];

  # ====================== USER & SHELL ======================
  users.users.moon = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "libvirtd" "input" ];
    shell = pkgs.zsh;
  };
  programs.zsh.enable = true;

  # ====================== MISC ======================
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;
  networking.hostName = "SoS";
  networking.networkmanager.enable = true;
  time.timeZone = "Asia/Kolkata";
  system.stateVersion = "25.05";
}
