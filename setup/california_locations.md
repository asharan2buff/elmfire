# California Fire Simulation — Location Reference

Edit `tutorials/03-california-fire/run_sim.sh` and set `CENTER_LON` and
`CENTER_LAT` to any of the pre-defined locations below, or any other
coordinate inside California.

| Location                          | LAT       | LON        | Notes                                  |
|-----------------------------------|-----------|------------|----------------------------------------|
| Merced area (Tutorial 03 default) |  37.440   | -120.281   | Same as ELMFIRE's official tutorial    |
| Paradise, CA (Camp Fire 2018)     |  39.759   | -121.606   | Butte County, Sierra Nevada foothills  |
| Malibu / Santa Monica Mtns        |  34.080   | -118.780   | Coastal chaparral, SoCal               |
| Napa Valley / Glass Fire 2020     |  38.503   | -122.450   | Wine country, mixed chaparral/timber   |
| Lake Tahoe / Caldor Fire 2021     |  38.680   | -120.050   | Sierra Nevada, heavy timber fuels      |
| Big Sur / Coastal Range            |  36.200   | -121.600   | Steep terrain, chaparral/mixed         |
| San Bernardino Mtns                |  34.190   | -117.310   | Dense timber, Santa Ana wind corridor  |
| Redding / Carr Fire 2018          |  40.586   | -122.393   | Northern CA, dry grass/chaparral       |
| Sonoma County / Tubbs Fire 2017   |  38.540   | -122.720   | Oak woodland/chaparral                 |
| Ventura County / Thomas Fire 2017 |  34.270   | -119.230   | Chaparral, strong Diablo/Sundowner     |

## Customizing wind

Edit `tutorials/03-california-fire/wx.csv` to change wind speed (ws),
wind direction (wd), and fuel moistures.

**Wind direction convention:** degrees clockwise from North.
- 0°  = wind FROM the North  (fire spreads south)
- 90° = wind FROM the East   (fire spreads west) — common Santa Ana direction
- 270°= wind FROM the West   (fire spreads east)

## Tile size

The default tile is 60 km × 60 km. For larger fires or longer simulations,
set larger buffers in `run_sim.sh`:

```bash
WEST_BUFFER=40    # km west of center
EAST_BUFFER=40
SOUTH_BUFFER=40
NORTH_BUFFER=40
```

## Simulation duration

Change `SIMULATION_TSTOP` in `run_sim.sh` (value is in seconds):
- 6 hrs  = 21600
- 12 hrs = 43200
- 24 hrs = 86400
