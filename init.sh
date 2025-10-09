#!/bin/bash -ex

export IMPORT_FINISHED="/opt/import-finished"
if [ -f ${IMPORT_FINISHED} ]; then
  exit 0
fi

/app/config.sh

OSMFILE=${PROJECT_DIR}/data.osm.pbf

CURL=("curl" "-L" "-A" "${USER_AGENT}" "--fail-with-body")

# Check if THREADS is not set or is empty
if [ -z "$THREADS" ]; then
  THREADS=$(nproc)
fi

if id nominatim >/dev/null 2>&1; then
  echo "user nominatim already exists"
else
  useradd -m  nominatim
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