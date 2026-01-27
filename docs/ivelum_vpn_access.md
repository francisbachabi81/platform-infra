# Quick Start: Connecting to VPN and Accessing the Database

This guide provides simple steps to connect to the Intterra Azure VPN and access the database resource.

---

## 1. Download the Azure VPN Client

Install the official **Azure VPN Client** from Microsoft:

- [`Microsoft Store link`](https://apps.microsoft.com/detail/9np355qt2sqb)
- Or search for **Azure VPN Client** in the Windows Store.

---

## 2. Import the VPN Profile

1. [`Download the VPN configuration file from GitHub`](https://github.com/intterra-io/platform-infra/blob/main/docs/azurevpnconfig_np_hrz_vpn_ivl.xml)
2. Open **Azure VPN Client**.
3. Click **Import**.
4. Select the downloaded `.xml` file.
5. A new VPN profile will appear and be ready to connect.

---

## 3. Sign In Using Entra ID

When connecting for the first time:

- Sign in with your **Intterra Entra ID**  
  *(example: firstinitiallastname@intterragov.onmicrosoft.us)*.
- If required:
  - Reset your password.
  - Configure **2FA** (Microsoft Authenticator).

Once authenticated, your VPN status should show **Connected**.

---

## 4. Add Hosts File Entry

After the VPN is connected:

1. Open **Notepad as Administrator**.
2. Open this file:

```
C:\Windows\System32\drivers\etc\hosts
```

3. Add these entries at the bottom:

```
10.11.3.4 pgflex-hrz-dev-usaz-01.postgres.database.usgovcloudapi.net
10.10.2.4 aks-hrz-np-usaz-01-dns-90wwrukv.privatelink.usgovarizona.cx.aks.containerservice.azure.us
10.10.2.8 internal.dev.horizon.intterra.io
```

4. Save and close Notepad.

This forces your system to route database traffic correctly.

---

## 5. Connect to the PostgreSQL Database

Use your preferred PostgreSQL client (Azure Data Studio, DBeaver, psql, etc.).

Use the following connection details:

- **Host:** pgflex-hrz-dev-usaz-01.postgres.database.usgovcloudapi.net  
- **Port:** 5432  
- **Username:** (provided to you)  
- **Password:** (provided to you)

If VPN is active and the hosts entry is correct, your connection should succeed.

---

## Troubleshooting

### VPN won’t connect  
- Ensure you downloaded the **raw XML file** from GitHub.
- Re-import the profile if needed.

### Database won’t resolve  
- Recheck that `pgflex-hrz-dev-usaz-01.postgres.database.usgovcloudapi.net` exists in your hosts file.
- Ensure you're connected to the VPN.

### Authentication issues  
- Make sure password reset and 2FA setup were completed successfully.

---

If you need assistance, reach out to Francis, Justin or Tom.