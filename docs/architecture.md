# Architecture

## Product goal

Build a simplified Xray client with UX closer to Hiddify than to classic raw-config clients.

## Layers

### Flutter app

- Presents a small number of screens
- Hides raw Xray details by default
- Edits an application-level config model instead of Xray JSON

### Go core manager

- Persists application config
- Generates Xray config from the simplified model
- Starts/stops Xray later
- Exposes logs, health checks, and profile refresh later

### Xray runtime

- Source checkout lives in `xray_runtime/xray-core`
- Bundled per-platform binaries should live in `xray_runtime/bin/<platform>`
- Driven only by generated config

## Routing model

- `global`: everything through proxy unless blocked explicitly
- `whitelist`: only `proxyDomains` use proxy; the rest go direct
- `blacklist`: `directDomains` bypass proxy; the rest use proxy

Blocked domains always map to a `blackhole` outbound.

## DNS model

- `auto`: default DNS plus domain strategy `AsIs`
- `proxy`: prefer remote/public resolvers through the proxy path
- `direct`: prefer local/direct resolution

The exact DNS wiring should be revisited once TUN mode is added.
