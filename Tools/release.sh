#!/bin/bash
# Archives and uploads AMS Seedboard to TestFlight from this Mac.   Tools/release.sh <build number, e.g. 1> [ios|mac|both]
# Uses Martin's ADMIN App Store Connect key (cloud signing); the issuer ID is read from his memory note by asc.py.
set -e
cd "$(dirname "$0")/.."
BUILD="${1:?build number, e.g. 1}"; WHAT="${2:-both}"
# The App Store Connect app id is not known yet. Fill it in once the app exists there.
APP_ID="6836228189"
KEY="/Users/martinschabbauer/Documents/01 Leisure/30 App Development/Apple Developer/AMS PARA/p8 file - Admin/AuthKey_63M2792NNV.p8"
ASC="${ASC_PY:-/Users/martinschabbauer/Documents/01 Leisure/30 App Development/AMS Packing App/private/release-tools/asc.py}"
ISSUER=$(python3 -c "import importlib.util,sys; s=importlib.util.spec_from_file_location('asc','$ASC'); m=importlib.util.module_from_spec(s); sys.argv=['x']; s.loader.exec_module(m); print(m.issuer())")
OUT="${TMPDIR:-/tmp}/AMSSeedboard-release"; mkdir -p "$OUT"
find . -path ./.git -prune -o -print0 | xargs -0 xattr -c 2>/dev/null || true
xcodegen generate >/dev/null
one() {   # one <ios|mac>
  local plat name
  if [ "$1" = ios ]; then plat="generic/platform=iOS"; name=ios; else plat="generic/platform=macOS"; name=mac; fi
  echo "== archive $name $BUILD"
  xcodebuild archive -project AMSSeedboard.xcodeproj -scheme AMSSeedboard -destination "$plat" \
    -archivePath "$OUT/$name.xcarchive" -derivedDataPath "$OUT/dd-$name" CURRENT_PROJECT_VERSION="$BUILD" \
    -allowProvisioningUpdates -authenticationKeyPath "$KEY" -authenticationKeyID 63M2792NNV -authenticationKeyIssuerID "$ISSUER" \
    2>&1 | grep -E "error:|warning: .*provision|ARCHIVE (SUCCEEDED|FAILED)" | sort -u
  echo "== upload $name"
  xcodebuild -exportArchive -archivePath "$OUT/$name.xcarchive" -exportOptionsPlist Tools/ExportOptions.plist -exportPath "$OUT/export-$name" \
    -allowProvisioningUpdates -authenticationKeyPath "$KEY" -authenticationKeyID 63M2792NNV -authenticationKeyIssuerID "$ISSUER" \
    2>&1 | grep -E "error:|EXPORT (SUCCEEDED|FAILED)|Upload" | sort -u
}
case "$WHAT" in ios) one ios;; mac) one mac;; *) one ios; one mac;; esac
if [ -z "$APP_ID" ]; then
  echo "APP_ID is empty: skipping the check of Apple's verdict and the release to testers. Fill in APP_ID in Tools/release.sh."
else
  echo "Now check GET /v1/apps/$APP_ID/buildUploads for Apple's verdict, then release-to-testers.py."
fi
