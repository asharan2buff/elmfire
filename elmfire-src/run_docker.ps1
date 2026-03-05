# run_docker.ps1
# Windows PowerShell helper script to run ELMFIRE Tutorial 03 for California
# inside Docker. Run this from the elmfire-src\ directory.
#
# Prerequisites:
#   - Docker Desktop for Windows installed and running
#     Download: https://www.docker.com/products/docker-desktop/
#
# Usage:
#   cd elmfire-src
#   .\run_docker.ps1

param(
    [string]$Lat = "",         # Override center latitude  (e.g. 34.080)
    [string]$Lon = "",         # Override center longitude (e.g. -118.780)
    [string]$Hours = "",       # Override simulation duration in hours (e.g. 12)
    [switch]$Shell             # Drop into interactive bash shell instead of running sim
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$IMAGE = "ghcr.io/lautenberger/elmfire"
$COMPOSE_FILE = Join-Path $PSScriptRoot "docker-compose.yml"

# ── Check Docker is running ───────────────────────────────────────────────────
Write-Host ""
Write-Host "=== ELMFIRE Docker Runner ===" -ForegroundColor Cyan
Write-Host ""

try {
    docker info 2>&1 | Out-Null
} catch {
    Write-Error "Docker is not running. Please start Docker Desktop and try again."
    exit 1
}

# ── Pull image if not present ─────────────────────────────────────────────────
$imageExists = docker images -q $IMAGE 2>&1
if (-not $imageExists) {
    Write-Host "Pulling ELMFIRE image from GitHub Container Registry..." -ForegroundColor Yellow
    Write-Host "  (This is ~1-2 GB and only happens once)" -ForegroundColor Gray
    docker pull $IMAGE
} else {
    Write-Host "ELMFIRE Docker image found locally." -ForegroundColor Green
}

# ── Ensure docker_shared_folder exists ───────────────────────────────────────
$sharedFolder = Join-Path $PSScriptRoot "docker_shared_folder"
if (-not (Test-Path $sharedFolder)) {
    New-Item -ItemType Directory -Path $sharedFolder | Out-Null
}

# ── Copy wx.csv into shared folder if not already there ───────────────────────
$wxDest = Join-Path $sharedFolder "wx.csv"
$wxSrc  = Join-Path $PSScriptRoot "docker_shared_folder\wx.csv"
if (-not (Test-Path $wxDest)) {
    Write-Host "wx.csv not found in docker_shared_folder — copying default..." -ForegroundColor Yellow
    $defaultWx = Join-Path $PSScriptRoot "tutorials\03-real-fuels\wx.csv"
    if (Test-Path $defaultWx) {
        Copy-Item $defaultWx $wxDest
        Write-Host "  Copied: $wxDest" -ForegroundColor Gray
        Write-Host "  Edit this file to change wind/moisture before running!" -ForegroundColor Gray
    }
}

# ── Build the command to run inside the container ─────────────────────────────
# docker-compose.yml sets  entrypoint: bash
# so:  docker compose run elmfire            → bash (interactive shell)
#      docker compose run elmfire -c "cmd"   → bash -c "cmd"

Push-Location $PSScriptRoot
try {
    if ($Shell) {
        Write-Host "Dropping into interactive bash shell inside the container..." -ForegroundColor Yellow
        Write-Host "  Run simulation with: bash /elmfire/elmfire/run_california.sh" -ForegroundColor Gray
        Write-Host ""
        docker compose run --rm elmfire
    } else {
        $script = "/elmfire/elmfire/run_california.sh"
        $overrides = ""
        if ($Lat -ne "") {
            $overrides += "sed -i 's/^CENTER_LAT=.*/CENTER_LAT=${Lat}/' $script; "
        }
        if ($Lon -ne "") {
            $overrides += "sed -i 's/^CENTER_LON=.*/CENTER_LON=${Lon}/' $script; "
        }
        if ($Hours -ne "") {
            $tstop = [int]$Hours * 3600
            $overrides += "sed -i 's/^SIMULATION_TSTOP=.*/SIMULATION_TSTOP=${tstop}.0/' $script; "
        }
        Write-Host "Starting ELMFIRE simulation..." -ForegroundColor Yellow
        if ($Lat -ne "") { Write-Host "  Lat: $Lat  Lon: $Lon" -ForegroundColor Gray }
        Write-Host ""
        docker compose run --rm elmfire -c "${overrides}bash $script"
    }
} finally {
    Pop-Location
}

# ── Show output location ──────────────────────────────────────────────────────
if (-not $Shell) {
    $outputPath = Join-Path $sharedFolder "simulation\outputs"
    Write-Host ""
    Write-Host "=== Done! ===" -ForegroundColor Green
    Write-Host "Outputs are at:" -ForegroundColor White
    Write-Host "  $outputPath" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Open hourly_isochrones.shp or time_of_arrival*.tif in QGIS." -ForegroundColor White
}
