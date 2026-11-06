# btip far page and installer

This repository is the btip web site: one static page, the iroh module it loads (WebAssembly), and the files the one-line Mac install downloads.

## The far page

The page reaches a btip home over iroh's public relay, straight from the browser.

The page holds no key. A home's owner makes a link for one person. The link is this page's address plus `#ticket=...&t=...`. Browsers keep the part after `#` to themselves, so the server that hosts this page never sees it.

Each device at the home stays off until its owner switches it on, and the owner can remove a link at any time.

## The Mac install

Paste this line into Terminal on a Mac (macOS 12 or newer):

```bash
curl -fsSL https://twinsavior.github.io/btip/install.sh | sh
```

| File | What it is |
|---|---|
| `install.sh` | the script that line runs. It checks the checksum of everything it downloads |
| `btip-home-0.7.0.tar.gz` | the btip code, the keyboard helper and the btip Home menu bar app |
| `btip-eyes-1-arm64.tar.gz` | the screen receiver (UxPlay and GStreamer). A home downloads it only when it drives a tablet's screen |

To remove all of it: `curl -fsSL https://twinsavior.github.io/btip/install.sh | sh -s uninstall`

## Licences and source

btip is MIT. The screen receiver holds GPL and LGPL parts: UxPlay (GPL-3.0, with two small btip patches), GStreamer, GLib and gettext's libintl (LGPL). Their licence texts are inside the download, in `eyes/licenses/`, and `eyes/SOURCES.txt` names every part, its version and its source. The full source of each GPL and LGPL part, and the patched UxPlay tree, is in the release [eyes-sources-1](https://github.com/twinsavior/btip/releases/tag/eyes-sources-1).
