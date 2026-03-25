# Xray Runtime

This directory contains the upstream `XTLS/Xray-core` checkout used by the app runtime layer.

## Layout

```text
xray_runtime/
  xray-core/   upstream source checkout
  bin/         future build or downloaded binaries per platform
```

## Why it is separate

`core_manager` should orchestrate Xray as an external process instead of importing it as an internal Go package. That keeps:

- upgrades of upstream Xray isolated
- app config separate from raw Xray internals
- cross-platform bundling simpler for Flutter releases

## Current upstream revision

`e86c36557241dc43989887a6006d8464d234fd27`

## Next step

Add a build or fetch script that produces:

```text
xray_runtime/bin/windows/xray.exe
xray_runtime/bin/linux/xray
xray_runtime/bin/macos/xray
```
