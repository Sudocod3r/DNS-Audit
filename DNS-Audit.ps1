# ============================================================
# DNS Audit Script
# Reusable Domain DNS / Microsoft 365 Audit
# ============================================================

Clear-Host

# ------------------------------------------------------------
# Ask for domain
# ------------------------------------------------------------

$Domain = Read-Host "Enter the domain to audit (example: contoso.com)"

# Clean up input
$Domain = $Domain.Trim().ToLower()
$Domain = $Domain -replace "^https?://", ""
$Domain = $Domain.TrimEnd("/")

if ([string]::IsNullOrWhiteSpace($Domain)) {
    Write-Host "No domain entered. Exiting." -ForegroundColor Red
    exit
}

# ------------------------------------------------------------
# Create report location
# ------------------------------------------------------------

$Desktop = [Environment]::GetFolderPath("Desktop")
$ReportFolder = Join-Path $Desktop "DNS-Audits"

if (!(Test-Path $ReportFolder)) {
    New-Item -ItemType Directory -Path $ReportFolder | Out-Null
}

$Timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
$ReportFile = Join-Path $ReportFolder "DNS-Audit_$($Domain)_$Timestamp.txt"

# ------------------------------------------------------------
# Helper functions
# ------------------------------------------------------------

function Add-ReportLine {
    param(
        [string]$Text = ""
    )

    Add-Content -Path $ReportFile -Value $Text
}

function Add-Section {
    param(
        [string]$Title
    )

    Add-ReportLine ""
    Add-ReportLine "======================================================================"
    Add-ReportLine " $Title"
    Add-ReportLine "======================================================================"
}

function Test-DNSRecord {
    param(
        [string]$Name,
        [string]$Type
    )

    Add-ReportLine ""
    Add-ReportLine "[$Type] $Name"
    Add-ReportLine "----------------------------------------------------------------------"

    try {

        $Results = Resolve-DnsName `
            -Name $Name `
            -Type $Type `
            -DnsOnly `
            -ErrorAction Stop

        $Output = $Results |
            Select-Object Name, Type, TTL, IPAddress, NameHost, NameExchange, Preference, Strings |
            Format-Table -AutoSize |
            Out-String -Width 300

        Add-ReportLine $Output.TrimEnd()

        return $Results
    }
    catch {

        Add-ReportLine "NOT FOUND / LOOKUP FAILED"

        return $null
    }
}

# ------------------------------------------------------------
# Report header
# ------------------------------------------------------------

@"
======================================================================
                         DNS AUDIT REPORT
======================================================================

Domain:        $Domain
Audit Date:    $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Computer:      $env:COMPUTERNAME
Run By:        $env:USERNAME

======================================================================
"@ | Set-Content -Path $ReportFile


Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " DNS AUDIT: $Domain" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Generating report..." -ForegroundColor Yellow


# ============================================================
# AUTHORITATIVE NAMESERVERS
# ============================================================

Add-Section "1. AUTHORITATIVE NAMESERVERS"

Test-DNSRecord -Name $Domain -Type NS | Out-Null


# ============================================================
# ROOT DOMAIN
# ============================================================

Add-Section "2. ROOT DOMAIN RESOLUTION"

Test-DNSRecord -Name $Domain -Type A | Out-Null

Test-DNSRecord -Name $Domain -Type AAAA | Out-Null


# ============================================================
# WWW / WEBSITE
# ============================================================

Add-Section "3. WEBSITE / WWW"

Test-DNSRecord -Name "www.$Domain" -Type CNAME | Out-Null

Test-DNSRecord -Name "www.$Domain" -Type A | Out-Null

Test-DNSRecord -Name "www.$Domain" -Type AAAA | Out-Null


# ============================================================
# MAIL EXCHANGE
# ============================================================

Add-Section "4. MAIL EXCHANGE (MX)"

$MXResults = Test-DNSRecord -Name $Domain -Type MX


# ------------------------------------------------------------
# Simple MX provider detection
# ------------------------------------------------------------

if ($MXResults) {

    Add-ReportLine ""
    Add-ReportLine "MX PROVIDER ANALYSIS"
    Add-ReportLine "----------------------------------------------------------------------"

    foreach ($MX in $MXResults) {

        $Target = $MX.NameExchange

        if ($Target -match "mail\.protection\.outlook\.com") {

            Add-ReportLine "[OK] Microsoft 365 / Exchange Online detected:"
            Add-ReportLine "     $Target"

        }
        elseif ($Target -match "appriver|edgepilot|zix") {

            Add-ReportLine "[REVIEW] AppRiver / Zix related MX detected:"
            Add-ReportLine "         $Target"

        }
        elseif ($Target -match "mimecast") {

            Add-ReportLine "[INFO] Mimecast mail filtering detected:"
            Add-ReportLine "       $Target"

        }
        elseif ($Target -match "pphosted|proofpoint") {

            Add-ReportLine "[INFO] Proofpoint mail filtering detected:"
            Add-ReportLine "       $Target"

        }
        else {

            Add-ReportLine "[INFO] Other MX provider:"
            Add-ReportLine "       $Target"

        }
    }
}


# ============================================================
# TXT / SPF
# ============================================================

Add-Section "5. TXT AND SPF RECORDS"

try {

    $TXTResults = Resolve-DnsName `
        -Name $Domain `
        -Type TXT `
        -DnsOnly `
        -ErrorAction Stop

    $SPFCount = 0

    foreach ($Record in $TXTResults) {

        if ($Record.Strings) {

            $Text = $Record.Strings -join ""

            if ($Text -match "^v=spf1") {

                $SPFCount++

                Add-ReportLine ""
                Add-ReportLine "SPF RECORD:"
                Add-ReportLine $Text

                if ($Text -match "spf\.protection\.outlook\.com") {
                    Add-ReportLine "[OK] Microsoft 365 SPF include detected."
                }

                if ($Text -match "appriver|edgepilot|zix") {
                    Add-ReportLine "[REVIEW] AppRiver/Zix reference detected in SPF."
                }

            }
            else {

                Add-ReportLine ""
                Add-ReportLine "TXT:"
                Add-ReportLine $Text

            }
        }
    }

    Add-ReportLine ""

    if ($SPFCount -eq 0) {

        Add-ReportLine "[WARNING] No SPF record detected."

    }
    elseif ($SPFCount -gt 1) {

        Add-ReportLine "[WARNING] MULTIPLE SPF RECORDS DETECTED!"
        Add-ReportLine "There should normally only be one SPF record."

    }
    else {

        Add-ReportLine "[OK] One SPF record detected."

    }

}
catch {

    Add-ReportLine "No TXT records found or lookup failed."

}


# ============================================================
# AUTODISCOVER
# ============================================================

Add-Section "6. AUTODISCOVER"

$AutoDiscover = Test-DNSRecord `
    -Name "autodiscover.$Domain" `
    -Type CNAME

if ($AutoDiscover) {

    foreach ($Record in $AutoDiscover) {

        if ($Record.NameHost -match "autodiscover\.outlook\.com") {

            Add-ReportLine ""
            Add-ReportLine "[OK] Autodiscover points to Microsoft 365."

        }
    }
}


# ============================================================
# DKIM
# ============================================================

Add-Section "7. MICROSOFT 365 DKIM"

Test-DNSRecord `
    -Name "selector1._domainkey.$Domain" `
    -Type CNAME |
    Out-Null

Test-DNSRecord `
    -Name "selector2._domainkey.$Domain" `
    -Type CNAME |
    Out-Null


# ============================================================
# DMARC
# ============================================================

Add-Section "8. DMARC"

Test-DNSRecord `
    -Name "_dmarc.$Domain" `
    -Type TXT |
    Out-Null


# ============================================================
# MICROSOFT 365 COMMON CNAMES
# ============================================================

Add-Section "9. MICROSOFT 365 / COMMON CNAME RECORDS"

$CNAMERecords = @(
    "autodiscover",
    "enterpriseenrollment",
    "enterpriseregistration",
    "lyncdiscover",
    "sip",
    "www",
    "mail",
    "smtp",
    "webmail",
    "remote",
    "portal",
    "owa",
    "vpn"
)

foreach ($Prefix in $CNAMERecords) {

    $Hostname = "$Prefix.$Domain"

    try {

        $Results = Resolve-DnsName `
            -Name $Hostname `
            -Type CNAME `
            -DnsOnly `
            -ErrorAction Stop

        Add-ReportLine ""
        Add-ReportLine "$Hostname"

        foreach ($Result in $Results) {

            Add-ReportLine "    CNAME -> $($Result.NameHost)"

        }

    }
    catch {

        # Don't clutter report with missing optional CNAMES

    }
}


# ============================================================
# CNAME RESOLUTION CHAINS
# ============================================================

Add-Section "10. CNAME / FULL RESOLUTION CHAINS"

$HostsToTrace = @(
    "www.$Domain",
    "autodiscover.$Domain",
    "selector1._domainkey.$Domain",
    "selector2._domainkey.$Domain"
)

foreach ($Hostname in $HostsToTrace) {

    Add-ReportLine ""
    Add-ReportLine "Resolving: $Hostname"
    Add-ReportLine "----------------------------------------------------------------------"

    try {

        $Results = Resolve-DnsName `
            -Name $Hostname `
            -DnsOnly `
            -ErrorAction Stop

        $Output = $Results |
            Select-Object Name, Type, TTL, NameHost, IPAddress |
            Format-Table -AutoSize |
            Out-String -Width 300

        Add-ReportLine $Output.TrimEnd()

    }
    catch {

        Add-ReportLine "Unable to resolve."

    }
}


# ============================================================
# SRV RECORDS
# ============================================================

Add-Section "11. MICROSOFT 365 / TEAMS SRV RECORDS"

$SRVRecords = @(
    "_sip._tls.$Domain",
    "_sipfederationtls._tcp.$Domain"
)

foreach ($SRV in $SRVRecords) {

    Test-DNSRecord `
        -Name $SRV `
        -Type SRV |
        Out-Null

}


# ============================================================
# PUBLIC DNS CHECKS
# ============================================================

Add-Section "12. PUBLIC DNS SERVER COMPARISON"

$PublicDNSServers = @{
    "Google"     = "8.8.8.8"
    "Cloudflare" = "1.1.1.1"
}

foreach ($Provider in $PublicDNSServers.Keys) {

    $DNSServer = $PublicDNSServers[$Provider]

    Add-ReportLine ""
    Add-ReportLine "$Provider DNS ($DNSServer)"
    Add-ReportLine "----------------------------------------------------------------------"

    try {

        $Result = Resolve-DnsName `
            -Name $Domain `
            -Type A `
            -Server $DNSServer `
            -DnsOnly `
            -ErrorAction Stop

        foreach ($Record in $Result) {

            if ($Record.IPAddress) {
                Add-ReportLine "$Domain -> $($Record.IPAddress)"
            }

        }

    }
    catch {

        Add-ReportLine "Lookup failed."

    }
}


# ============================================================
# FINAL SUMMARY
# ============================================================

Add-Section "13. AUDIT NOTES"

Add-ReportLine @"

Review the following:

[ ] Authoritative nameservers point to the expected DNS provider.

[ ] Root domain A record points to the correct web server/provider.

[ ] WWW CNAME/A record points to the correct website.

[ ] MX records point to the currently used mail provider.

[ ] No legacy AppRiver/Zix/EdgePilot MX records remain unless required.

[ ] Only ONE SPF record exists.

[ ] SPF contains all currently authorized senders.

[ ] Old email providers have been removed from SPF.

[ ] Autodiscover points to the correct Microsoft 365 service.

[ ] DKIM selector1 and selector2 resolve correctly.

[ ] DMARC exists and has the intended policy.

[ ] No stale CNAME records point to retired services.

[ ] Public DNS resolution is consistent.

======================================================================
                         END OF REPORT
======================================================================
"@

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host " DNS AUDIT COMPLETE" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Domain: $Domain"
Write-Host ""
Write-Host "Report saved to:" -ForegroundColor Yellow
Write-Host $ReportFile -ForegroundColor Cyan
Write-Host ""

# Open report automatically
Start-Process notepad.exe $ReportFile