# Azure VPN Client Setup (Gov + Commercial)

This guide includes installation and configuration steps for Windows, macOS, and **Linux (Ubuntu 20.04/22.04)**, including safe installation steps for Ubuntu 22.04 where Microsoft’s package depends on `libssl1.1`.

---

## 1. Install the Azure VPN Client

### **Windows**
[`Download`](https://learn.microsoft.com/en-us/azure/vpn-gateway/point-to-site-entra-vpn-client-windows#download)

### **macOS**
[`Download`](https://learn.microsoft.com/azure/vpn-gateway/openvpn-azure-ad-client-mac)

---

## 2. Linux Setup (Ubuntu 20.04 / 22.04)

Microsoft provides an Azure VPN Client package for Linux, but Ubuntu 22.04 requires special handling due to `libssl1.1` removal.

Below are full installation steps.

---

## **Ubuntu Linux — Standard Installation (20.04 Focal / 22.04 Jammy)**

Install Microsoft’s repo and the VPN Client:

```bash
# install curl utility
sudo apt-get install curl

# Install Microsoft's public key
curl -sSl https://packages.microsoft.com/keys/microsoft.asc | sudo tee /etc/apt/trusted.gpg.d/microsoft.asc

# Install the repo list for Ubuntu 20.04
curl https://packages.microsoft.com/config/ubuntu/20.04/prod.list | sudo tee /etc/apt/sources.list.d/microsoft-ubuntu-focal-prod.list

# Install the repo list for Ubuntu 22.04
curl https://packages.microsoft.com/config/ubuntu/22.04/prod.list | sudo tee /etc/apt/sources.list.d/microsoft-ubuntu-jammy-prod.list

sudo apt-get update
```

If installation works normally, run:

```bash
sudo apt-get install microsoft-azurevpnclient
```

---

## **SAFE INSTALLATION STEPS for Ubuntu 22.04 (AMD64)**  
If you get errors about `libssl1.1` not being installable, use this script.  
It temporarily enables **focal-security only for libssl1.1**, installs the client, and cleans up.

```bash
# SAFE INSTALLATION OF AZURE VPN CLIENT ON UBUNTU 22.04 (AMD64)
set -euo pipefail

# Add Microsoft repo (Jammy)
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /usr/share/keyrings/microsoft.gpg >/dev/null

echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/ubuntu/22.04/prod jammy main" | sudo tee /etc/apt/sources.list.d/microsoft-ubuntu-jammy-prod.list >/dev/null

# TEMPORARILY add focal-security ONLY for libssl1.1
echo 'deb [arch=amd64] http://security.ubuntu.com/ubuntu focal-security main' | sudo tee /etc/apt/sources.list.d/focal-security.list >/dev/null

# Pin so only libssl1.1 comes from focal
sudo tee /etc/apt/preferences.d/pin-focal-libssl >/dev/null <<'EOF'
Package: *
Pin: release n=focal
Pin-Priority: -10

Package: libssl1.1
Pin: release n=focal
Pin-Priority: 990
EOF

sudo apt-get update
sudo apt-get install -y libssl1.1 microsoft-azurevpnclient

sudo apt-mark manual libssl1.1

# Cleanup temp repo and pin
sudo rm -f /etc/apt/sources.list.d/focal-security.list
sudo rm -f /etc/apt/preferences.d/pin-focal-libssl
sudo apt-get update

echo "Installed. Cleanup complete."
```

---

## 3. Importing Your VPN Profile (XML)

After installation:

1. Open **Azure VPN Client**
2. Click **Import**
3. Browse to your provided `.xml` config  
4. Sign in with Entra ID and complete MFA

---

## 4. Configuration Downloads

Replace these URLs with your actual blob or repo URLs.

### **Azure Government (hrz)**

| Plane | Download |
|-------|----------|
| Nonprod | [`Download`](azurevpnconfig_np_hrz_vpn.xml) |
| Prod    | [`Download`](azurevpnconfig_pr_hrz_vpn.xml) |

### **Azure Commercial (pub)**

| Plane | Download |
|-------|----------|
| Nonprod | [`Download`](azurevpnconfig_np_pub_vpn.xml) |
| Prod    | [`Download`](azurevpnconfig_pr_pub_vpn___NOTREADY.xml) |

---

## 5. Troubleshooting

### Tenant / Login Issues
Sign out → Sign in again inside the Azure VPN Client.

### DNS Problems
```bash
sudo systemd-resolve --flush-caches   # Linux
ipconfig /flushdns                    # Windows
sudo dscacheutil -flushcache          # macOS
```

### Connection Drops
Re-import your profile or ensure your Entra ID group assignment is correct.

---

End of document.
