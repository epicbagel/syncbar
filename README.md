# Syncbar

Watch [Syncthing](https://syncthing.net) from the [Omarchy](https://omarchy.org)
bar: what each folder is doing, how far behind you are, and whether any peer is
actually connected.

## Why

A sync tool that has quietly stopped talking to its peers looks exactly like one
that has nothing to do. Both say "in sync". This separates them: folders can be
perfectly up to date locally while there is nobody to sync with, and the bar
goes urgent when that happens.

## Requirements

```bash
omarchy pkg add syncthing curl jq
```

Syncthing running under systemd `--user`, with its GUI enabled. The API key is
read from Syncthing's own `config.xml`; nothing needs configuring.

## Install

```bash
omarchy plugin add https://github.com/epicbagel/syncbar.git --enable
omarchy-restart-shell
```

The restart matters: `omarchy plugin update` reloads a plugin's service but
does not re-instantiate its bar widget.

## Use

Left click opens the panel; middle click triggers a rescan.

```bash
syncbar status     # one JSON object
syncbar rescan     # ask Syncthing to rescan every folder
syncbar open       # open the web UI
syncbar logs [n]
syncbar doctor
```

## Removing it

```bash
omarchy plugin remove io.github.epicbagel.syncbar
omarchy-restart-shell
rm -rf ~/.config/syncbar
```

## Notes

States, most alarming first: `error` (a folder reports errors), `syncing`
(bytes still to transfer, or a folder scanning), `disconnected` (in sync, but
no peer connected — switchable off), `ok`, and `offline`/`nokey` when Syncthing
is not answering or its config cannot be read.

The API key is read from Syncthing's `config.xml` and used only against
loopback. It is never printed, logged, or passed on a command line. The GUI
certificate is self-signed by design, so the request skips verification — it
never leaves the machine.

Two parsing details that are easy to get wrong: the GUI address must be read
from inside the `<gui>` element, because device entries carry their own
`<address>` tags and the first in the file is usually `dynamic`; and the scheme
comes from the `tls` attribute, since Syncthing redirects plain HTTP.

## License

MIT
