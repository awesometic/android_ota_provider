#!/bin/bash

if [ ! $# -eq 2 ] ; then
    echo "Usage: $0 <device codename> <ota zip>"
    exit 1
fi

DEVICE="$1"
ROM="$2"

METADATA=$(unzip -p "$ROM" META-INF/com/android/metadata)
SDK_LEVEL=$(echo "$METADATA" | grep post-sdk-level | cut -f2 -d '=')
TIMESTAMP=$(echo "$METADATA" | grep post-timestamp | cut -f2 -d '=')

FILENAME=$(basename $ROM)
ROMNAME=$(echo $FILENAME | cut -f1 -d '-')

case $ROMNAME in
  "lineage")
    ROMTYPE=$(echo $FILENAME | cut -f4 -d '-')
    ;;
  "crDroidAndroid")
    # Assume that all the crDroid ROMs released by this script are unofficial one
    ROMTYPE="UNOFFICIAL"
    ;;
  *)
    echo "Unknwon ROM name: $ROMNAME"
    exit 1
esac

DATE=$(echo $FILENAME | cut -f3 -d '-')
ID=$(echo ${TIMESTAMP}${DEVICE}${SDK_LEVEL} | sha256sum | cut -f 1 -d ' ')
SIZE=$(du -b $ROM | cut -f1 -d '	')
VERSION=$(echo $FILENAME | cut -f2 -d '-')
RELASE_TAG=${DEVICE}_${ROMNAME}-${VERSION}_${TIMESTAMP}

URL="https://github.com/awesometic/android-ota-provider/releases/download/${RELASE_TAG}/${FILENAME}"

response=$(jq -n --arg datetime $TIMESTAMP \
        --arg filename $FILENAME \
        --arg id $ID \
        --arg romtype $ROMTYPE \
        --arg size $SIZE \
        --arg url $URL \
        --arg version $VERSION \
        '$ARGS.named'
)
wrapped_response=$(jq -n --argjson response "[$response]" '$ARGS.named')

#! Ensure you are at the repository directory
if [ ! -d $(pwd)/${ROMNAME}-${VERSION} ]; then
  mkdir $(pwd)/${ROMNAME}-${VERSION}
fi

echo "$wrapped_response" > ${ROMNAME}-${VERSION}/${DEVICE}.json
git add ${ROMNAME}-${VERSION}/${DEVICE}.json
git commit -m "Update autogenerated json for $DEVICE $ROMNAME $VERSION ${DATE}/${TIMESTAMP}"
git push origin main -f

gh release create $RELASE_TAG $ROM --notes "Automated release for $DEVICE $ROMNAME $VERSION ${DATE}/${TIMESTAMP}"
