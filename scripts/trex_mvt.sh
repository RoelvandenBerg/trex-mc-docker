#!/usr/bin/env bash
function getExtent(){
    source_name=$1
    filename="${source_name}_export.gpkg"
    extent_string=$(ogrinfo -so "$filename" "${source_name}_export" | grep Extent)
    regex="Extent:\s\(([0-9\.]+),\s([0-9\.]+)\)\s-\s\(([0-9\.]+),\s([0-9\.]+)\)"
    if [[ $extent_string =~ $regex ]]; then
        echo "extent_string: $extent_string"
        LOWER=$(echo -e "${BASH_REMATCH[1]} ${BASH_REMATCH[2]}" |  gdaltransform -output_xy  -s_srs EPSG:28992 -t_srs EPSG:4326)
        UPPER=$(echo -e "${BASH_REMATCH[3]} ${BASH_REMATCH[4]}" |  gdaltransform -output_xy  -s_srs EPSG:28992 -t_srs EPSG:4326)
        EXTENT="$(echo $LOWER | awk '{print $1","$2}'),$(echo $UPPER | awk '{print $1","$2}')"
    else
        echo "could not determine bbox"
        exit 1
    fi
}

function init(){
    sed "s/\$SOURCE_NAME/$SOURCE_NAME/g;"  "scripts/config.toml.template"  > "config.toml"
    getExtent "$SOURCE_NAME"
}

function onFinish(){
    jq --arg extent $EXTENT .bounds='"[\($extent)]"' "tiles/$SOURCE_NAME/$SOURCE_NAME/metadata.json" > "tiles/$SOURCE_NAME/$SOURCE_NAME/metadata.json.tmp"
    mv "tiles/$SOURCE_NAME/$SOURCE_NAME/metadata.json.tmp" "tiles/$SOURCE_NAME/$SOURCE_NAME/metadata.json"
}

SOURCE_NAME=$1
MIN_ZOOM=${2:-1}
MAX_ZOOM=${3:-10}

echo "SOURCE_NAME: $SOURCE_NAME"

echo "configure minio"
mc config host add \
    minio \
    "$AWS_API_ENDPOINT" \
    "$AWS_ACCESS_KEY_ID" \
    "$AWS_SECRET_ACCESS_KEY"

echo "copy resource from minio"
mc cp \
    "minio/${AWS_S3_BUCKET}/input/${SOURCE_NAME}_export.gpkg" \
     /root/export.gpkg

echo "t-rex: generate tiles"
init "$SOURCE_NAME"
    echo "EXTENT: $EXTENT"
    t_rex generate \
        --config config.toml \
        --maxzoom $MAX_ZOOM \
        --minzoom $MIN_ZOOM \
        --extent "$EXTENT" \
        --tileset "$SOURCE_NAME" \
        --overwrite true

echo "copy to minio"
mc cp \
    --recursive \
    --attr "Content-Encoding=gzip;Content-Type=application/vnd.mapbox-vector-tile" \
    "/root/$SOURCE_NAME/" \
    "minio/$AWS_S3_BUCKET/$AWS_S3_KEY_PREFIX/$SOURCE_NAME"
