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
# 0.5: the share page (AMSSeedboardShare, com.schabbauer.AMSSeedboard.Share) is a second bundle inside the app. The
# archive signs it with the same key (automatic signing covers every target). Apple refuses an upload whose share
# page is missing or carries another version or build than the app: checked here, before the upload.
plist_of() { if [ -f "$1/Contents/Info.plist" ]; then echo "$1/Contents/Info.plist"; else echo "$1/Info.plist"; fi; }
check_share() {   # check_share <archive>
  local app ext av ab ev eb rights
  app=$(find "$1/Products/Applications" -maxdepth 1 -name "*.app" | head -1)
  ext=$(find "$app" -name "AMSSeedboardShare.appex" | head -1)
  if [ -z "$ext" ]; then echo "error: the share page is not inside the app"; return 1; fi
  av=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$(plist_of "$app")")
  ab=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$(plist_of "$app")")
  ev=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$(plist_of "$ext")")
  eb=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$(plist_of "$ext")")
  if [ "$av" != "$ev" ] || [ "$ab" != "$eb" ]; then
    echo "error: the app is $av ($ab) but its share page is $ev ($eb)"; return 1
  fi
  rights=$(codesign -d --entitlements - "$ext" 2>/dev/null || true)
  echo "share page: $ev ($eb), keychain group $(echo "$rights" | grep -q "keychain-access-groups" && echo yes || echo NO), shared folder $(echo "$rights" | grep -q "group.com.schabbauer.amspara" && echo yes || echo "no (words and links only)")"
}
one() {   # one <ios|mac>
  local plat name
  if [ "$1" = ios ]; then plat="generic/platform=iOS"; name=ios; else plat="generic/platform=macOS"; name=mac; fi
  echo "== archive $name $BUILD"
  xcodebuild archive -project AMSSeedboard.xcodeproj -scheme AMSSeedboard -destination "$plat" \
    -archivePath "$OUT/$name.xcarchive" -derivedDataPath "$OUT/dd-$name" CURRENT_PROJECT_VERSION="$BUILD" \
    -allowProvisioningUpdates -authenticationKeyPath "$KEY" -authenticationKeyID 63M2792NNV -authenticationKeyIssuerID "$ISSUER" \
    2>&1 | grep -E "error:|warning: .*provision|ARCHIVE (SUCCEEDED|FAILED)" | sort -u
  check_share "$OUT/$name.xcarchive"
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
