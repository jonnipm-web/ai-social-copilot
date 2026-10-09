# IV-ECOSYSTEM-COMMERCIAL-RELEASE-SUPERMACRO-01 — D3
# Verifies that assetlinks.json is correctly deployed at
# https://insightvalues.com/.well-known/assetlinks.json
#
# Usage (after deploying assetlinks.json):
#   powershell -File scripts\verify_assetlinks.ps1
#
# Optional: provide SHA256 fingerprints to verify they appear in the response.
#   powershell -File scripts\verify_assetlinks.ps1 `
#     -CoreSHA "AA:BB:..." `
#     -ImpactSHA "CC:DD:..." `
#     -QuantSHA "EE:FF:..."
#
# Prerequisites: the endpoint must be live before running this script.

param(
    [string]$Url = "https://insightvalues.com/.well-known/assetlinks.json",
    [string]$CoreSHA = "",
    [string]$ImpactSHA = "",
    [string]$QuantSHA = ""
)

$ErrorActionPreference = "Stop"

Write-Host "[assetlinks] Verifying $Url ..."

try {
    $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 15
} catch {
    Write-Error "[FAIL] Could not reach $Url : $_"
    exit 1
}

if ($response.StatusCode -ne 200) {
    Write-Error "[FAIL] HTTP $($response.StatusCode) from $Url"
    exit 1
}

$contentType = $response.Headers["Content-Type"]
if ($contentType -notmatch "application/json") {
    Write-Warning "[WARN] Content-Type is '$contentType' (expected application/json)"
}

try {
    $json = $response.Content | ConvertFrom-Json
} catch {
    Write-Error "[FAIL] Response is not valid JSON: $_"
    exit 1
}

$requiredPackages = @(
    "com.insightvalues.core",
    "com.insightvalues.impact",
    "com.insightvalues.quant"
)

$shas = @{
    "com.insightvalues.core"   = $CoreSHA
    "com.insightvalues.impact" = $ImpactSHA
    "com.insightvalues.quant"  = $QuantSHA
}

$allPass = $true

foreach ($pkg in $requiredPackages) {
    $entry = $json | Where-Object {
        $_.target.package_name -eq $pkg
    }
    if (-not $entry) {
        Write-Host "[FAIL] Missing entry for $pkg"
        $allPass = $false
        continue
    }

    $sha = $shas[$pkg]
    if ($sha -and $sha -ne "") {
        $fingerprints = $entry.target.sha256_cert_fingerprints
        if ($fingerprints -contains $sha) {
            Write-Host "[PASS] $pkg — fingerprint verified"
        } else {
            Write-Host "[FAIL] $pkg — expected fingerprint '$sha' not found in $fingerprints"
            $allPass = $false
        }
    } else {
        Write-Host "[PASS] $pkg — entry exists (no SHA provided to verify)"
    }
}

if ($allPass) {
    Write-Host ""
    Write-Host "[assetlinks] ALL CHECKS PASS — assetlinks.json is correctly deployed."
    exit 0
} else {
    Write-Host ""
    Write-Host "[assetlinks] FAILURES DETECTED — check output above."
    exit 1
}
