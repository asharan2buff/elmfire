#!/bin/bash
# run_california.sh
#
# Run an ELMFIRE Tutorial-03-style fire simulation at any California location.
# This script is designed to run INSIDE the ELMFIRE Docker container.
#
# Usage (from inside container):
#   bash /elmfire/elmfire/run_california.sh
#
# Or via the Windows PowerShell helper:
#   .\run_docker.ps1

set -e

# ╔══════════════════════════════════════════════════════════════════════╗
# ║         USER-CONFIGURABLE SETTINGS — edit these before running      ║
# ╚══════════════════════════════════════════════════════════════════════╝

# --- Ignition location (center of simulation tile) ---------------------
# See docker_shared_folder/california_locations.md for presets.
CENTER_LAT=38.503        # Napa Valley / Glass Fire 2020 area
CENTER_LON=-120.281      # change to any CA lon/lat

# --- Tile size in km from center to each edge -------------------------
WEST_BUFFER=30
EAST_BUFFER=30
SOUTH_BUFFER=30
NORTH_BUFFER=30

# --- Simulation duration ----------------------------------------------
SIMULATION_TSTOP=21600.0   # seconds (21600 = 6 hours, 86400 = 24 hours)

# --- Weather (edit wx.csv *before* launching container) ---------------
WX_INPUTS_FILE=/elmfire/elmfire/docker_shared_folder/wx.csv

# --- Fuel source -------------------------------------------------------
FUEL_SOURCE='landfire'
FUEL_VERSION='2.4.0'

# ╚══════════════════════════════════════════════════════════════════════╝

# ── Resolve paths ─────────────────────────────────────────────────────
ELMFIRE_VER=${ELMFIRE_VER:-2025.1002}
BASE=/elmfire/elmfire
SHARED=$BASE/docker_shared_folder
SIM_DIR=$SHARED/simulation
FUEL_DIR=$SHARED/fuel
SCRATCH=$SIM_DIR/scratch
INPUTS=$SIM_DIR/inputs
OUTPUTS=$SIM_DIR/outputs

. $BASE/tutorials/functions/functions.sh

mkdir -p "$FUEL_DIR"
rm -rf "$SCRATCH" "$INPUTS" "$OUTPUTS"
mkdir -p "$SCRATCH" "$INPUTS" "$OUTPUTS"
cp $BASE/tutorials/03-real-fuels/elmfire.data.in $INPUTS/elmfire.data

echo "============================================================"
echo " ELMFIRE — California Fire Simulation"
echo "============================================================"
echo " Location   : ${CENTER_LAT}N, ${CENTER_LON}E"
echo " Domain     : ${WEST_BUFFER}km W / ${EAST_BUFFER}km E / ${SOUTH_BUFFER}km S / ${NORTH_BUFFER}km N"
echo " Duration   : $(echo "$SIMULATION_TSTOP / 3600" | bc) hours"
echo " Executable : elmfire_${ELMFIRE_VER}"
echo "============================================================"

# ── Step 1: fetch fuel/topography from Cloudfire ──────────────────────
echo ""
echo "[1/5] Fetching LANDFIRE fuel and topography from Cloudfire..."

TARBALL="$FUEL_DIR/california_fire.tar"
if [ -f "$TARBALL" ]; then
    echo "      Tarball already exists — skipping download."
    echo "      Delete $TARBALL to force re-download."
else
    $BASE/cloudfire/fuel_wx_ign.py \
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
        --name="california_fire"
fi

echo "      Extracting..."
tar -xf "$TARBALL" -C "$INPUTS"
rm -f $INPUTS/m*.tif $INPUTS/w*.tif $INPUTS/l*.tif $INPUTS/ignition*.tif $INPUTS/forecast_cycle.txt

# ── Get spatial metadata from fuel raster ─────────────────────────────
XMIN=`gdalinfo $INPUTS/fbfm40.tif | grep 'Lower Left'  | cut -d'(' -f2 | cut -d, -f1 | xargs`
YMIN=`gdalinfo $INPUTS/fbfm40.tif | grep 'Lower Left'  | cut -d'(' -f2 | cut -d, -f2 | cut -d')' -f1 | xargs`
XMAX=`gdalinfo $INPUTS/fbfm40.tif | grep 'Upper Right' | cut -d'(' -f2 | cut -d, -f1 | xargs`
YMAX=`gdalinfo $INPUTS/fbfm40.tif | grep 'Upper Right' | cut -d'(' -f2 | cut -d, -f2 | cut -d')' -f1 | xargs`
XCEN=`echo "0.5*($XMIN + $XMAX)" | bc`
YCEN=`echo "0.5*($YMIN + $YMAX)" | bc`
A_SRS=`gdalsrsinfo $INPUTS/fbfm40.tif | grep PROJ.4 | cut -d: -f2 | xargs`
CELLSIZE=`gdalinfo $INPUTS/fbfm40.tif | grep 'Pixel Size' | cut -d'(' -f2 | cut -d, -f1`

# ── Step 2: build multiband weather rasters from wx.csv ───────────────
echo ""
echo "[2/5] Building weather rasters from wx.csv..."

if [ ! -f "$WX_INPUTS_FILE" ]; then
    echo "      wx.csv not found at $WX_INPUTS_FILE"
    echo "      Falling back to tutorial default at $BASE/tutorials/03-real-fuels/wx.csv"
    WX_INPUTS_FILE=$BASE/tutorials/03-real-fuels/wx.csv
fi

gdalwarp -multi -dstnodata -9999 -tr 300 300 $INPUTS/adj.tif $SCRATCH/dummy.tif
gdal_calc.py -A $SCRATCH/dummy.tif --NoDataValue=-9999 --type=Float32 \
    --outfile="$SCRATCH/float.tif" --calc="A*0.0"

COLS=`head -n 1 $WX_INPUTS_FILE | tr ',' ' ' | tr -d '\r'`
tail -n +2 $WX_INPUTS_FILE | tr -d '\r' > $SCRATCH/wx.csv
NUM_TIMES=`cat $SCRATCH/wx.csv | wc -l`
echo "      Weather timesteps: $NUM_TIMES"

ICOL=0
for QUANTITY in $COLS; do
    let "ICOL = ICOL + 1"
    TIMESTEP=0
    FNLIST=''
    while read LINE; do
        VAL=`echo $LINE | cut -d, -f$ICOL`
        FNOUT=$SCRATCH/${QUANTITY}_$TIMESTEP.tif
        FNLIST="$FNLIST $FNOUT"
        gdal_calc.py -A $SCRATCH/float.tif --NoDataValue=-9999 --type=Float32 \
            --outfile="$FNOUT" --calc="A + $VAL" >& /dev/null &
        let "TIMESTEP=TIMESTEP+1"
    done < $SCRATCH/wx.csv
    wait
    gdal_merge.py -separate -n -9999 -init -9999 -a_nodata -9999 \
        -co "COMPRESS=DEFLATE" -co "ZLEVEL=9" -o $INPUTS/$QUANTITY.tif $FNLIST
    echo "      -> $QUANTITY.tif ($TIMESTEP bands)"
done

# ── Step 3: write ELMFIRE namelist inputs ─────────────────────────────
echo ""
echo "[3/5] Configuring ELMFIRE input deck..."

# replace_line uses hardcoded relative path "./inputs/elmfire.data" so we must
# have SIM_DIR as the working directory when calling it.
cd "$SIM_DIR"

replace_line COMPUTATIONAL_DOMAIN_XLLCORNER $XMIN no
replace_line COMPUTATIONAL_DOMAIN_YLLCORNER $YMIN no
replace_line COMPUTATIONAL_DOMAIN_CELLSIZE  $CELLSIZE no
replace_line SIMULATION_TSTOP              $SIMULATION_TSTOP no
replace_line DTDUMP                        $SIMULATION_TSTOP no
replace_line A_SRS                         "$A_SRS" yes
replace_line 'X_IGN(1)'                   $XCEN no
replace_line 'Y_IGN(1)'                   $YCEN no

# ── Step 4: run ELMFIRE ───────────────────────────────────────────────
echo ""
echo "[4/5] Running ELMFIRE fire spread simulation..."
echo "      (This may take 1-5 minutes depending on domain size)"
echo ""

# Working dir is $SIM_DIR; elmfire.data uses relative ./inputs and ./outputs
mpirun --allow-run-as-root -np 1 elmfire_${ELMFIRE_VER} ./inputs/elmfire.data

# ── Step 5: postprocess ───────────────────────────────────────────────
echo ""
echo "[5/5] Postprocessing outputs..."

for f in ./outputs/*.bil; do
    [ -f "$f" ] || continue
    gdal_translate -a_srs "$A_SRS" -co "COMPRESS=DEFLATE" -co "ZLEVEL=9" \
        "$f" "./outputs/$(basename $f | cut -d. -f1).tif"
done

gdal_contour -i 3600 $(ls ./outputs/time_of_arrival*.tif 2>/dev/null | head -1) \
    ./outputs/hourly_isochrones.shp 2>/dev/null || true

echo ""
echo "============================================================"
echo " Simulation complete!"
echo " Outputs are in: docker_shared_folder/simulation/outputs/"
echo " On Windows, open:"
echo "   elmfire-src/docker_shared_folder/simulation/outputs/"
echo "============================================================"
echo ""
echo " Key files:"
echo "   time_of_arrival*.tif   — fire arrival raster"
echo "   hourly_isochrones.shp  — hourly perimeter shapefile"
echo "   flame_length*.tif      — flame length raster"
