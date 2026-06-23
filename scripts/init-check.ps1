# Init Check Script — Windows (PowerShell)
# Dosya varlik + yapilandirma kontrolu yapar

$Missing = @()
$ProjectName = Split-Path -Leaf (Get-Location)

# CLAUDE.md kontrolu
if (-not (Test-Path "CLAUDE.md")) { $Missing += "CLAUDE.md" }

# CLAUDE.local.md kontrolu
if (-not (Test-Path "CLAUDE.local.md")) {
    $Missing += "CLAUDE.local.md"
} else {
    $content = Get-Content "CLAUDE.local.md" -Raw
    # NOT: Gorev takibi (Plane) OPSIYONELDIR — zorunlu alan degil.
    if ($content -notmatch "Solo") { $Missing += "Solo ID" }
    if ($content -notmatch "Obsidian Folder") { $Missing += "Obsidian Folder" }
}

# Sonuc
if ($Missing.Count -eq 0) {
    Write-Output "INIT_OK|$ProjectName"
} else {
    Write-Output "INIT_MISSING|$ProjectName|$($Missing -join ',')"
}
