#!/usr/bin/env bash
set -euo pipefail
umask 077
signing_dir="$(mktemp -d "$RUNNER_TEMP/las-signing.XXXXXX")"
keychain="$signing_dir/build.keychain-db"
profile_path=''
cleanup() {
  security delete-keychain "$keychain" >/dev/null 2>&1 || true
  if [[ -n "$profile_path" ]]; then rm -f -- "$profile_path"; fi
  rm -rf -- "$signing_dir"
}
trap cleanup EXIT
export LAS_SIGNING_DIR="$signing_dir"
python3 - <<'PY'
import base64, os, pathlib, re
p = pathlib.Path(os.environ['LAS_SIGNING_DIR'])
names = ['IOS_DISTRIBUTION_P12_BASE64', 'IOS_DISTRIBUTION_P12_PASSWORD',
         'IOS_PROVISION_PROFILE_BASE64', 'APP_STORE_CONNECT_KEY_ID',
         'APP_STORE_CONNECT_ISSUER_ID', 'APP_STORE_CONNECT_PRIVATE_KEY']
for name in names:
    if not os.environ.get(name, '').strip():
        raise SystemExit('Missing GitHub secret: ' + name)
keyid = os.environ['APP_STORE_CONNECT_KEY_ID']
if not re.fullmatch(r'[A-Z0-9]{10}', keyid):
    raise SystemExit('Invalid API key ID')
for name, filename in [('IOS_DISTRIBUTION_P12_BASE64','distribution.p12'),
                       ('IOS_PROVISION_PROFILE_BASE64','profile.mobileprovision')]:
    (p/filename).write_bytes(base64.b64decode(''.join(os.environ[name].split()), validate=True))
(p / ('AuthKey_' + keyid + '.p8')).write_text(os.environ['APP_STORE_CONNECT_PRIVATE_KEY'].strip()+'\n')
PY
security cms -D -i "$signing_dir/profile.mobileprovision" > "$signing_dir/profile.plist"
python3 - <<'PY'
import datetime, os, pathlib, plistlib, re
p=pathlib.Path(os.environ['LAS_SIGNING_DIR'])
profile=plistlib.loads((p/'profile.plist').read_bytes())
assert profile['TeamIdentifier']==['QSNN5PDQ84'], 'Wrong Apple team'
assert profile['Entitlements']['application-identifier']=='QSNN5PDQ84.com.lastoptechnik.lasCustomer', 'Wrong App ID'
assert not profile['Entitlements'].get('get-task-allow'), 'Development profile is not accepted'
assert not profile.get('ProvisionedDevices') and not profile.get('ProvisionsAllDevices'), 'App Store profile required'
assert profile['ExpirationDate']>datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None), 'Expired profile'
assert re.fullmatch(r'[a-fA-F0-9-]{36}',profile['UUID']), 'Invalid profile UUID'
(p/'uuid').write_text(profile['UUID'])
options={'method':'app-store-connect','teamID':'QSNN5PDQ84','signingStyle':'manual',
         'signingCertificate':'Apple Distribution','manageAppVersionAndBuildNumber':False,
         'uploadSymbols':True,'provisioningProfiles':{'com.lastoptechnik.lasCustomer':profile['UUID']}}
(p/'ExportOptions.plist').write_bytes(plistlib.dumps(options))
PY
profile_uuid="$(cat "$signing_dir/uuid")"
profile_path="$HOME/Library/MobileDevice/Provisioning Profiles/$profile_uuid.mobileprovision"
mkdir -p "$(dirname "$profile_path")"
cp "$signing_dir/profile.mobileprovision" "$profile_path"
keychain_password="$(openssl rand -hex 32)"
security create-keychain -p "$keychain_password" "$keychain"
security set-keychain-settings -lut 21600 "$keychain"
security unlock-keychain -p "$keychain_password" "$keychain"
security import "$signing_dir/distribution.p12" -k "$keychain" -P "$IOS_DISTRIBUTION_P12_PASSWORD" -T /usr/bin/codesign -T /usr/bin/security >/dev/null
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$keychain_password" "$keychain" >/dev/null
security list-keychains -d user -s "$keychain" "$HOME/Library/Keychains/login.keychain-db"
export LAS_PROFILE_UUID="$profile_uuid"
ruby - <<'RUBY'
require 'xcodeproj'
project = Xcodeproj::Project.open('ios/Runner.xcodeproj')
runner = project.targets.find { |t| t.name == 'Runner' }
raise 'Runner target missing' unless runner
runner.build_configurations.each do |config|
  config.build_settings['DEVELOPMENT_TEAM'] = 'QSNN5PDQ84'
  config.build_settings['CODE_SIGN_STYLE'] = 'Manual'
  config.build_settings['CODE_SIGN_IDENTITY'] = 'Apple Distribution'
  config.build_settings['CODE_SIGN_IDENTITY[sdk=iphoneos*]'] = 'Apple Distribution'
  config.build_settings['PROVISIONING_PROFILE_SPECIFIER'] = ENV.fetch('LAS_PROFILE_UUID')
end
project.save
RUBY
/usr/libexec/PlistBuddy -c 'Set :CFBundleDisplayName My LAS' ios/Runner/Info.plist
build_number="$((100 + GITHUB_RUN_NUMBER)).$GITHUB_RUN_ATTEMPT"
flutter build ipa --release --no-pub --build-name=1.0.0 --build-number="$build_number" \
  --dart-define=ENABLE_PUSH=false --dart-define=ENABLE_DEVICE_LOGIN="${ENABLE_DEVICE_LOGIN:-false}" --dart-define=PORTAL_ORIGIN=https://dms.lastoptechnik.com \
  --export-options-plist="$signing_dir/ExportOptions.plist"
shopt -s nullglob
ipas=(build/ios/ipa/*.ipa)
[[ ${#ipas[@]} -eq 1 ]] || { echo 'Expected one signed IPA'; exit 1; }
export API_PRIVATE_KEYS_DIR="$signing_dir"
xcrun altool --validate-app --type ios --file "${ipas[0]}" --apiKey "$APP_STORE_CONNECT_KEY_ID" --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID"
xcrun altool --upload-app --type ios --file "${ipas[0]}" --apiKey "$APP_STORE_CONNECT_KEY_ID" --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID"
echo "Uploaded My LAS 1.0.0 ($build_number). Apple processing is still required." >> "$GITHUB_STEP_SUMMARY"
