#!/usr/bin/env bash
# Compila, firma y sube la app de iOS a TestFlight, sin abrir Xcode ni iniciar sesión con Apple ID.
# Adaptado de gupp-app/tool/testflight.sh y opentransit-mobile/tool/testflight.sh (misma cuenta de Apple: Jerónimo, 6DTDJCKC8X).
# MZD Owner embebe una extensión (widget + Live Activity), que necesita su propio perfil, y ambos
# usan el App Group group.com.jeronimotech.mzdOwner (capacidad APP_GROUPS en los dos bundle ids).
#
# Firma manual: el certificado de distribución y el perfil App Store se crean con la API de App Store
# Connect (basta una llave con rol App Manager) y la identidad vive en un llavero dedicado, que se
# puede desbloquear desde un script. MZD Owner comparte con las otras apps de Jerónimo ese certificado
# y ese llavero (Apple limita cuántos certificados de distribución hay por cuenta).
#
# Variables (archivo privado, nunca en el repo; por defecto ~/.config/mzd-owner/apple.env):
#   APPLE_TEAM_ID, ASC_KEY_ID, ASC_ISSUER_ID
# Opcionales:
#   MZD_ENV           archivo con MZD_BRIDGE_TOKEN (por defecto ~/dev/projects/mazda/.env)
#   MZD_BRIDGE_URL    puente del asistente (por defecto el de Railway)
#   DIST_DIR, KEYCHAIN_NAME, KEYCHAIN_ENV   identidad de firma compartida (por defecto la de opentransit)
#   BUILD_NUMBER      por defecto, minutos desde 1970: siempre sube
#   BUILD_NAME        por defecto, la versión de pubspec.yaml
#   WAIT_MINUTES      cuánto esperar a que App Store Connect procese la build (20; 0 = no esperar)
#
# Uso:
#   tool/testflight.sh              firma, compila, sube y espera a que la build quede VALID
#   tool/testflight.sh --no-upload  se detiene con el .ipa en build/ios/ipa/
set -euo pipefail
export LANG="${LANG:-en_US.UTF-8}"   # CocoaPods necesita UTF-8
cd "$(dirname "$0")/.."

UPLOAD=1
[[ "${1:-}" == "--no-upload" ]] && UPLOAD=0

APPLE_ENV="${APPLE_ENV:-$HOME/.config/mzd-owner/apple.env}"
# shellcheck disable=SC1090
[[ -f "$APPLE_ENV" ]] && { set -a; source "$APPLE_ENV"; set +a; }

: "${APPLE_TEAM_ID:?falta APPLE_TEAM_ID (ver $APPLE_ENV)}"
: "${ASC_KEY_ID:?falta ASC_KEY_ID}"
: "${ASC_ISSUER_ID:?falta ASC_ISSUER_ID}"
ASC_KEY_PATH="${ASC_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8}"
[[ -f "$ASC_KEY_PATH" ]] || { echo "no está la llave de la API: $ASC_KEY_PATH" >&2; exit 1; }
export ASC_KEY_PATH APPLE_TEAM_ID ASC_KEY_ID ASC_ISSUER_ID

BUNDLE_ID="com.jeronimotech.mzdOwner"
PROFILE_NAME="${PROFILE_NAME:-MZD Owner App Store}"
WIDGET_ID="$BUNDLE_ID.MiMazdaWidget"
WIDGET_PROFILE="${WIDGET_PROFILE:-MZD Owner Widget App Store}"
export BUNDLE_ID PROFILE_NAME
DIST_DIR="${DIST_DIR:-$HOME/.config/opentransit/apple-dist}"
KEYCHAIN_NAME="${KEYCHAIN_NAME:-opentransit-signing}"
KEYCHAIN_ENV="${KEYCHAIN_ENV:-$HOME/.config/opentransit/keychain.env}"
KEYCHAIN_PATH="$HOME/Library/Keychains/$KEYCHAIN_NAME.keychain-db"
MZD_ENV="${MZD_ENV:-$HOME/dev/projects/mazda/.env}"
# shellcheck disable=SC1090
[[ -f "$MZD_ENV" ]] && { set -a; source "$MZD_ENV"; set +a; }
: "${MZD_BRIDGE_TOKEN:?falta MZD_BRIDGE_TOKEN (ver $MZD_ENV)}"
MZD_BRIDGE_URL="${MZD_BRIDGE_URL:-https://mzd-bridge-production.up.railway.app}"
BUILD_NUMBER="${BUILD_NUMBER:-$(( $(date +%s) / 60 ))}"
BUILD_NAME="${BUILD_NAME:-$(sed -n 's/^version: *\([0-9.]*\).*/\1/p' pubspec.yaml)}"
WAIT_MINUTES="${WAIT_MINUTES:-20}"

ARCHIVE=build/ios/archive/Runner.xcarchive
EXPORT_DIR=build/ios/ipa
EXPORT_PLIST=build/ios/ExportOptions.plist
ASC="python3 tool/asc_signing.py"

echo "==> MZD Owner iOS $BUILD_NAME ($BUILD_NUMBER) · $BUNDLE_ID · equipo $APPLE_TEAM_ID · puente $MZD_BRIDGE_URL"

json_field() { python3 -c 'import json,sys; d=json.load(sys.stdin); print(d[sys.argv[1]] or "")' "$1"; }

prepare_signing() {
  [[ -f "$KEYCHAIN_ENV" ]] && { set -a; # shellcheck disable=SC1090
    source "$KEYCHAIN_ENV"; set +a; }
  : "${KEYCHAIN_PW:?no hay KEYCHAIN_PW en $KEYCHAIN_ENV; corre primero el testflight.sh de opentransit}"
  [[ -f "$KEYCHAIN_PATH" && -f "$DIST_DIR/dist.csr" ]] || {
    echo "no está el llavero $KEYCHAIN_PATH o $DIST_DIR/dist.csr" >&2; exit 1; }
  security unlock-keychain -p "$KEYCHAIN_PW" "$KEYCHAIN_PATH"
  security set-keychain-settings -t 3600 "$KEYCHAIN_PATH"
  # shellcheck disable=SC2046
  security list-keychains -d user -s "$KEYCHAIN_PATH" $(security list-keychains -d user | tr -d '" ' | grep -v "$KEYCHAIN_NAME")

  echo "==> App Store Connect: bundle ids (app + widget, con App Groups)"
  BUNDLE_CAPABILITIES=APP_GROUPS $ASC bundle-id --name "MZD Owner" > build/asc-bundle.json
  BUNDLE_ID="$WIDGET_ID" BUNDLE_CAPABILITIES=APP_GROUPS $ASC bundle-id --name "MZD Owner Widget" > /dev/null
  echo "==> App Store Connect: certificado de distribución"
  $ASC certificate --csr "$DIST_DIR/dist.csr" --out "$DIST_DIR/dist.cer" > build/asc-cert.json
  CERT_ID=$(json_field id < build/asc-cert.json)
  echo "==> App Store Connect: perfil \"$PROFILE_NAME\""
  $ASC profile --cert-id "$CERT_ID" --name "$PROFILE_NAME" --install > build/asc-profile.json
  echo "==> App Store Connect: perfil \"$WIDGET_PROFILE\""
  BUNDLE_ID="$WIDGET_ID" $ASC profile --cert-id "$CERT_ID" --name "$WIDGET_PROFILE" --install > /dev/null

  openssl x509 -inform DER -in "$DIST_DIR/dist.cer" -out "$DIST_DIR/dist.pem" 2>/dev/null
  CERT_CN=$(openssl x509 -in "$DIST_DIR/dist.pem" -noout -subject -nameopt RFC2253 | sed -n 's/.*CN=\([^,]*\).*/\1/p')
  security find-identity -v -p codesigning "$KEYCHAIN_PATH" | grep -q "$CERT_CN" || {
    echo "la identidad $CERT_CN no está en $KEYCHAIN_NAME; corre el testflight.sh de opentransit" >&2; exit 1; }
  SIGN_IDENTITY_PREFIX=$(echo "$CERT_CN" | sed 's/:.*//')   # "Apple Distribution"
  echo "==> firma: $CERT_CN · perfil $PROFILE_NAME"
}

# Desde cero: Flutter reutiliza binarios nativos de compilaciones de simulador y App Store Connect
# los rechaza (ITMS-91169).
flutter clean >/dev/null
mkdir -p build
flutter pub get >/dev/null

DEFINES=(--dart-define="MZD_BRIDGE_URL=$MZD_BRIDGE_URL" --dart-define="MZD_BRIDGE_TOKEN=$MZD_BRIDGE_TOKEN")
flutter build ios --release --no-codesign "${DEFINES[@]}" --build-name="$BUILD_NAME" --build-number="$BUILD_NUMBER"

prepare_signing

# La firma manual se pone solo en el target Runner: si va en la línea de comandos de xcodebuild
# aplica también a los pods, y estos rechazan perfiles. Se parcha el proyecto y se restaura al final.
PBXPROJ=ios/Runner.xcodeproj/project.pbxproj
cp "$PBXPROJ" build/project.pbxproj.bak
restore_pbxproj() { [[ -f build/project.pbxproj.bak ]] && mv build/project.pbxproj.bak "$PBXPROJ"; }
trap restore_pbxproj EXIT
PBXPROJ="$PBXPROJ" SIGN_IDENTITY_PREFIX="$SIGN_IDENTITY_PREFIX" WIDGET_ID="$WIDGET_ID" WIDGET_PROFILE="$WIDGET_PROFILE" python3 - <<'PY'
import os, re
p = os.environ["PBXPROJ"]; s = open(p).read()
ident = os.environ["SIGN_IDENTITY_PREFIX"]
profiles = {os.environ["BUNDLE_ID"]: os.environ["PROFILE_NAME"], os.environ["WIDGET_ID"]: os.environ["WIDGET_PROFILE"]}
n = 0
def patch(m):
    global n
    block = m.group(0)
    # El id más largo primero: el de la app es prefijo del de la extensión.
    for bid in sorted(profiles, key=len, reverse=True):
        if "PRODUCT_BUNDLE_IDENTIFIER = %s;" % bid in block:
            break
    else:
        return block
    settings = {
        "CODE_SIGN_STYLE": "Manual",
        "DEVELOPMENT_TEAM": os.environ["APPLE_TEAM_ID"],
        "CODE_SIGN_IDENTITY": '"%s"' % ident,
        '"CODE_SIGN_IDENTITY[sdk=iphoneos*]"': '"%s"' % ident,
        "PROVISIONING_PROFILE_SPECIFIER": '"%s"' % profiles[bid],
    }
    indent = re.search(r"^(\t+)buildSettings = \{\n", block, re.M).group(1) + "\t"
    for k, v in settings.items():
        line = "%s%s = %s;" % (indent, k, v)
        pat = re.compile(r"^\s*%s = [^;]*;$" % re.escape(k), re.M)
        if pat.search(block):
            block = pat.sub(line, block)
        else:
            at = re.search(r"^(\t+)buildSettings = \{\n", block, re.M).end()
            block = block[:at] + line + "\n" + block[at:]
    n += 1
    return block
s = re.sub(r"\t\t[0-9A-F]{24} /\* (Release|Profile) \*/ = \{\n\t\t\tisa = XCBuildConfiguration;.*?\n\t\t\};",
           patch, s, flags=re.S)
# A nivel de proyecto Flutter deja "iPhone Developer" para iphoneos y le gana al target.
s = re.sub(r'^(\t+)"CODE_SIGN_IDENTITY\[sdk=iphoneos\*\]" = "iPhone Developer";$',
           lambda m: '%s"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "%s";' % (m.group(1), ident), s, flags=re.M)
open(p, "w").write(s)
assert n == 4, "esperaba Release y Profile de Runner y del widget, encontré %d" % n
PY

echo "==> archive"
set +e
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" archive \
  DEVELOPMENT_TEAM="$APPLE_TEAM_ID" OTHER_CODE_SIGN_FLAGS="--keychain $KEYCHAIN_PATH" \
  > build/xcodebuild-archive.log 2>&1
STATUS=$?
set -e
if [[ $STATUS -ne 0 ]]; then
  echo "!! falló el archive; log completo en build/xcodebuild-archive.log" >&2
  grep -E "error:|No profile|Provisioning" build/xcodebuild-archive.log | head -20 >&2
  exit 1
fi
restore_pbxproj; trap - EXIT

echo "==> export"
XCODE_MAJOR=$(xcodebuild -version | sed -n 's/^Xcode \([0-9]*\).*/\1/p')
EXPORT_PLIST="$EXPORT_PLIST" SIGN_IDENTITY_PREFIX="$SIGN_IDENTITY_PREFIX" XCODE_MAJOR="$XCODE_MAJOR" WIDGET_ID="$WIDGET_ID" WIDGET_PROFILE="$WIDGET_PROFILE" python3 - <<'PY'
import os, plistlib
opts = {
    "method": "app-store-connect" if int(os.environ["XCODE_MAJOR"] or 0) >= 15 else "app-store",
    "destination": "export",
    "signingStyle": "manual",
    "teamID": os.environ["APPLE_TEAM_ID"],
    "signingCertificate": os.environ["SIGN_IDENTITY_PREFIX"],
    "provisioningProfiles": {os.environ["BUNDLE_ID"]: os.environ["PROFILE_NAME"],
                             os.environ["WIDGET_ID"]: os.environ["WIDGET_PROFILE"]},
    "uploadSymbols": True,
    "manageAppVersionAndBuildNumber": False,
}
with open(os.environ["EXPORT_PLIST"], "wb") as fh:
    plistlib.dump(opts, fh)
PY
rm -rf "$EXPORT_DIR"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_PLIST" | tail -n 3
IPA=$(ls "$EXPORT_DIR"/*.ipa | head -n 1)
echo "==> $IPA ($(du -h "$IPA" | cut -f1))"

if [[ "$UPLOAD" -eq 0 ]]; then echo "==> --no-upload: no se subió"; exit 0; fi

echo "==> subiendo a App Store Connect"
xcrun altool --upload-app -f "$IPA" -t ios --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
if [[ "$WAIT_MINUTES" != "0" ]]; then
  $ASC builds --wait --version "$BUILD_NUMBER" --build-name "$BUILD_NAME" --timeout "$WAIT_MINUTES"
  echo "==> build $BUILD_NAME ($BUILD_NUMBER) lista: agrégala a un grupo de TestFlight."
else
  echo "==> subida; App Store Connect la procesa en 10-20 min (tool/asc_signing.py builds)"
fi
