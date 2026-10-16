#!/bin/zsh
set -euo pipefail

root="${0:A:h:h}"
out="$root/build/release"
profile="${CYTE_NOTARY_PROFILE:-cyte-notary}"
team="${CYTE_TEAM_ID:-}"
identity="Developer ID Application"

usage() {
  cat <<EOF
Builds, signs, notarizes and staples Cyte into a DMG at build/release.

One-time setup, after joining the Apple Developer Program:
  1. Xcode > Settings > Accounts > Manage Certificates > + > Developer ID Application
  2. xcrun notarytool store-credentials $profile --apple-id YOU@EMAIL --team-id TEAMID
     (use an app-specific password from account.apple.com)

Run:
  CYTE_TEAM_ID=TEAMID scripts/release.sh          full release
  CYTE_TEAM_ID=TEAMID scripts/release.sh --check  check the setup only
EOF
}

fail() { print -u2 "release: $1"; exit 1; }

check() {
  [[ -n "$team" ]] || { usage; fail "set CYTE_TEAM_ID to your 10-character team ID"; }
  security find-identity -v -p codesigning | grep -q "$identity: .*($team)" \
    || fail "no '$identity' certificate for team $team in your keychain"
  xcrun notarytool history --keychain-profile "$profile" >/dev/null 2>&1 \
    || fail "notary profile '$profile' is missing; run: xcrun notarytool store-credentials $profile"
  print "release: setup looks good for team $team"
}

notarize() {
  xcrun notarytool submit "$1" --keychain-profile "$profile" --wait --timeout 30m \
    | tee "$out/notary.log"
  grep -q "status: Accepted" "$out/notary.log" || fail "Apple rejected $1; see $out/notary.log"
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && { usage; exit 0; }
check
[[ "${1:-}" == "--check" ]] && exit 0

cd "$root"
xcodegen generate >/dev/null
rm -rf "$out" && mkdir -p "$out"

xcodebuild test -project Pool.xcodeproj -scheme Pool -destination 'platform=macOS' -derivedDataPath "$out/dd" -quiet \
  || fail "tests failed; nothing was built"

xcodebuild archive -project Pool.xcodeproj -scheme Pool -configuration Release \
  -archivePath "$out/Cyte.xcarchive" -derivedDataPath "$out/dd" -quiet \
  DEVELOPMENT_TEAM="$team" CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$identity" \
  OTHER_CODE_SIGN_FLAGS="--timestamp"

cat > "$out/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>$team</string>
  <key>signingStyle</key><string>manual</string>
  <key>signingCertificate</key><string>$identity</string>
</dict>
</plist>
EOF
xcodebuild -exportArchive -archivePath "$out/Cyte.xcarchive" -exportPath "$out/export" \
  -exportOptionsPlist "$out/ExportOptions.plist" -quiet

app="$out/export/Cyte.app"
version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$app/Contents/Info.plist")
build=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$app/Contents/Info.plist")

codesign --verify --deep --strict "$app"
ditto -c -k --keepParent "$app" "$out/Cyte.zip"
notarize "$out/Cyte.zip"
xcrun stapler staple "$app"

stage="$out/dmg"
mkdir -p "$stage"
cp -R "$app" "$stage/"
ln -s /Applications "$stage/Applications"
dmg="$out/Cyte-$version-$build.dmg"
hdiutil create -volname "Cyte" -srcfolder "$stage" -format UDZO -ov "$dmg" >/dev/null
sign_id=$(security find-identity -v -p codesigning | grep "$identity: .*($team)" | head -1 | awk '{print $2}')
codesign --sign "$sign_id" --timestamp "$dmg"
notarize "$dmg"
xcrun stapler staple "$dmg"

spctl --assess --type execute -vv "$app"
spctl --assess --type open --context context:primary-signature -vv "$dmg"
print "release: $dmg is signed, notarized and stapled"
