#!/bin/bash

user=$1
shift

password=$1

if [ -z "$password" ]; then
  # Read Password
  echo -n "Password: "
  read -s password
  echo
fi

password=$(printf '%q' "$password")

read -r -d '' SCRIPT <<EOF
set -e
export PGPASSWORD="\$POSTGRES_PASSWORD";
export PGUSER=postgres;
psql -c "CREATE ROLE $user NOSUPERUSER NOCREATEDB NOCREATEROLE INHERIT LOGIN PASSWORD '$(printf '%q' "$password")'";
psql -c 'CREATE DATABASE "$user" OWNER "$user"';
EOF

echo $SCRIPT

kubectl exec -n databases postgresql-0 -- bash -c "$SCRIPT"
