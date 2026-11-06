# btip far page

This repository holds one static page and the iroh module it loads (WebAssembly). The page reaches a btip home over iroh's public relay, straight from the browser.

The page holds no key. A home's owner makes a link for one person. The link is this page's address plus `#ticket=...&t=...`. Browsers keep the part after `#` to themselves, so the server that hosts this page never sees it.

Each device at the home stays off until its owner switches it on, and the owner can remove a link at any time.
