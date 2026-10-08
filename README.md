# Transmission for Noctalia

Monitor and control a local or remote [Transmission](https://transmissionbt.com) daemon from Noctalia v5.

- **Bar widget** (`mindows/transmission:speed`): ↓/↑ rates (refreshed every background interval, 5 min by default), totals in the tooltip, click to open the panel.
- **Panel** (`mindows/transmission:panel`): live torrent list (refreshed every 3 s while open) with progress, status and ETA; pause/resume per torrent or all at once.
- **Control-center tile** (`mindows/transmission:altspeed`): toggles Transmission's alternative ("turtle") speed limits.
- **Service** (`mindows/transmission:service`): polls the RPC and feeds the widget and tile.

Talks to the daemon's HTTP RPC directly; `transmission-remote` is not required.

## Setup

1. Put the RPC password in a file (default `~/.config/noctalia-transmission/password`):

   ```sh
   mkdir -p ~/.config/noctalia-transmission
   install -m 600 /dev/null ~/.config/noctalia-transmission/password
   $EDITOR ~/.config/noctalia-transmission/password
   ```

2. In **Settings → Plugins → Transmission** (gear icon), set the host, port, and username. Or in `config.toml`:

   ```toml
   [plugin_settings."mindows/transmission"]
   host = "192.168.55.240"
   port = 9091
   username = "transmission"
   ```

   Leave the username empty if the daemon has `rpc-authentication-required` off.

3. Add the **Transmission** widget to a bar and/or the **Alt speed** tile to the control center.

The daemon must allow your machine in `rpc-whitelist` (or have the whitelist disabled).

## Development

```sh
ln -s "$PWD" ~/.local/share/noctalia/plugins/transmission
noctalia msg plugins enable mindows/transmission

noctalia msg plugin mindows/transmission:service all refresh
noctalia msg panel-toggle mindows/transmission:panel
grep -E 'transmission|mindows' ~/.cache/noctalia/noctalia.log | tail
```

`.luau` edits hot-reload; `plugin.toml` changes apply on the next config reload (`noctalia msg config-reload`).
A newly added widget setting is not seen by existing bar widgets until the plugin is disabled and re-enabled.
