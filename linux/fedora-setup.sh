#!/usr/bin/env bash

# Fedora system setup: updates, firmware, rpm fusion, codecs and the nvidia
# driver. Things that aren't a plain package in linux/packages.txt.
# Run by linux.sh before the package list, or on its own from the repo.
# Safe to re-run: every step skips what's already done.
#
# Set LOCAL_RTC=1 when dual-booting Windows, so both agree on the clock.

set -euo pipefail

print_msg() {
    printf "\n\033[1;34m%s\033[0m\n" "$1"
}

print_info() {
    printf "    %s\n" "$1"
}

if [ "$EUID" -eq 0 ]; then
    echo "Run fedora-setup.sh as your normal user; it uses sudo where needed." >&2
    exit 1
fi

# Ask for sudo once and keep it alive until this script exits
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2> /dev/null &

FEDORA_VER=$(rpm -E %fedora)

# 1. dnf: parallel downloads, default to yes
print_msg "Tuning dnf..."
rpm -q dnf5-plugins &> /dev/null || sudo dnf install -y dnf5-plugins
sudo dnf config-manager setopt max_parallel_downloads=10 defaultyes=True

# 2. rpm fusion (codecs, nvidia driver, steam) and openh264
if ! rpm -q rpmfusion-free-release rpmfusion-nonfree-release &> /dev/null; then
    print_msg "Enabling RPM Fusion..."
    sudo dnf install -y \
        "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$FEDORA_VER.noarch.rpm" \
        "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$FEDORA_VER.noarch.rpm"
fi
sudo dnf config-manager setopt fedora-cisco-openh264.enabled=1

# 3. Full upgrade
print_msg "Upgrading the system..."
sudo dnf upgrade -y --refresh

# 4. Firmware: UEFI/SSD updates via fwupd, plus CPU microcode and Wi-Fi/BT firmware
print_msg "Updating firmware..."
sudo dnf install -y fwupd linux-firmware amd-ucode-firmware mt7xxx-firmware
sudo fwupdmgr refresh --force || true
sudo fwupdmgr update -y || print_info "no firmware updates applied"

# 5. Multimedia codecs (full ffmpeg instead of ffmpeg-free)
print_msg "Installing multimedia codecs..."
if rpm -q ffmpeg-free &> /dev/null; then
    sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing
fi
sudo dnf update -y @multimedia --setopt=install_weak_deps=False --exclude=PackageKit-gstreamer-plugin
sudo dnf install -y gstreamer1-plugins-bad-freeworld gstreamer1-plugins-ugly \
    gstreamer1-plugin-openh264 mozilla-openh264

# 6. NVIDIA driver, only when an NVIDIA GPU is present
if lspci | grep -iE 'vga|3d' | grep -qi nvidia; then
    print_msg "NVIDIA GPU found, installing the driver..."
    sudo dnf install -y kernel-devel kernel-headers akmods mokutil openssl

    # Secure Boot: sign the module with a local key, enrolled on next boot
    if mokutil --sb-state 2> /dev/null | grep -q "SecureBoot enabled" \
        && [ ! -f /etc/pki/akmods/certs/public_key.der ]; then
        print_msg "Secure Boot is on: enrolling an akmods signing key..."
        sudo kmodgenca -a
        print_info "pick a one-time password; on next boot choose"
        print_info "Enroll MOK -> Continue -> enter that password"
        sudo mokutil --import /etc/pki/akmods/certs/public_key.der
    fi

    # Driver, CUDA, NVDEC video decode, 32-bit libs for Steam
    sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-power \
        xorg-x11-drv-nvidia-cuda xorg-x11-drv-nvidia-cuda-libs \
        xorg-x11-drv-nvidia-libs.i686 nvidia-vaapi-driver libva-utils

    # Keep video memory across suspend (Wayland)
    sudo tee /etc/modprobe.d/nvidia-power.conf > /dev/null <<'EOF'
options nvidia NVreg_PreserveVideoMemoryAllocations=1 NVreg_TemporaryFilePath=/var/tmp
EOF
    sudo systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service

    # Hardware video decode in Firefox and others
    sudo mkdir -p /etc/environment.d
    sudo tee /etc/environment.d/90-nvidia-vaapi.conf > /dev/null <<'EOF'
LIBVA_DRIVER_NAME=nvidia
NVD_BACKEND=direct
EOF

    # Build for the newest installed kernel: after the upgrade above that's
    # the one the next boot runs, and kernel-devel matches it, not
    # necessarily the kernel running now.
    KVER=$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-core | sort -V | tail -n1)
    if ! modinfo -k "$KVER" -F version nvidia &> /dev/null; then
        print_msg "Building the NVIDIA kernel module for $KVER (a few minutes)..."
        sudo akmods --force --kernels "$KVER" || print_info "build failed; akmods tries again on next boot"
        sudo dracut --force --kver "$KVER"
    fi
    if modinfo -k "$KVER" -F version nvidia &> /dev/null; then
        print_info "nvidia module $(modinfo -k "$KVER" -F version nvidia) ready for $KVER"
    else
        print_info "module not built yet; it builds on next boot (check: modinfo -F version nvidia)"
    fi
else
    print_msg "No NVIDIA GPU, skipping the driver..."
fi

# 7. Hardware monitoring: sensors, SSD trim, drive health
print_msg "Enabling sensors, fstrim and smartd..."
sudo dnf install -y lm_sensors smartmontools nvme-cli
sudo sensors-detect --auto > /dev/null 2>&1 || true
sudo systemctl enable --now fstrim.timer smartd.service

# 8. Desktops rarely need to wait for the network to boot
sudo systemctl disable NetworkManager-wait-online.service 2> /dev/null || true

# 9. Dual-boot clock
if [ "${LOCAL_RTC:-0}" -eq 1 ]; then
    sudo timedatectl set-local-rtc 1 --adjust-system-clock
fi

print_msg "System setup done. Reboot, then check: nvidia-smi, vainfo"
