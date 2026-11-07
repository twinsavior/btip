#!/bin/sh
# btip Home: one install on a Mac. Paste the line from the btip page into Terminal, press Return, and wait
# about a minute. Nothing needs an admin password: everything goes into your own folders.
#
#   curl -fsSL https://twinsavior.github.io/btip/install.sh | sh             install, or update
#   curl -fsSL https://twinsavior.github.io/btip/install.sh | sh -s uninstall  remove all of it
#
# What it puts on this Mac:
#   ~/Applications/btip Home.app                 a small app, so macOS can ask you about Bluetooth by name
#   ~/Library/Application Support/btip/          its own Python, the btip code, the iroh transport, its settings
#   ~/Library/LaunchAgents/<label>.plist         starts btip Home when you log in
# Every Bluetooth device starts switched off for far ends. You switch each one on, on your own page.
#
# For tests: BTIP_DIR, BTIP_APPS, BTIP_LABEL, BTIP_PORT, BTIP_PAGE and BTIP_SRC (a .tar.gz path or URL) move
# each part, so a second copy can run next to a first one.
set -eu
VERSION=0.7.1
SRC="${BTIP_SRC:-https://twinsavior.github.io/btip/btip-home-$VERSION.tar.gz}"
SRC_SHA="e7fe3776cee64f6c0bc7ef4d89fb503c3ea305a0f2aca14a1cfd2606f225cbc6"        # build.sh writes the checksum of the published tarball here; a local test tarball is not checked
D="${BTIP_DIR:-$HOME/Library/Application Support/btip}"
APPS="${BTIP_APPS:-$HOME/Applications}"
LABEL="${BTIP_LABEL:-io.github.twinsavior.btip.home}"
PORT="${BTIP_PORT:-9100}"
APP="$APPS/btip Home.app"; AGENT="$HOME/Library/LaunchAgents/$LABEL.plist"; UID_=$(id -u)
PY_TAG=20261026; PY_VER=3.12.16
DP_VER=v0.40.1
T0=$(date +%s)

say() { printf '%s\n' "$*"; }
step() { printf '  %s\n' "$*"; }
die() { printf '\nbtip Home did not install: %s\n' "$*" >&2; exit 1; }
fetch() {        # fetch URL FILE SHA256
  curl -fsSL --retry 3 -o "$2" "$1" || die "could not download $1. Check this Mac is online, then paste the line again."
  if [ -n "$3" ]; then
    got=$(shasum -a 256 "$2" | cut -d' ' -f1)
    [ "$got" = "$3" ] || { rm -f "$2"; die "the download of $1 did not match its checksum, so nothing was installed. Paste the line again later."; }
  fi
}

if [ "${1:-}" = uninstall ]; then
  launchctl bootout "gui/$UID_/$LABEL" 2>/dev/null || launchctl bootout "user/$UID_/$LABEL" 2>/dev/null || true
  tccutil reset BluetoothAlways "$LABEL" >/dev/null 2>&1 || true
  rm -rf "$AGENT" "$APP" "$D"
  say "btip Home is gone from this Mac. Friends you invited can no longer reach it."
  exit 0
fi

[ "$(uname -s)" = Darwin ] || die "this installer is for a Mac."
MAJOR=$(sw_vers -productVersion | cut -d. -f1)
[ "$MAJOR" -ge 12 ] || die "btip Home needs macOS 12 or newer (this Mac has $(sw_vers -productVersion))."
case "$(uname -m)" in
  arm64) PY_ARCH=aarch64; PY_SHA=fbf4afef53c2a6b72bb741bc06d5671a9dfaf87bd84e5aa73ac9b3d0d589f14e
         DP_ARCH=darwin-aarch64; DP_SHA=e6bd3c9a98ba22e8233ae1f8ba5e2dceb4cbf132dc4d4332589295b702902a27 ;;
  x86_64) PY_ARCH=x86_64; PY_SHA=a962e47df522889eaa7ff0d6a56203f1079f68aabb65ffdbe8455f362bc769f3
          DP_ARCH=darwin-x86_64; DP_SHA=eaa35e228528cbf5fc2a8a07646570f49af6ab1acd35c8f539f150a0cb5d4b0e ;;
  *) die "unknown kind of Mac: $(uname -m)" ;;
esac

say "Installing btip Home $VERSION. This takes about a minute."
mkdir -p "$D/config" "$D/cache" "$D/bin" "$APPS" "$HOME/Library/LaunchAgents"
chmod 700 "$D/config"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

if [ ! -x "$D/python/bin/python3" ] || [ "$(cat "$D/python/.btip-version" 2>/dev/null)" != "$PY_VER+$PY_TAG" ]; then
  step "1 of 5  Python for btip Home (25 MB, its own copy; your Mac's Python is not touched)"
  fetch "https://github.com/astral-sh/python-build-standalone/releases/download/$PY_TAG/cpython-$PY_VER%2B$PY_TAG-$PY_ARCH-apple-darwin-install_only.tar.gz" "$TMP/py.tgz" "$PY_SHA"
  rm -rf "$D/python"; tar -xzf "$TMP/py.tgz" -C "$D"; echo "$PY_VER+$PY_TAG" > "$D/python/.btip-version"
else step "1 of 5  Python for btip Home: already here"; fi

step "2 of 5  Bluetooth libraries (bleak, PyObjC)"
"$D/python/bin/python3" -m pip install -q --disable-pip-version-check --no-warn-script-location --only-binary :all: "bleak==3.0.2" >"$TMP/pip.log" 2>&1 \
  || { tail -5 "$TMP/pip.log" >&2; die "the Bluetooth libraries did not install. Check this Mac is online, then paste the line again."; }

step "3 of 5  The iroh transport, so friends can reach this Mac from anywhere"
if [ "$("$D/bin/dumbpipe" --version 2>/dev/null | awk '{print "v"$2}')" != "$DP_VER" ]; then
  fetch "https://github.com/n0-computer/dumbpipe/releases/download/$DP_VER/dumbpipe-$DP_VER-$DP_ARCH.tar.gz" "$TMP/dp.tgz" "$DP_SHA"
  tar -xzf "$TMP/dp.tgz" -C "$TMP" && mv "$TMP/dumbpipe" "$D/bin/dumbpipe" && chmod 755 "$D/bin/dumbpipe"
fi

step "4 of 5  btip Home itself"
case "$SRC" in
  http*) fetch "$SRC" "$TMP/app.tgz" "$SRC_SHA" ;;
  *) cp "$SRC" "$TMP/app.tgz" ;;
esac
rm -rf "$TMP/app"; mkdir "$TMP/app"; tar -xzf "$TMP/app.tgz" -C "$TMP/app"
rm -rf "$D/app"; mv "$TMP/app/app" "$D/app"
cp "$TMP/app/run-home" "$D/run-home"; chmod 755 "$D/run-home"
echo "$PORT" > "$D/config/port"; echo "$LABEL" > "$D/config/label"
if [ -n "${BTIP_PAGE:-}" ]; then echo "$BTIP_PAGE" > "$D/config/page"; else rm -f "$D/config/page"; fi
launchctl bootout "gui/$UID_/$LABEL" 2>/dev/null || launchctl bootout "user/$UID_/$LABEL" 2>/dev/null || true
rm -rf "$APP"; cp -R "$TMP/app/btip Home.app" "$APP"
if [ "$LABEL" != io.github.twinsavior.btip.home ]; then        # a second copy for tests: its own name for macOS's privacy list
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $LABEL" "$APP/Contents/Info.plist"
  codesign -s - --force "$APP" >/dev/null 2>&1 || die "codesign could not sign the test copy"
fi
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true

step "5 of 5  Start at login, then start now"
cat > "$AGENT" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>$LABEL</string>
<key>ProgramArguments</key><array><string>$APP/Contents/MacOS/btip-home</string><string>serve</string></array>
<key>EnvironmentVariables</key><dict><key>BTIP_DIR</key><string>$D</string></dict>
<key>AssociatedBundleIdentifiers</key><string>$LABEL</string>
<key>RunAtLoad</key><true/>
<key>KeepAlive</key><true/>
<key>ThrottleInterval</key><integer>10</integer>
<key>StandardOutPath</key><string>$D/cache/serve.out</string>
<key>StandardErrorPath</key><string>$D/cache/serve.out</string>
</dict></plist>
PLIST
: > "$D/cache/serve.out"        # READY must come from this start, not an earlier one
launchctl bootstrap "gui/$UID_" "$AGENT" 2>/dev/null || launchctl bootstrap "user/$UID_" "$AGENT" || die "macOS did not accept the login item. Paste the line again; if it still fails, restart the Mac and paste it once more."

i=0; while [ $i -lt 120 ]; do grep -q "READY" "$D/cache/serve.out" 2>/dev/null && break; i=$((i+1)); sleep 0.5; done
grep -q "READY" "$D/cache/serve.out" 2>/dev/null || { tail -5 "$D/cache/serve.out" >&2; die "btip Home did not start. The lines above say why."; }
say ""
say "btip Home is running ($(( $(date +%s) - T0 )) s)."
say "It lives in your menu bar (the radio-waves icon): a switch for each device, who has a link, pause, share."
say "If macOS asks whether btip Home may use Bluetooth, click Allow."
if [ -z "${BTIP_NO_OPEN:-}" ]; then
  BTIP_DIR="$D" "$D/run-home" && say "Your page is open in your browser. Switch on the devices to share, then press Make a link and send it to your friend."
fi
say "To open your page again later: open btip Home in your Applications folder. To remove everything, paste:"
say "  curl -fsSL https://twinsavior.github.io/btip/install.sh | sh -s uninstall"
