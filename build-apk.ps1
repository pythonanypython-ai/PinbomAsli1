$ErrorActionPreference = "Stop"

if (-not (Test-Path ".\gradlew.bat")) {
    throw "Gradle wrapper is missing. Open this project in Android Studio and restore the wrapper before building."
}

# A Release must never be signed with a predictable, auto-generated password.
# Gradle reads these values from keystore.properties or PINBOM_* environment variables.
$requiredKeys = @(
    "PINBOM_STORE_FILE",
    "PINBOM_STORE_PASSWORD",
    "PINBOM_KEY_ALIAS",
    "PINBOM_KEY_PASSWORD"
)
$properties = @{}
$propertiesPath = ".\keystore.properties"
if (Test-Path $propertiesPath) {
    Get-Content $propertiesPath | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]*?)\s*=\s*(.*?)\s*$') {
            $properties[$matches[1].Trim()] = $matches[2].Trim()
        }
    }
}

$missing = @($requiredKeys | Where-Object {
    $envValue = [Environment]::GetEnvironmentVariable($_)
    $propertyValue = $properties[$_]
    [string]::IsNullOrWhiteSpace($envValue) -and [string]::IsNullOrWhiteSpace($propertyValue)
})
if ($missing.Count -gt 0) {
    throw "Release signing is not configured. Create keystore.properties from keystore.properties.example or set all PINBOM_* signing environment variables. Missing: $($missing -join ', ')"
}

$storePath = [Environment]::GetEnvironmentVariable("PINBOM_STORE_FILE")
if ([string]::IsNullOrWhiteSpace($storePath)) {
    $storePath = $properties["PINBOM_STORE_FILE"]
}
if (-not (Test-Path $storePath -PathType Leaf)) {
    throw "Release keystore file was not found: $storePath"
}

.\gradlew.bat :app:assembleRelease :app:bundleRelease --no-daemon --console=plain

$apk = ".\app\build\outputs\apk\release\app-release.apk"
$aab = ".\app\build\outputs\bundle\release\app-release.aab"
if (-not (Test-Path $apk -PathType Leaf)) { throw "Release APK was not generated." }
if (-not (Test-Path $aab -PathType Leaf)) { throw "Release App Bundle was not generated." }

New-Item -ItemType Directory -Force -Path ".\output" | Out-Null
Copy-Item $apk ".\output\pinbom-release.apk" -Force
Copy-Item $aab ".\output\pinbom-release.aab" -Force
Get-FileHash ".\output\pinbom-release.apk", ".\output\pinbom-release.aab" -Algorithm SHA256 |
    Format-Table -AutoSize
Write-Host "Release outputs: output\pinbom-release.apk and output\pinbom-release.aab"
