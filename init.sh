#!/bin/bash -ex

export IMPORT_FINISHED="/opt/import-finished"
if [ -f ${IMPORT_FINISHED} ]; then
  exit 0
fi

/app/config.sh

OSMFILE=${PROJECT_DIR}/data.osm.pbf

CURL=("curl" "-L" "-A" "${USER_AGENT}" "--fail-with-body")

SCP='sshpass -p DMg5bmLPY7npHL2Q scp -o StrictHostKeyChecking=no u355874-sub1@u355874-sub1.your-storagebox.de'

# Check if THREADS is not set or is empty
if [ -z "$THREADS" ]; then
  THREADS=$(nproc)
fi

if id nominatim >/dev/null 2>&1; then
  echo "user nominatim already exists"
else
  useradd -m  nominatim
fi

# we re-host the files on a Hetzner storage box because inconsiderate users eat up all of
# nominatim.org's bandwidth
# https://github.com/mediagis/nominatim-docker/issues/416

# https://nominatim.org/release-docs/5.1/admin/Import/#wikipediawikidata-rankings
# TODO: Should we need a new env var $IMPORT_SECONDARY_WIKIPEDIA
#  (using wget -O secondary_importance.sql.gz https://nominatim.org/data/wikimedia-secondary-importance.sql.gz)
if [ "$IMPORT_WIKIPEDIA" = "true" ]; then
  echo "Downloading Wikipedia importance dump"
  ${SCP}:wikimedia-importance.csv.gz ${PROJECT_DIR}/wikimedia-importance.csv.gz
elif [ -f "$IMPORT_WIKIPEDIA" ]; then
  # use local file if asked
  ln -s "$IMPORT_WIKIPEDIA" ${PROJECT_DIR}/wikimedia-importance.csv.gz
else
  echo "Skipping optional Wikipedia importance import"
fi;

if [ "$IMPORT_GB_POSTCODES" = "true" ]; then
  ${SCP}:gb_postcodes.csv.gz ${PROJECT_DIR}/gb_postcodes.csv.gz
elif [ -f "$IMPORT_GB_POSTCODES" ]; then
  # use local file if asked
  ln -s "$IMPORT_GB_POSTCODES" ${PROJECT_DIR}/gb_postcodes.csv.gz
else \
  echo "Skipping optional GB postcode import"
fi;

if [ "$IMPORT_US_POSTCODES" = "true" ]; then
  ${SCP}:us_postcodes.csv.gz ${PROJECT_DIR}/us_postcodes.csv.gz
elif [ -f "$IMPORT_US_POSTCODES" ]; then
  # use local file if asked
  ln -s "$IMPORT_US_POSTCODES" ${PROJECT_DIR}/us_postcodes.csv.gz
else
  echo "Skipping optional US postcode import"
fi;

if [ "$IMPORT_TIGER_ADDRESSES" = "true" ]; then
  ${SCP}:tiger2024-nominatim-preprocessed.csv.tar.gz ${PROJECT_DIR}/tiger-nominatim-preprocessed.csv.tar.gz
elif [ -f "$IMPORT_TIGER_ADDRESSES" ]; then
  # use local file if asked
  ln -s "$IMPORT_TIGER_ADDRESSES" ${PROJECT_DIR}/tiger-nominatim-preprocessed.csv.tar.gz
else
  echo "Skipping optional Tiger addresses import"
fi

if [ "$PBF_URL" != "" ]; then
  echo Downloading OSM extract from "$PBF_URL"
  "${CURL[@]}" "$PBF_URL" -C - --create-dirs -o $OSMFILE
fi

if [ "$PBF_PATH" != "" ]; then
  echo Reading OSM extract from "$PBF_PATH"
  OSMFILE=$PBF_PATH
fi



chown -R nominatim:nominatim ${PROJECT_DIR}


cd ${PROJECT_DIR}



# Sometimes Nominatim marks parent places to be indexed during the initial
# import which leads to '123 entries are not yet indexed' errors in --check-database
# Thus another quick additional index here for the remaining places
sudo -E -u nominatim nominatim index --threads $THREADS


export NOMINATIM_QUERY_TIMEOUT=600
export NOMINATIM_REQUEST_TIMEOUT=3600
export NOMINATIM_QUERY_TIMEOUT=10
export NOMINATIM_REQUEST_TIMEOUT=60

# gather statistics for query planner to potentially improve query performance
# see, https://github.com/osm-search/Nominatim/issues/1023
# and  https://github.com/osm-search/Nominatim/issues/1139

echo "Deleting downloaded dumps in ${PROJECT_DIR}"
rm -f ${PROJECT_DIR}/*sql.gz
rm -f ${PROJECT_DIR}/*csv.gz
rm -f ${PROJECT_DIR}/tiger-nominatim-preprocessed.csv.tar.gz

if [ "$PBF_URL" != "" ]; then
  rm -f ${OSMFILE}
fi

touch ${IMPORT_FINISHED}