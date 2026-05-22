# nearme

A CLI tool that searches for places near given coordinates using native OS APIs. On macOS, wraps MKLocalSearch (MapKit). No API keys, no cloud accounts.

Companion to [whereami](https://github.com/georgemandis/whereami).

## Install

Requires Zig 0.16.0 and macOS.

```bash
git clone https://github.com/georgemandis/nearme.git
cd nearme
zig build
```

The binary is at `zig-out/bin/nearme`. Copy it to your PATH or run via `zig build run`.

## Usage

```bash
# Search with explicit coordinates
nearme "pizza" --lat=40.6892 --lon=-73.9857

# Pipe from whereami
whereami --json | nearme "coffee"

# JSON output
whereami --json | nearme "pharmacy" --json

# Limit results
nearme "restaurant" --lat=40.7128 --lon=-74.0060 --count=5

# Custom search radius (meters)
nearme "gas station" --lat=40.7128 --lon=-74.0060 --radius=5000
```

### Options

```
Usage: nearme <query> [options]

Arguments:
  <query>              What to search for (e.g. "pizza", "coffee", "pharmacy")

Options:
  --lat=N              Latitude
  --lon=N              Longitude
  --radius=N           Search radius in meters (default: 2000)
  --count=N            Max results (default: 10)
  --json               Output as JSON
  -h, --help           Show help
  -v, --version        Show version
```

### Coordinates

Three ways to provide coordinates, checked in order:

1. `--lat` and `--lon` flags (highest priority)
2. Piped JSON on stdin — compatible with `whereami --json` output
3. Neither provided — prints usage and exits

## How it works

On macOS, nearme uses MapKit's `MKLocalSearch` API through the Objective-C runtime. This is the same search that powers Apple Maps. No API keys needed — it's a system framework.

The tool is macOS-only because MKLocalSearch is an Apple API. There are no equivalent native place search APIs on Windows or Linux.

## Credits

Created by [George Mandis](https://george.mand.is).
