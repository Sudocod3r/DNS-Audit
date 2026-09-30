from pathlib import Path

path = Path("/mnt/data/README.md")

readme = r"""# DNS Audit PowerShell Script

<p align="center">
  <strong>Reusable PowerShell DNS auditing for MSPs, sysadmins, and Microsoft 365 environments.</strong>
</p>

<p align="center">
  <img alt="PowerShell" src="https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white">
  <img alt="Platform" src="https://img.shields.io/badge/Platform-Windows-0078D6?logo=windows&logoColor=white">
  <img alt="DNS" src="https://img.shields.io/badge/DNS-Read--Only-success">
  <img alt="Microsoft 365" src="https://img.shields.io/badge/Microsoft%20365-Aware-742774?logo=microsoft">
</p>

---

## Overview

**DNS Audit** is a reusable PowerShell script that prompts for a domain, performs a structured public DNS review, and writes the results to a timestamped text report.

It is designed for:

- Post-migration DNS reviews
- Microsoft 365 mail-flow validation
- MSP troubleshooting
- DNS cleanup projects
- SPF / DKIM / DMARC verification
- Checking for stale third-party mail services
- Comparing public DNS resolver results

> [!NOTE]
> The script is **read-only**. It does not modify DNS records, Microsoft 365, or Exchange Online.

---

## Features

The script checks:

| Area | Checks |
|---|---|
| Authoritative DNS | NS records |
| Website | A, AAAA, and `www` resolution |
| Email | MX records |
| SPF | TXT records and duplicate SPF detection |
| Autodiscover | Microsoft 365 Autodiscover CNAME |
| DKIM | Selector 1 and Selector 2 |
| DMARC | `_dmarc` TXT record |
| CNAMEs | Common service aliases |
| Microsoft 365 | Enrollment, registration, SIP, Lync/Teams-related records |
| SRV | Microsoft 365 / Teams SRV records |
| Resolver comparison | Google DNS and Cloudflare DNS |
| CNAME chains | Full DNS resolution where applicable |

The report also includes lightweight detection for common mail providers such as:

- Microsoft 365 / Exchange Online
- AppRiver / Zix / EdgePilot
- Mimecast
- Proofpoint

---

## Example Workflow

```text
Run script
   │
   ▼
Enter domain
   │
   ▼
Query public DNS
   │
   ├── NS
   ├── A / AAAA
   ├── MX
   ├── TXT / SPF
   ├── CNAME
   ├── DKIM
   ├── DMARC
   └── SRV
   │
   ▼
Compare public resolvers
   │
   ▼
Generate timestamped report
```

---

## Requirements

- Windows 10, Windows 11, or Windows Server
- Windows PowerShell 5.1 or PowerShell 7
- Built-in `DnsClient` module
- Internet access for public DNS queries

No third-party PowerShell modules are required.

Verify that `Resolve-DnsName` is available:

```powershell
Get-Command Resolve-DnsName
```

You can also confirm the built-in DNS module is present:

```powershell
Get-Module -ListAvailable DnsClient
```

---

## Optional: Install PowerShell 7

PowerShell 7 is not required, but it can be installed with:

```powershell
winget install --id Microsoft.PowerShell --source winget --accept-source-agreements --accept-package-agreements
```

Verify:

```powershell
pwsh --version
```

---

## Usage

Save the script as:

```text
DNS-Audit.ps1
```

### Windows PowerShell

```powershell
powershell.exe -ExecutionPolicy Bypass -File "D:\DNS-Audit.ps1"
```

### PowerShell 7

```powershell
pwsh -ExecutionPolicy Bypass -File "D:\DNS-Audit.ps1"
```

The script prompts for a domain:

```text
Enter the domain to audit (example: contoso.com):
```

Example:

```text
hawkvalveinc.com
```

Do not include `https://`.

---

## Report Output

Reports are automatically saved to:

```text
Desktop\DNS-Audits
```

Example filename:

```text
DNS-Audit_hawkvalveinc.com_2026-09-30_104618.txt
```

This makes it easy to keep historical DNS audits and compare changes over time.

---

## Report Structure

Generated reports are organized into sections:

```text
1. AUTHORITATIVE NAMESERVERS
2. ROOT DOMAIN RESOLUTION
3. WEBSITE / WWW
4. MAIL EXCHANGE (MX)
5. TXT AND SPF RECORDS
6. AUTODISCOVER
7. MICROSOFT 365 DKIM
8. DMARC
9. MICROSOFT 365 / COMMON CNAME RECORDS
10. CNAME / FULL RESOLUTION CHAINS
11. MICROSOFT 365 / TEAMS SRV RECORDS
12. PUBLIC DNS SERVER COMPARISON
13. AUDIT NOTES
```

---

## What to Review

Use the report to confirm:

- [ ] Authoritative nameservers belong to the expected DNS provider
- [ ] Root-domain records point to the correct website or proxy service
- [ ] `www` resolves to the intended destination
- [ ] MX records point to the current mail platform
- [ ] Legacy mail-filtering providers are no longer present
- [ ] Only one SPF record exists
- [ ] SPF contains only currently authorized senders
- [ ] Autodiscover points to the expected Microsoft 365 service
- [ ] DKIM selectors are published and resolve correctly
- [ ] DMARC is present and configured with the intended policy
- [ ] CNAMEs do not reference retired services
- [ ] Public resolver results are consistent

---

## Microsoft 365 Checks

For Microsoft 365 environments, the script checks records such as:

```text
autodiscover.example.com
selector1._domainkey.example.com
selector2._domainkey.example.com
enterpriseenrollment.example.com
enterpriseregistration.example.com
lyncdiscover.example.com
sip.example.com
```

It also checks common Microsoft-related SRV records.

> [!IMPORTANT]
> DNS presence alone does not prove that a Microsoft 365 feature is enabled.
>
> For example, DKIM CNAMEs may exist while DKIM is disabled or misconfigured in Exchange Online. Always verify service-side configuration when needed.

---

## SPF Review

The script identifies SPF records beginning with:

```text
v=spf1
```

It also warns if multiple SPF records are found.

A Microsoft 365 SPF record commonly contains:

```text
include:spf.protection.outlook.com
```

The script can also flag references associated with older mail-filtering platforms.

> [!CAUTION]
> Do not remove an unfamiliar SPF entry simply because you do not recognize it.

Before removing an IP, include, or hostname, verify whether it is still used by:

- Printers or scanners
- Websites
- SMTP relays
- Line-of-business applications
- Google Workspace
- Marketing platforms
- Security gateways
- SaaS applications
- Legacy systems still sending as the domain

---

## Example Findings

A healthy Microsoft 365 environment may show:

```text
MX:
example-com.mail.protection.outlook.com

Autodiscover:
autodiscover.example.com
    -> autodiscover.outlook.com

SPF:
v=spf1 include:spf.protection.outlook.com -all

DKIM:
selector1._domainkey.example.com
    -> Microsoft 365 DKIM target

selector2._domainkey.example.com
    -> Microsoft 365 DKIM target
```

The script does not automatically assume every non-Microsoft record is wrong. It highlights items for further review.

---

## Security

The script performs read-only DNS queries.

It does **not**:

- Modify DNS records
- Change Microsoft 365 settings
- Connect to Exchange Online
- Store credentials
- Require API keys
- Require DNS-provider credentials

This makes it safe to use as an initial discovery and audit tool.

---

## Limitations

DNS data can tell you **what is published**, but not always **why it exists**.

For example:

- An SPF IP may belong to an active application
- A CNAME may support a legacy system that is still required
- DKIM records may exist while tenant-side DKIM is disabled
- A DMARC policy may intentionally remain in monitoring mode
- Public DNS can be correct while application configuration is not

Always validate uncertain records before removing or changing them.

---

## Recommended Use Cases

This script is useful for:

- Microsoft 365 migrations
- Email-delivery troubleshooting
- Post-recovery DNS validation
- DNS-provider migrations
- AppRiver / Zix / EdgePilot cleanup
- MSP documentation
- Client environment audits
- SPF cleanup
- DKIM / DMARC reviews
- Website DNS troubleshooting

---

## Suggested Repository Layout

```text
DNS-Audit/
│
├── DNS-Audit.ps1
├── README.md
└── examples/
    └── sample-report.txt
```

---

## Contributing

Suggestions and improvements are welcome.

Useful future enhancements could include:

- CSV or HTML report output
- Automatic SPF lookup-count analysis
- DNSSEC checks
- MTA-STS checks
- TLS-RPT checks
- CAA record validation
- Exchange Online integration
- Automatic stale-record detection
- Side-by-side historical report comparison

---

## Disclaimer

This tool is intended for administrative and troubleshooting use.

Review findings before making DNS changes. A record that appears unused may still be required by an application, device, third-party service, or legacy workflow.

---

## License

Use and modify this script as needed for internal administration, troubleshooting, or MSP workflows.
"""

path.write_text(readme, encoding="utf-8")
print(f"Updated: {path}")
