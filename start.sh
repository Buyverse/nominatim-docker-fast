#!/bin/bash -ex
replicationpid=0
GUNICORN_PID_FILE=/tmp/gunicorn.pid
# send gunicorn logs straight to the console without buffering: https://stackoverflow.com/questions/59812009
export PYTHONUNBUFFERED=1

if [[ "$NOMINATIM_DATABASE_DSN" = "" ]]; then
    echo "You need to specify the NOMINATIM_DATABASE_DSN environment variable"
    echo "e.g. pgsql:host=localhost;port=5433;dbname=nominatim;sslmode=disable;user=nominatim;password=your_password"
    exit 1
fi

stopServices() {
  # Check if the replication process is active
  if [ $replicationpid -ne 0 ]; then
    echo "Shutting down replication process"
    kill $replicationpid
  fi
  kill $tailpid
  cat $GUNICORN_PID_FILE | sudo xargs kill

  # Force exit code 0 to signal a successful shutdown to Docker
  exit 0
}
trap stopServices SIGTERM TERM INT


chown -R nominatim:nominatim ${PROJECT_DIR}



# start continous replication process
if [ "$REPLICATION_URL" != "" ] && [ "$FREEZE" != "true" ]; then
  # run init in case replication settings changed
  sudo -E -u nominatim nominatim replication --project-dir ${PROJECT_DIR} --init
  if [ "$UPDATE_MODE" == "continuous" ]; then
    echo "starting continuous replication"
    sudo -E -u nominatim nominatim replication --project-dir ${PROJECT_DIR} &> /var/log/replication.log &
    replicationpid=${!}
  elif [ "$UPDATE_MODE" == "once" ]; then
    echo "starting replication once"
    sudo -E -u nominatim nominatim replication --project-dir ${PROJECT_DIR} --once &> /var/log/replication.log &
    replicationpid=${!}
  elif [ "$UPDATE_MODE" == "catch-up" ]; then
    echo "starting replication once in catch-up mode"
    sudo -E -u nominatim nominatim replication --project-dir ${PROJECT_DIR} --catch-up &> /var/log/replication.log &
    replicationpid=${!}
  else
    echo "skipping replication"
  fi
fi

# fork a process and wait for it
tailpid=${!}




# Set default number of workers if not specified
if [ -z "$GUNICORN_WORKERS" ]; then
  GUNICORN_WORKERS=$(nproc)
fi

echo "Starting Gunicorn with $GUNICORN_WORKERS workers"

echo "--> Nominatim is ready to accept requests"

cd "$PROJECT_DIR"
sudo -E -u nominatim gunicorn \
  --bind :8080 \
  --pid $GUNICORN_PID_FILE \
  --workers $GUNICORN_WORKERS \
  --daemon \
  --enable-stdio-inheritance \
  --worker-class uvicorn.workers.UvicornWorker \
  nominatim_api.server.falcon.server:run_wsgi

sleep infinity