# California Fire Locations — Quick Reference

Edit the `CENTER_LAT` / `CENTER_LON` values at the top of
`run_california.sh`, or pass them directly via PowerShell:

```powershell
.\run_docker.ps1 -Lat 34.080 -Lon -118.780 -Hours 6
```

---

## Preset Locations

| Location                           | LAT      | LON        | Fuel type / notes                         |
|------------------------------------|----------|------------|-------------------------------------------|
| Merced area (official Tutorial 03) | 37.440   | -120.281   | Central Valley edge, mixed grass/shrub    |
| Napa Valley / Glass Fire 2020      | 38.503   | -122.450   | Chaparral, oak woodland                   |
| Paradise, CA / Camp Fire 2018      | 39.759   | -121.606   | Sierra Nevada foothills, heavy timber     |
| Malibu / Santa Monica Mtns         | 34.080   | -118.780   | Dense chaparral, marine layer influence   |
| Lake Tahoe / Caldor Fire 2021      | 38.680   | -120.050   | Sierra Nevada, heavy timber/mixed         |
| Redding / Carr Fire 2018           | 40.586   | -122.393   | Northern CA, dry grass & chaparral        |
| Sonoma County / Tubbs Fire 2017    | 38.540   | -122.720   | Oak woodland, chaparral                   |
| Ventura County / Thomas Fire 2017  | 34.270   | -119.230   | Chaparral, Sundowner winds                |
| Big Sur / Coastal Range             | 36.200   | -121.600   | Steep terrain, chaparral/mixed conifer    |
| San Bernardino Mtns                | 34.190   | -117.310   | Dense timber, Santa Ana wind corridor     |

---

## Weather (wx.csv) — Column Reference

| Column | Meaning                     | Typical range |
|--------|-----------------------------|---------------|
| ws     | Wind speed (mph)            | 5–40          |
| wd     | Wind direction (° from N)   | 0–360         |
| m1     | 1-hr dead fuel moisture (%) | 2–8           |
| m10    | 10-hr dead fuel moisture (%)| 3–10          |
| m100   | 100-hr fuel moisture (%)    | 4–15          |
| lh     | Live herbaceous moisture (%)| 30–150        |
| lw     | Live woody moisture (%)     | 60–160        |

**Wind direction convention:**
- 0° = wind FROM north (fire spreads south)
- 90° = wind FROM east (fire spreads west) — Santa Ana direction
- 270° = wind FROM west (fire spreads east)

**Each row = 1 hour** (DT_METEOROLOGY = 3600 s).

---

## Simulation duration

```powershell
.\run_docker.ps1 -Hours 24    # 24-hour simulation
.\run_docker.ps1 -Hours 6     # 6-hour simulation (default)
```

## Interactive shell (for debugging)

```powershell
.\run_docker.ps1 -Shell
# inside container:
bash /elmfire/elmfire/run_california.sh
```
