# nearme

Search for places near you from the command line. Uses macOS MapKit under the hood — no API keys, no cloud accounts.

Companion to [whereami](https://github.com/georgemandis/whereami).

```bash
$ whereami --json | nearme "pizza"

1. Norm's Pizza
   345 Adams St, New York, NY 11201
   +1 (347) 916-1310 · https://normspizza.com · 470 m

2. Piz-zetta
   90 Livingston St, Brooklyn, NY 11201
   +1 (718) 422-7878 · 473 m

3. Pronto Pizza
   139 Court St, New York, NY 11201
   +1 (718) 522-2225 · 560 m
```

Results are sorted by distance and include address, phone, URL, and distance from your search coordinates.

## Install

### Homebrew

```bash
brew install georgemandis/tap/nearme
```

### From source

Requires [Zig 0.16.0](https://ziglang.org/download/) and macOS.

```bash
git clone https://github.com/georgemandis/nearme.git
cd nearme
zig build
# Binary is at zig-out/bin/nearme
```

## Usage

```bash
# Pipe coordinates from whereami
whereami --json | nearme "coffee"

# Or specify coordinates directly
nearme "pizza" --lat=40.6892 --lon=-73.9857

# JSON output for scripting
whereami --json | nearme "pharmacy" --json

# Custom radius and result count
nearme "gas station" --lat=40.7128 --lon=-74.0060 --radius=5000 --count=5
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

Coordinates are resolved in this order:

1. `--lat` and `--lon` flags (highest priority)
2. Piped JSON on stdin — compatible with `whereami --json`
3. Neither provided — prints usage and exits

### JSON output

With `--json`, results are a JSON array:

```json
[
  {
    "name": "Norm's Pizza",
    "address": "345 Adams St, New York, NY 11201",
    "latitude": 40.6928,
    "longitude": -73.9886,
    "phone": "+1 (347) 916-1310",
    "url": "https://normspizza.com"
  }
]
```

`phone` and `url` may be `null`.

## How it works

nearme calls MapKit's [MKLocalSearch](https://developer.apple.com/documentation/mapkit/mklocalsearch) API through the Objective-C runtime — the same search that powers Apple Maps. The entire tool is written in Zig with no Swift or Objective-C source files; it talks to the ObjC runtime directly via `objc_msgSend`.

macOS-only. There are no equivalent native place search APIs on Windows or Linux.

## See also

- [whereami](https://github.com/georgemandis/whereami) — get your current coordinates from the command line
- [loupe](https://github.com/georgemandis/loupe) — computer vision CLI (face detection, OCR, person segmentation)

## License

MIT — see [LICENSE](LICENSE).

Created by [George Mandis](https://george.mand.is).
