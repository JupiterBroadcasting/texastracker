#!/usr/bin/env bash
set -euo pipefail

FILE_CKSUM() {
    cksum "$1" | cut -d' ' -f1
}

export AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="$R2_SECRET_KEY"
export AWS_ENDPOINT_URL="$R2_ENDPOINT"

prev_wes_cksum=""
prev_brent_cksum=""

while true; do
    echo "$(date): Fetching data..."

    # Fetch person 1
    curl "$DAWARICH_URL/api/v1/points?api_key=$APIKEY1" > wes_new.json
    [ -f wes.json ] || echo '[{}]' > wes.json
    jq -s '[ add | unique_by(.id) | sort_by(.timestamp) ] | .[]' wes_new.json wes.json > wes_merged.json
    mv wes_merged.json wes.json

    # Fetch person 2
    curl "$DAWARICH_URL/api/v1/points?api_key=$APIKEY2" > brent_new.json
    [ -f brent.json ] || echo '[{}]' > brent.json
    jq -s '[ add | unique_by(.id) | sort_by(.timestamp) ] | .[]' brent_new.json brent.json > brent_merged.json
    mv brent_merged.json brent.json

    # Compute checksums
    wes_cksum=$(FILE_CKSUM wes.json)
    brent_cksum=$(FILE_CKSUM brent.json)

    # Upload only if changed
    if [ "$wes_cksum" != "$prev_wes_cksum" ]; then
        s5cmd --endpoint-url="$AWS_ENDPOINT_URL" cp wes.json "s3://$R2_BUCKET/wes.json"
        prev_wes_cksum="$wes_cksum"
        echo "$(date): Uploaded wes.json"
    else
        echo "$(date): wes.json unchanged, skipping upload"
    fi

    if [ "$brent_cksum" != "$prev_brent_cksum" ]; then
        s5cmd --endpoint-url="$AWS_ENDPOINT_URL" cp brent.json "s3://$R2_BUCKET/brent.json"
        prev_brent_cksum="$brent_cksum"
        echo "$(date): Uploaded brent.json"
    else
        echo "$(date): brent.json unchanged, skipping upload"
    fi

    echo "$(date): Done. Sleeping $INTERVAL seconds..."
    sleep "$INTERVAL"
done
