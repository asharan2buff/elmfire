#!/bin/bash
# run_sim.sh — Tutorial 03 California fire simulation
#
# This script fetches real LANDFIRE fuel/terrain data from the Cloudfire
# server for any location in California and runs an ELMFIRE fire spread
# simulation.
#
# Prerequisites:
#   - ELMFIRE installed and built (see README.md)
#   - Environment variables set (ELMFIRE_BASE_DIR, etc.)
#   - Source ~/.bashrc before running:  source ~/.bashrc
#
# Usage:
#   bash tutorials/03-california-fire/run_sim.sh

set -e

# ╔══════════════════════════════════════════════════════════════════════╗
# ║              USER-CONFIGURABLE SETTINGS — edit these                ║
# ╚══════════════════════════════════════════════════════════════════════╝

# --- Location (center of simulation domain) ----------------------------
# See setup/california_locations.md for a list of preset locations.
CENTER_LAT=38.503          # Napa Valley (Glass Fire area)
CENTER_LON=-122.450

# --- Domain size (km from center to each edge) -------------------------
WEST_BUFFER=30
EAST_BUFFER=30
SOUTH_BUFFER=30
NORTH_BUFFER=30

# --- Simulation duration -----------------------------------------------
SIMULATION_TSTOP=21600     # seconds  (21600 = 6 hours)

# --- Meteorology timestep (must match number of rows in wx.csv) --------
DT_METEOROLOGY=3600        # seconds between weather bands (1 hour)

# --- Ignition point (relative to domain center, in meters) -------------
X_IGN=0.0
Y_IGN=0.0
T_IGN=0.0                  # ignition time in seconds from simulation start

# --- Fuel source -------------------------------------------------------
FUEL_SOURCE="landfire"
FUEL_VERSION="2.2.0"

# --- Simulation name / output tag --------------------------------------
SIM_NAME="california_fire"

# ╔══════════════════════════════════════════════════════════════════════╗
# ║                    SCRIPT BODY — no need to edit below              ║
# ╚══════════════════════════════════════════════════════════════════════╝

# Resolve directories relative to this script's parent location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$SCRIPT_DIR"

INPUTS_DIR="$WORK_DIR/inputs"
OUTPUTS_DIR="$WORK_DIR/outputs"
FUEL_DIR="$WORK_DIR/fuel"

mkdir -p "$INPUTS_DIR" "$OUTPUTS_DIR" "$FUEL_DIR"

echo "============================================================"
echo " ELMFIRE Tutorial 03 — California Fire Simulation"
echo "============================================================"
echo " Location  : ${CENTER_LAT}N, ${CENTER_LON}E"
echo " Domain    : ${WEST_BUFFER}km W / ${EAST_BUFFER}km E / ${SOUTH_BUFFER}km S / ${NORTH_BUFFER}km N"
echo " Duration  : $(echo "$SIMULATION_TSTOP / 3600" | bc) hours"
echo "============================================================"

# ── Step 1: fetch fuel and topography from Cloudfire ──────────────────
echo ""
echo "[1/5] Fetching fuel and topography from Cloudfire..."

TARBALL="$FUEL_DIR/${SIM_NAME}.tar"

if [ -f "$TARBALL" ]; then
    echo "      Tarball already exists — skipping download. Delete $TARBALL to re-fetch."
else
    fuel_wx_ign.py \
        --do_wx=False \
        --do_ignition=False \
        --center_lon=${CENTER_LON} \
        --center_lat=${CENTER_LAT} \
        --west_buffer=${WEST_BUFFER} \
        --east_buffer=${EAST_BUFFER} \
        --south_buffer=${SOUTH_BUFFER} \
        --north_buffer=${NORTH_BUFFER} \
        --fuel_source="${FUEL_SOURCE}" \
        --fuel_version="${FUEL_VERSION}" \
        --outdir="${FUEL_DIR}" \
        --name="${SIM_NAME}"
fi

echo "      Extracting fuel tarball..."
tar -xf "$TARBALL" -C "$INPUTS_DIR" --overwrite

# ── Step 2: build multi-band weather rasters from wx.csv ──────────────
echo ""
echo "[2/5] Building weather rasters from wx.csv..."

WX_CSV="$SCRIPT_DIR/wx.csv"

# Get spatial extent from the fuel raster (fbfm40 is always present)
FBFM40="$INPUTS_DIR/fbfm40.tif"
read XMIN YMIN XMAX YMAX <<< $(gdalinfo "$FBFM40" | \
    grep -E 'Upper Left|Lower Right' | \
    awk '{gsub(/[(),]/," "); print $3, $4}' | \
    awk 'NR==1{printf "%s %s ", $1, $2} NR==2{printf "%s %s\n", $1, $2}')

read COLS ROWS <<< $(gdalinfo "$FBFM40" | grep "Size is" | \
    awk '{print $3, $4}' | tr ',' ' ')

NODATA=-9999

# Parse wx.csv, skipping header
tail -n +2 "$WX_CSV" | while IFS=',' read ws wd m1 m10 m100 lh lw; do
    echo "$ws $wd $m1 $m10 $m100 $lh $lw"
done > /tmp/elmfire_wx_rows.txt

NUM_BANDS=$(wc -l < /tmp/elmfire_wx_rows.txt)

echo "      Weather bands: $NUM_BANDS"

# Create a single-value constant raster for each band of each variable
create_band_raster() {
    local VAR=$1
    local IDX=$2
    local VAL=$3
    gdal_calc.py \
        -A "$FBFM40" \
        --outfile="/tmp/elmfire_${VAR}_band${IDX}.tif" \
        --calc="$VAL * (A > -9998)" \
        --NoDataValue=$NODATA \
        --quiet \
        --overwrite
}

VARS=(ws wd m1 m10 m100 lh lw)
for var in "${VARS[@]}"; do
    rm -f /tmp/elmfire_${var}_band*.tif
done

IDX=1
while read ws wd m1 m10 m100 lh lw; do
    create_band_raster ws  $IDX $ws
    create_band_raster wd  $IDX $wd
    create_band_raster m1  $IDX $m1
    create_band_raster m10 $IDX $m10
    create_band_raster m100 $IDX $m100
    create_band_raster lh  $IDX $lh
    create_band_raster lw  $IDX $lw
    IDX=$((IDX + 1))
done < /tmp/elmfire_wx_rows.txt

echo "      Stacking bands into multiband GeoTiffs..."
for var in "${VARS[@]}"; do
    BAND_FILES=$(ls /tmp/elmfire_${var}_band*.tif | sort -V | tr '\n' ' ')
    gdal_merge.py -separate -o "$INPUTS_DIR/${var}.tif" $BAND_FILES -q
    echo "        -> $INPUTS_DIR/${var}.tif  (${NUM_BANDS} bands)"
done

# ── Step 3: compute ignition coordinates ──────────────────────────────
echo ""
echo "[3/5] Computing ignition coordinates..."

# The ignition is expressed relative to the center of the domain.
# ELMFIRE Tutorial 03 uses the domain center as origin.
# Determine the projected coordinate of the domain center.
CENTER_X=$(echo "($XMIN + $XMAX) / 2" | bc -l)
CENTER_Y=$(echo "($YMIN + $YMAX) / 2" | bc -l)

IGN_X=$(echo "$CENTER_X + $X_IGN" | bc -l)
IGN_Y=$(echo "$CENTER_Y + $Y_IGN" | bc -l)

echo "      Ignition (projected): X=${IGN_X}  Y=${IGN_Y}"

# ── Step 4: write elmfire.data namelist ───────────────────────────────
echo ""
echo "[4/5] Writing ELMFIRE input deck (elmfire.data)..."

cat > "$INPUTS_DIR/elmfire.data" << NAMELIST
&INPUTS
FUELS_AND_TOPOGRAPHY_DIRECTORY = '$INPUTS_DIR/'
WEATHER_DIRECTORY               = '$INPUTS_DIR/'
MISCELLANEOUS_INPUTS_DIRECTORY  = '$INPUTS_DIR/'
OUTPUTS_DIRECTORY               = '$OUTPUTS_DIR/'

FUEL_MODEL_FILE = 'fbfm40.tif'
CANOPY_COVER_FILE = 'cc.tif'
CANOPY_HEIGHT_FILE = 'ch.tif'
CANOPY_BASE_HEIGHT_FILE = 'cbh.tif'
CANOPY_BULK_DENSITY_FILE = 'cbd.tif'

WIND_SPEED_FILE        = 'ws.tif'
WIND_DIRECTION_FILE    = 'wd.tif'
M1_FILE                = 'm1.tif'
M10_FILE               = 'm10.tif'
M100_FILE              = 'm100.tif'
MLH_FILE               = 'lh.tif'
MLW_FILE               = 'lw.tif'

DT_METEOROLOGY = ${DT_METEOROLOGY}.

TERRAIN_IN_M = .TRUE.
SLOPE_FILE = 'slp.tif'
ASPECT_FILE = 'asp.tif'
DEM_FILE    = 'dem.tif'
/

&OUTPUTS
DTDUMP = 3600.
DUMP_FLAME_LENGTH  = .TRUE.
DUMP_SPREAD_RATE   = .TRUE.
DUMP_CROWN_FIRE    = .TRUE.
HOURLY_ISOCHRONES  = .TRUE.
/

&SIMULATOR
DT_DUMP           = 3600.
SIMULATION_TSTOP  = ${SIMULATION_TSTOP}.
NUM_IGNITIONS     = 1
X_IGN(1)          = ${IGN_X}
Y_IGN(1)          = ${IGN_Y}
T_IGN(1)          = ${T_IGN}
/

&MONTE_CARLO
NUM_METEOROLOGY_TIMES = ${NUM_BANDS}
/
NAMELIST

echo "      Written to $INPUTS_DIR/elmfire.data"

# ── Step 5: run ELMFIRE ───────────────────────────────────────────────
echo ""
echo "[5/5] Running ELMFIRE..."
echo "      This may take a few minutes depending on domain size."
echo ""

# Find the elmfire executable (format: elmfire_YYYY.MMDD)
ELMFIRE_EXE=$(ls "$ELMFIRE_INSTALL_DIR"/elmfire_[0-9]* 2>/dev/null | sort -V | tail -1)

if [ -z "$ELMFIRE_EXE" ]; then
    echo "ERROR: ELMFIRE executable not found in $ELMFIRE_INSTALL_DIR"
    echo "       Please build ELMFIRE first:"
    echo "         cd \$ELMFIRE_BASE_DIR/build/linux && ./make_gnu.sh"
    exit 1
fi

echo "      Using executable: $ELMFIRE_EXE"
echo ""

mpirun -np 1 "$ELMFIRE_EXE" "$INPUTS_DIR/elmfire.data"

echo ""
echo "============================================================"
echo " Simulation complete!"
echo "============================================================"
echo ""
echo " Outputs written to: $OUTPUTS_DIR"
echo ""
echo " Key output files:"
echo "   time_of_arrival.tif     — raster of fire arrival time (s)"
echo "   hourly_isochrones.shp   — hourly fire perimeter shapefile"
echo "   flame_length.tif        — peak flame length raster"
echo ""
echo " Open these in QGIS (Windows) by browsing to:"
echo "   $(wslpath -w "$OUTPUTS_DIR" 2>/dev/null || echo "$OUTPUTS_DIR")"
echo ""
