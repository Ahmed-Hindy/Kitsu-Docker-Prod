#!/usr/bin/env bash
set -euo pipefail

/backup_db_once.sh
/backup_previews_once.sh
