# IV-ECOSYSTEM-COMMERCIAL-RELEASE-SUPERMACRO-01 — D5
# Validates that Firebase configuration files are present and not placeholder.
#
# Usage:
#   powershell -File scripts\validate_firebase_config.ps1
#   powershell -File scripts\validate_firebase_config.ps1 -ReleaseMode
#
# In CI/release mode (-ReleaseMode), EXITS with code 1 if any config is missing
# or contains placeholder values. In debug mode (default), warnings only.

param(
    [switch]$ReleaseMode
)

$ErrorActionPreference = "Continue"
$repoRoot = Split-Path $PSScriptRoot -Parent

$configs = @(
    @{
        path = "android\app\src\core\google-services.json"
        flavor = "core (Android)"
        requiredField = "package_name"
        expectedValue = "com.insightvalues.core"
    },
    @{
        path = "android\app\src\impact\google-services.json"
        flavor = "impact (Android)"
        requiredField = "package_name"
        expectedValue = "com.insightvalues.impact"
    },
    @{
        path = "android\app\src\quant\google-services.json"
        flavor = "quant (Android)"
        requiredField = "package_name"
        expectedValue = "com.insightvalues.quant"
    },
    @{
        path = "ios\targets\core\GoogleService-Info.plist"
        flavor = "core (iOS)"
        requiredField = "BUNDLE_ID"
        expectedValue = "com.insightvalues.core"
    },
    @{
        path = "ios\targets\impact\GoogleService-Info.plist"
        flavor = "impact (iOS)"
        requiredField = "BUNDLE_ID"
        expectedValue = "com.insightvalues.impact"
    },
    @{
        path = "ios\targets\quant\GoogleService-Info.plist"
        flavor = "quant (iOS)"
        requiredField = "BUNDLE_ID"
        expectedValue = "com.insightvalues.quant"
    }
)

$failures = 0

foreach ($cfg in $configs) {
    $fullPath = Join-Path $repoRoot $cfg.path
    $flavor = $cfg.flavor

    if (-not (Test-Path $fullPath)) {
        Write-Host "[MISSING] $flavor — $($cfg.path) not found. FIREBASE_EXTERNAL_CONFIGURATION_REQUIRED."
        $failures++
        continue
    }

    $content = Get-Content $fullPath -Raw -ErrorAction SilentlyContinue
    if (-not $content) {
        Write-Host "[EMPTY] $flavor — $($cfg.path) is empty."
        $failures++
        continue
    }

    if ($content -match "PLACEHOLDER" -or $content -match "YOUR_" -or $content -match "example\.com") {
        Write-Host "[PLACEHOLDER] $flavor — $($cfg.path) contains placeholder values. Replace with real Firebase config."
        $failures++
        continue
    }

    if ($cfg.path -match "google-services\.json") {
        try {
            $json = $content | ConvertFrom-Json -ErrorAction Stop
            $clientPackage = $json.client[0].client_info.android_client_info.package_name
            if ($clientPackage -ne $cfg.expectedValue) {
                Write-Host "[MISMATCH] $flavor — expected package $($cfg.expectedValue), got $clientPackage"
                $failures++
                continue
            }
        } catch {
            Write-Host "[PARSE_ERROR] $flavor — $($cfg.path): $_"
            $failures++
            continue
        }
    } elseif ($cfg.path -match "GoogleService-Info\.plist") {
        # P2 fix (Codex D): validate iOS bundle ID from plist XML.
        # GoogleService-Info.plist is an Apple XML plist; parse it as XML and
        # find the BUNDLE_ID value in the key/string alternation pattern.
        try {
            [xml]$plist = $content
            # Standard plist format: <dict><key>BUNDLE_ID</key><string>com.x.y</string>...
            $dict = $plist.plist.dict
            $keys = $dict.key
            $vals = $dict.string
            $bundleIdIndex = -1
            for ($i = 0; $i -lt $keys.Count; $i++) {
                if ($keys[$i] -eq "BUNDLE_ID") { $bundleIdIndex = $i; break }
            }
            if ($bundleIdIndex -lt 0) {
                Write-Host "[PARSE_ERROR] $flavor — BUNDLE_ID key not found in $($cfg.path)"
                $failures++
                continue
            }
            $bundleId = $vals[$bundleIdIndex]
            if ($bundleId -ne $cfg.expectedValue) {
                Write-Host "[MISMATCH] $flavor — expected bundle ID $($cfg.expectedValue), got $bundleId"
                $failures++
                continue
            }
        } catch {
            Write-Host "[PARSE_ERROR] $flavor — $($cfg.path): $_"
            $failures++
            continue
        }
    }

    Write-Host "[PASS] $flavor — $($cfg.path) present and valid."
}

Write-Host ""

if ($failures -eq 0) {
    Write-Host "Firebase config validation: ALL PASS"
    exit 0
} else {
    $msg = "Firebase config validation: $failures ISSUE(S) FOUND"
    if ($ReleaseMode) {
        Write-Error "$msg — blocking release build."
        exit 1
    } else {
        Write-Warning "$msg — debug build continues, release will be blocked."
        exit 0
    }
}
