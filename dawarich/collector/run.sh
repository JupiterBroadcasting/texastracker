#!/bin/bash

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

    
    # Upload to R2
    export AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY"
    export AWS_SECRET_ACCESS_KEY="$R2_SECRET_KEY"
    export AWS_ENDPOINT_URL="$R2_ENDPOINT"
    
    s5cmd --endpoint-url="$AWS_ENDPOINT_URL" cp wes.json s3://$R2_BUCKET/wes.json
    s5cmd --endpoint-url="$AWS_ENDPOINT_URL" cp brent.json s3://$R2_BUCKET/brent.json
    
    echo "$(date): Done. Sleeping $INTERVAL seconds..."
    sleep $INTERVAL
done
