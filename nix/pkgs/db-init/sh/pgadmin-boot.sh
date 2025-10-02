#!/bin/bash
# ^ The Nix derivation replaces the shebang with a suitable one.

#
# See `docs.md` for script documentation.
#

# Stop at the first error, especially if in a pipeline.
set -ueo pipefail

# Read input args.
superuser_email="$1"
initial_password_file="$2"
db_uri="$3"

# Locate the local connection SQL script.
script_dir=$(dirname "$0")
base_dir=$(readlink -f "${script_dir}/..")
local_conn_script="${base_dir}/sql/pgadmin-local-conn.sql"

# Write the content of the password file to `stdout`, bailing out if
# the password has less than six chars.
read_password() {
    local len=$(wc -m < "${initial_password_file}")
    if [ ${len} -lt 6 ]; then
        echo "Password must be at least 6 characters long."
        exit 1
    fi
    cat "${initial_password_file}"
}

# Run PgAdmin DB setup in non-interactive mode
setup_db() {
    local password=$(read_password)
    
    # IMPORTANTE: Esporta le variabili che pgadmin4 usa per trovare la config
    export SERVER_MODE="True"
    
    # Setup database fornendo le credenziali via stdin
    (
        echo "${superuser_email}"
        echo "${password}"
        echo "${password}"
    ) | pgadmin4-cli setup-db
}

# Run our SQL script to set up a Unix socket server connection for
# the PgAdmin UI.
setup_local_connection() {
    psql "${db_uri}" -f "${local_conn_script}"
}


# Let the show begin...
setup_db
setup_local_connection
systemd-notify --ready --status='DB bootstrap completed.'