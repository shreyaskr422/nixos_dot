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

  # ====================== GRAPHICS - NVIDIA + AMD HYBRID (your exact hardware) ======================
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    open = true;                    # matches your nvidia-open-dkms
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    nvidiaSettings = true;
    prime = {
      offload.enable = true;        # best battery + performance (Hybrid style)
      offload.enableOffloadCmd = true;
      amdgpuBusId = "PCI:106:0:0";  # your AMD iGPU (6a hex = 106 decimal)
      nvidiaBusId   = "PCI:1:0:0";  # your RTX 5050
    };
  };

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

  # ====================== SYSTEM PACKAGES (all your important ones) ======================
   
   # for better wayland portals (screen sharing)
   xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];
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
    foot wezterm kitty alacritty   # you had st, but these are better on NixOS
    nautilus xfce.thunar easyeffects polkit_gnome blueman
                        
    # NVIDIA + gaming
    mangohud gamemode steam lutris wine wineWowPackages.full protonup-ng obs-studio mpv

    # Your CLI/dev tools
    bat eza fd fzf ripgrep yazi fastfetch btop neovim git lazygit curl wget aria2 yt-dlp qbittorrent zathura

    # Fonts + misc
    noto-fonts noto-fonts-color-emoji nerd-fonts.fira-code nerd-fonts.jetbrains-mono nerd-fonts.hack
    firefox ungoogled-chromium vscode obsidian

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
