# ELMFIRE on Windows — Docker Setup & California Fire Simulation

Run ELMFIRE fire simulations at any California location using **Docker Desktop
for Windows** and the official pre-built ELMFIRE image. No WSL2 configuration
or manual compilation needed.

---

## Prerequisites

1. **Docker Desktop for Windows** — [Download here](https://www.docker.com/products/docker-desktop/)
   - During installation, enable "Use WSL 2 based engine" (default)
   - After install, start Docker Desktop and wait for the engine to show "running"

2. **QGIS for Windows** (free, for viewing outputs) — [Download here](https://qgis.org/en/site/forusers/download.html)

---

## Quick Start — 3 Steps

### 1. Pull the ELMFIRE Docker image

Open **PowerShell** and `cd` into the `elmfire-src\` folder:

```powershell
cd elmfire-src
docker pull ghcr.io/lautenberger/elmfire
```

This is a ~1-2 GB download and only needs to happen once.

### 2. (Optional) Edit weather inputs

Open `elmfire-src\docker_shared_folder\wx.csv` to set wind speed, wind
direction, and fuel moisture per hour. See
`docker_shared_folder\california_locations.md` for column descriptions.

### 3. Run the simulation

```powershell
cd elmfire-src
.\run_docker.ps1
```

To run at a **specific California location**, pass lat/lon directly:

```powershell
.\run_docker.ps1 -Lat 34.080 -Lon -118.780             # Malibu
.\run_docker.ps1 -Lat 39.759 -Lon -121.606             # Paradise (Camp Fire area)
.\run_docker.ps1 -Lat 38.503 -Lon -122.450 -Hours 12   # Napa, 12-hour run
```

---

## California Preset Locations

| Location                          | LAT      | LON        |
|-----------------------------------|----------|------------|
| Merced (Tutorial default)         | 37.440   | -120.281   |
| Napa Valley / Glass Fire 2020     | 38.503   | -122.450   |
| Paradise / Camp Fire 2018         | 39.759   | -121.606   |
| Malibu / Santa Monica Mtns        | 34.080   | -118.780   |
| Lake Tahoe / Caldor Fire 2021     | 38.680   | -120.050   |
| Redding / Carr Fire 2018          | 40.586   | -122.393   |
| Sonoma County / Tubbs Fire 2017   | 38.540   | -122.720   |
| Ventura County / Thomas Fire 2017 | 34.270   | -119.230   |

Full list with fuel descriptions: `elmfire-src\docker_shared_folder\california_locations.md`

---

## Viewing Outputs

After the simulation, outputs appear at:

```
elmfire-src\docker_shared_folder\simulation\outputs\
```

Open in QGIS:
- `hourly_isochrones.shp` — fire perimeters at each hour
- `time_of_arrival*.tif` — raster of when fire reached each cell
- `flame_length*.tif` — peak flame length raster

---

## Folder Structure

```
elmfire-src/                         ← official ELMFIRE repo (cloned from GitHub)
├── Dockerfile                       ← official image definition
├── docker-compose.yml               ← defines container, volumes, env vars
├── run_california.sh                ← simulation script (runs inside container)
├── run_docker.ps1                   ← Windows PowerShell launcher  ← START HERE
└── docker_shared_folder/            ← shared between Windows and container
    ├── wx.csv                       ← EDIT: wind, fuel moisture inputs
    ├── california_locations.md      ← lat/lon reference
    ├── fuel/                        ← cached LANDFIRE tiles (auto-downloaded)
    └── simulation/
        ├── inputs/
        └── outputs/                 ← OUTPUTS appear here
```

---

## Advanced: Interactive Shell

Drop into bash inside the container to explore ELMFIRE tools directly:

```powershell
cd elmfire-src
.\run_docker.ps1 -Shell
```

Inside the container, `docker_shared_folder` is mounted at
`/elmfire/elmfire/docker_shared_folder`.

---

## How It Works

```
Windows PowerShell
  └─> run_docker.ps1
        └─> docker compose run  (ghcr.io/lautenberger/elmfire)
              ├─ fuel_wx_ign.py  ── fetch LANDFIRE fuel/terrain from Cloudfire
              ├─ gdal_calc.py    ── build multiband weather rasters from wx.csv
              ├─ elmfire_2025.x  ── run fire spread simulation (MPI)
              └─> outputs written to docker_shared_folder\ (visible on Windows)
```
