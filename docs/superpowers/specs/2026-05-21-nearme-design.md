# nearme Design Spec

## Goal

A CLI tool written in Zig that searches for places near given coordinates using native OS APIs. On macOS, wraps MKLocalSearch (MapKit). No API keys, no cloud accounts. Companion to [whereami](https://github.com/georgemandis/whereami).

## Architecture

Standalone Zig project following whereami's structure exactly. Platform-specific search behind a common interface. macOS uses MKLocalSearch via the Objective-C runtime. The `objc.zig` helper is copied from whereami.

macOS-only at launch. The platform abstraction exists so Windows/Linux backends could be added later if native place search APIs emerge, but no stubs or placeholder implementations.

## CLI Interface

```
Usage: nearme <query> [options]

Search for places nearby using native OS APIs.

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

### Coordinate input

Three ways to provide coordinates, checked in order:

1. `--lat` and `--lon` flags (highest priority)
2. Piped JSON on stdin — if stdin is a pipe, read JSON and extract `latitude`/`longitude` fields. Compatible with `whereami --json` output.
3. Neither provided and stdin is not a pipe — print usage and exit 1.

### Output

Human-readable by default:

```
$ nearme "pizza" --lat=40.6892 --lon=-73.9857

1. Little Pizza Parlor       192 Duffield St, Brooklyn, NY 11201
2. Juliana's Pizza           19 Old Fulton St, Brooklyn, NY 11201
3. Grimaldi's Pizzeria       1 Front St, Brooklyn, NY 11201
4. Front Street Pizza        80 Front St, Brooklyn, NY 11201
5. Lucali                    575 Henry St, Brooklyn, NY 11231
```

JSON mode (`--json`):

```json
[
  {
    "name": "Little Pizza Parlor",
    "address": "192 Duffield St, Brooklyn, NY 11201",
    "latitude": 40.6893,
    "longitude": -73.9842,
    "phone": "+17183551234",
    "url": "http://littlepizzaparlor.com"
  }
]
```

Fields `phone` and `url` may be `null` in JSON mode. In human-readable mode, only name and address are shown.

### Composition with whereami

```bash
# Piped
whereami --json | nearme "coffee"

# Explicit coordinates
nearme "pharmacy" --lat=40.7128 --lon=-74.0060

# Full pipeline to JSON
whereami --json | nearme "pizza" --json | jq '.[0].name'
```

## File Structure

```
nearme/
  src/
    main.zig            # Arg parsing, stdin detection, output formatting
    search.zig          # Platform-agnostic interface: Place struct, search function
    objc.zig            # Obj-C runtime helpers (copied from whereami)
    platform/
      macos.zig         # MKLocalSearch implementation
  build.zig             # Links MapKit, Foundation, libobjc
  README.md
  LICENSE
```

## Data Types

### Place (defined in search.zig)

```
Place {
    name: []const u8,
    address: []const u8,
    latitude: f64,
    longitude: f64,
    phone: ?[]const u8,
    url: ?[]const u8,
}
```

### SearchError (defined in search.zig)

```
SearchError {
    NotAvailable,     // MKLocalSearch not found (non-macOS)
    SearchFailed,     // MKLocalSearch returned an error
    Timeout,          // Run loop timed out
}
```

## macOS Implementation (platform/macos.zig)

### MKLocalSearch wrapper

Follows the same pattern as whereami's `reverseGeocode` in `platform/macos.zig`:

1. Create `MKLocalSearchRequest` via `[[MKLocalSearchRequest alloc] init]`
2. Set `naturalLanguageQuery` to the search query string (NSString)
3. Create `MKCoordinateRegion` from lat/lon/radius and set on the request
4. Create `MKLocalSearch` via `[[MKLocalSearch alloc] initWithRequest:]`
5. Call `[search startWithCompletionHandler:]` with a Zig-constructed ObjC block
6. Pump `CFRunLoop` until the block callback fires or 10-second timeout
7. In the block callback: extract `MKMapItem` array from `MKLocalSearchResponse.mapItems`
8. For each MKMapItem, read: `name`, `placemark.title` (address), `placemark.coordinate` (lat/lon), `phoneNumber`, `url`
9. Return array of Place structs

### ObjC types needed

- `MKLocalSearchRequest` — set `naturalLanguageQuery` (NSString) and `region` (MKCoordinateRegion)
- `MKLocalSearch` — init with request, `startWithCompletionHandler:` takes a block
- `MKLocalSearchResponse` — has `mapItems` (NSArray of MKMapItem)
- `MKMapItem` — has `name` (NSString), `phoneNumber` (NSString?), `url` (NSURL?), `placemark` (MKPlacemark)
- `MKPlacemark` — has `title` (NSString?), `coordinate` (CLLocationCoordinate2D)

### MKCoordinateRegion

This is a struct with nested structs:

```
MKCoordinateRegion {
    center: CLLocationCoordinate2D { latitude: f64, longitude: f64 },
    span: MKCoordinateSpan { latitudeDelta: f64, longitudeDelta: f64 }
}
```

To convert radius in meters to span deltas:
- `latitudeDelta = (radius / 111320.0) * 2.0`
- `longitudeDelta = (radius / (111320.0 * cos(lat * pi / 180.0))) * 2.0`

Setting the region on the request requires passing this struct. On ARM64, structs over 16 bytes are passed by pointer via `objc_msgSend`. MKCoordinateRegion is 32 bytes (4 x f64), so we may need to handle this carefully — either pass by pointer or use `objc_msgSend_stret` depending on the ABI. This needs verification during implementation.

### Block ABI

Same pattern as whereami's `GeocoderBlockLiteral`:

```
SearchBlockLiteral {
    isa: *anyopaque,           // &_NSConcreteStackBlock
    flags: c_int,              // 0
    reserved: c_int,           // 0
    invoke: *const fn,         // callback function pointer
    descriptor: *const BlockDescriptor,
}
```

The completion handler signature is `^(MKLocalSearchResponse *response, NSError *error)` — two nullable object arguments, same pattern as the geocoder block.

### Module-level state

Same pattern as whereami — module-level vars for the block callback to write results into:

```
var search_results: ?[]Place = null;
var search_error: ?SearchError = null;
var search_completed: bool = false;
```

### Frameworks to link in build.zig

- `MapKit`
- `Foundation`
- `libobjc`

### .app bundle

MKLocalSearch may not require an .app bundle (unlike CoreLocation, which needs it for permissions). Test during implementation. If it works as a raw binary, skip the bundle step entirely.

## build.zig

Follows whereami's build.zig structure:

- `search_mod` module with platform-specific framework linking
- Single executable `nearme`
- `zig build run` step with arg forwarding
- Bundle step only if needed (see above)

## Error Handling

- No query argument: print usage, exit 1
- No coordinates (no flags, no pipe): print usage, exit 1
- Invalid `--lat`/`--lon` values: "Error: invalid coordinates", exit 2
- Invalid JSON on stdin: "Error: could not read coordinates from stdin", exit 2
- MKLocalSearch not available (non-macOS build): "Error: nearme requires macOS (MapKit)", exit 1
- Search returns no results: "No results found for '{query}' within {radius}m.", exit 0
- Search fails (MKLocalSearch error): "Error: search failed", exit 1
- Timeout: "Error: search timed out", exit 1

## Limitations

- macOS only. No Windows or Linux backend at launch.
- MKLocalSearch returns up to ~10 results (Apple's limit). The `--count` flag caps below that but cannot exceed it.
- No ratings — Apple does not expose ratings through MKLocalSearch.
- Results depend on Apple Maps data quality for the area.
