# Xray Desktop

Cross-platform VPN client scaffold built around `Flutter + Go + Xray`.

The repository starts with a UI-first MVP:

- Flutter desktop/mobile shell with a Hiddify-like dashboard
- Go backend that stores app config and generates Xray routing config
- Shared JSON schema for future validation and migrations

## Structure

```text
app_ui/         Flutter app
core_manager/   Go backend/orchestrator
xray_runtime/   Xray-core source checkout and future bundled binaries
shared/         Shared schema and sample config
docs/           Architecture notes
```

## MVP scope

- One-click connect/disconnect
- Active profile selection
- Routing modes: `global`, `whitelist`, `blacklist`
- Domain lists: proxy/direct/block
- DNS mode toggle: `auto`, `proxy`, `direct`
- Toggle placeholders for system proxy, TUN, launch at startup
- Backend endpoint that renders an Xray JSON config from app state
- Vendored `XTLS/Xray-core` source under `xray_runtime/xray-core`

## Local run

### Flutter UI

1. Install Flutter SDK and add `flutter` to `PATH`
2. Start the backend from `core_manager/`
3. From `app_ui/`:

```bash
flutter pub get
flutter run -d windows
```

### Go backend

1. Install Go 1.22+ and add `go` to `PATH`
2. Build Xray from `xray_runtime/xray-core/`:

```bash
go build -o ../bin/windows/xray.exe ./main
```

3. From `core_manager/`:

```bash
go run ./cmd/core-manager
```

The backend listens on `127.0.0.1:8080`.

## Integration direction

- Flutter will talk to Go over localhost HTTP for the first iteration.
- Go will own app settings, Xray config generation, process lifecycle, and logs.
- `XTLS/Xray-core` source is checked out separately in `xray_runtime/xray-core`.
- `core_manager` now launches `xray_runtime/bin/windows/xray.exe` on `connect`, writes the generated config to the temp directory, and exposes runtime status/logs back to Flutter.
- The next integration step is to replace placeholder profiles with real imported `vmess/vless/trojan/reality` endpoints and add system proxy or TUN plumbing.

## Status

This repository was created manually because `flutter` and `go` were not available in `PATH` in the current environment, so the project could not be bootstrapped with the official CLIs here.
