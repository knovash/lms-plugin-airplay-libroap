#!/bin/bash
# Сборка дистрибутива: dist/RaopBridgeAP2-v<VER>.zip + sha1
set -e
cd "$(dirname "$0")"

VER=$(grep -oPm1 '(?<=<version>)[^<]+' RaopBridgeAP2/install.xml)
ZIP="dist/RaopBridgeAP2-v${VER}.zip"

rm -rf dist
mkdir -p dist
zip -r "$ZIP" RaopBridgeAP2 -x "*.DS_Store"
echo
echo "ZIP: $ZIP"
echo "sha1: $(sha1sum "$ZIP" | cut -d' ' -f1)"
echo "Upload as release asset v${VER} and update repo.xml (sha=, url=)."
