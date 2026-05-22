# nearme Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Zig CLI tool that searches for nearby places using macOS MKLocalSearch, with no API keys required.

**Architecture:** Standalone Zig 0.16.0 project following whereami's structure. `main.zig` handles arg parsing, stdin detection, and output formatting. `search.zig` defines the `Place` struct and dispatches to `platform/macos.zig`, which wraps MKLocalSearch via the Objective-C runtime. `objc.zig` is copied from whereami.

**Tech Stack:** Zig 0.16.0, macOS MapKit framework (MKLocalSearch), Objective-C runtime, CoreFoundation run loop

---

## File Structure

```
nearme/
  src/
    main.zig              # Arg parsing, stdin JSON reading, output formatting, entry point
    search.zig            # Place struct, SearchError, platform dispatch (search function)
    objc.zig              # Obj-C runtime helpers (copied verbatim from whereami)
    platform/
      macos.zig           # MKLocalSearch implementation via ObjC runtime
  build.zig               # Links MapKit, Foundation, libobjc; creates search_mod module
  README.md               # Usage docs
  LICENSE                  # MIT
```

## Reference Files

These are in the whereami project at `/Users/georgemandis/Projects/recurse/2026/zig-geocoding/whereami/`:

- `src/objc.zig` — Copy verbatim to nearme's `src/objc.zig`
- `src/main.zig` — Reference for arg parsing pattern, `std.Io.Writer`, `std.process.Init`, JSON output
- `src/platform/macos.zig` — Reference for block ABI, run loop pumping, `extractPlacemarkField`, `_NSConcreteStackBlock`, module-level state, `c_allocator` usage
- `src/location.zig` — Reference for platform dispatch pattern
- `build.zig` — Reference for module creation, framework linking

## Key Zig 0.16.0 Patterns

Zig 0.16.0 uses `std.Io.Writer`, `std.Io.File`, `std.process.Init`. The entry point is `pub fn main(init: std.process.Init) !void`. Stdout/stderr are created via `std.Io.File.stdout()` then `.writerStreaming(init.io, &buf)`. The writer interface is at `.interface`. Args iterate via `init.minimal.args.iterateAllocator(allocator)`.

---

### Task 1: Project scaffolding — build.zig and objc.zig

**Files:**
- Create: `src/objc.zig` (copy from whereami)
- Create: `build.zig`

This task sets up the build system and copies the ObjC runtime bindings. After this, `zig build` should compile (even though there's no main yet — we'll verify the build.zig is valid).

- [ ] **Step 1: Copy objc.zig from whereami**

Copy `/Users/georgemandis/Projects/recurse/2026/zig-geocoding/whereami/src/objc.zig` verbatim to `src/objc.zig`. No modifications needed.

- [ ] **Step 2: Create build.zig**

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const search_mod = b.createModule(.{
        .root_source_file = b.path("src/search.zig"),
        .target = target,
        .optimize = optimize,
    });

    search_mod.linkSystemLibrary("objc", .{});
    search_mod.linkFramework("MapKit", .{});
    search_mod.linkFramework("Foundation", .{});

    const exe = b.addExecutable(.{
        .name = "nearme",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "search", .module = search_mod },
            },
        }),
    });
    b.installArtifact(exe);

    const run_step = b.step("run", "Run nearme");
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    run_step.dependOn(&run_cmd.step);
}
```

- [ ] **Step 3: Create minimal stub files so the build can be verified**

Create `src/search.zig`:

```zig
const std = @import("std");
const builtin = @import("builtin");

pub const Place = struct {
    name: []const u8,
    address: []const u8,
    latitude: f64,
    longitude: f64,
    phone: ?[]const u8,
    url: ?[]const u8,
};

pub const SearchError = error{
    NotAvailable,
    SearchFailed,
    Timeout,
};

pub fn search(query: []const u8, lat: f64, lon: f64, radius: f64) SearchError![]Place {
    _ = query;
    _ = lat;
    _ = lon;
    _ = radius;
    return SearchError.NotAvailable;
}

pub fn freePlaces(places: []Place) void {
    _ = places;
}
```

Create `src/main.zig`:

```zig
const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const stdout_file = std.Io.File.stdout();
    var stdout_buf: [4096]u8 = undefined;
    var stdout = stdout_file.writerStreaming(init.io, &stdout_buf);
    try stdout.interface.print("nearme stub\n", .{});
    try stdout.interface.flush();
}
```

- [ ] **Step 4: Verify the project compiles**

Run: `cd /Users/georgemandis/Projects/recurse/2026/nearme && zig build`
Expected: Compiles without errors.

- [ ] **Step 5: Commit**

```bash
cd /Users/georgemandis/Projects/recurse/2026/nearme
git add build.zig src/objc.zig src/search.zig src/main.zig
git commit -m "scaffold: build.zig, objc.zig, stub search and main"
```

---

### Task 2: Argument parsing and help/version in main.zig

**Files:**
- Modify: `src/main.zig`

Implement the full CLI argument parser: `<query>` positional arg, `--lat=N`, `--lon=N`, `--radius=N`, `--count=N`, `--json`, `-h`/`--help`, `-v`/`--version`. No stdin detection yet — that's Task 3.

- [ ] **Step 1: Implement argument parsing and help/version**

Replace `src/main.zig` with:

```zig
const std = @import("std");
const builtin = @import("builtin");
const search = @import("search");

const version = "0.1.0";

fn printUsage(writer: *std.Io.Writer) !void {
    try writer.print(
        \\Usage: nearme <query> [options]
        \\
        \\Search for places nearby using native OS APIs.
        \\Version {s}
        \\
        \\Arguments:
        \\  <query>              What to search for (e.g. "pizza", "coffee", "pharmacy")
        \\
        \\Options:
        \\  --lat=N              Latitude
        \\  --lon=N              Longitude
        \\  --radius=N           Search radius in meters (default: 2000)
        \\  --count=N            Max results (default: 10)
        \\  --json               Output as JSON
        \\  -h, --help           Show help
        \\  -v, --version        Show version
        \\
        \\Examples:
        \\  nearme "pizza" --lat=40.6892 --lon=-73.9857
        \\  whereami --json | nearme "coffee"
        \\
        \\Created by George Mandis <george@mand.is>
        \\https://github.com/georgemandis/nearme
        \\
    , .{version});
}

pub fn main(init: std.process.Init) !void {
    const stdout_file = std.Io.File.stdout();
    var stdout_buf: [4096]u8 = undefined;
    var stdout = stdout_file.writerStreaming(init.io, &stdout_buf);

    const stderr_file = std.Io.File.stderr();
    var stderr_buf: [4096]u8 = undefined;
    var stderr = stderr_file.writerStreaming(init.io, &stderr_buf);

    const allocator = init.gpa;

    var query: ?[]const u8 = null;
    var lat: ?f64 = null;
    var lon: ?f64 = null;
    var radius: f64 = 2000.0;
    var count: usize = 10;
    var json_output = false;

    var args_iter = try init.minimal.args.iterateAllocator(allocator);
    defer args_iter.deinit();
    _ = args_iter.next(); // skip program name

    while (args_iter.next()) |arg| {
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            try printUsage(&stdout.interface);
            try stdout.interface.flush();
            return;
        } else if (std.mem.eql(u8, arg, "--version") or std.mem.eql(u8, arg, "-v")) {
            try stdout.interface.print("nearme " ++ version ++ "\n", .{});
            try stdout.interface.flush();
            return;
        } else if (std.mem.eql(u8, arg, "--json")) {
            json_output = true;
        } else if (std.mem.startsWith(u8, arg, "--lat=")) {
            lat = std.fmt.parseFloat(f64, arg["--lat=".len..]) catch {
                try stderr.interface.print("Error: invalid coordinates\n", .{});
                try stderr.interface.flush();
                std.process.exit(2);
            };
        } else if (std.mem.startsWith(u8, arg, "--lon=")) {
            lon = std.fmt.parseFloat(f64, arg["--lon=".len..]) catch {
                try stderr.interface.print("Error: invalid coordinates\n", .{});
                try stderr.interface.flush();
                std.process.exit(2);
            };
        } else if (std.mem.startsWith(u8, arg, "--radius=")) {
            radius = std.fmt.parseFloat(f64, arg["--radius=".len..]) catch {
                try stderr.interface.print("Error: invalid radius\n", .{});
                try stderr.interface.flush();
                std.process.exit(2);
            };
        } else if (std.mem.startsWith(u8, arg, "--count=")) {
            count = std.fmt.parseInt(usize, arg["--count=".len..], 10) catch {
                try stderr.interface.print("Error: invalid count\n", .{});
                try stderr.interface.flush();
                std.process.exit(2);
            };
        } else if (std.mem.startsWith(u8, arg, "-")) {
            try stderr.interface.print("Error: unknown flag: {s}\n\n", .{arg});
            try printUsage(&stderr.interface);
            try stderr.interface.flush();
            std.process.exit(2);
        } else {
            // Positional argument = query
            if (query == null) {
                query = arg;
            } else {
                try stderr.interface.print("Error: unexpected argument: {s}\n\n", .{arg});
                try printUsage(&stderr.interface);
                try stderr.interface.flush();
                std.process.exit(2);
            }
        }
    }

    // Validate: query is required
    if (query == null) {
        try printUsage(&stderr.interface);
        try stderr.interface.flush();
        std.process.exit(1);
    }

    // For now, just print what we parsed (placeholder until stdin + search are wired up)
    _ = lat;
    _ = lon;
    _ = radius;
    _ = count;
    _ = json_output;
    _ = query;

    try stdout.interface.print("Args parsed OK\n", .{});
    try stdout.interface.flush();
}
```

- [ ] **Step 2: Build and verify help output**

Run: `cd /Users/georgemandis/Projects/recurse/2026/nearme && zig build run -- --help`
Expected: Prints usage text with version 0.1.0.

- [ ] **Step 3: Verify version flag**

Run: `zig build run -- -v`
Expected: Prints `nearme 0.1.0`

- [ ] **Step 4: Verify error on no query**

Run: `zig build run`
Expected: Prints usage to stderr, exits with code 1.

- [ ] **Step 5: Verify error on bad flag**

Run: `zig build run -- --bogus`
Expected: `Error: unknown flag: --bogus` followed by usage, exit 2.

- [ ] **Step 6: Verify basic arg parsing**

Run: `zig build run -- "pizza" --lat=40.6892 --lon=-73.9857`
Expected: `Args parsed OK`

- [ ] **Step 7: Commit**

```bash
git add src/main.zig
git commit -m "feat: argument parsing with help, version, and validation"
```

---

### Task 3: Stdin JSON coordinate reading

**Files:**
- Modify: `src/main.zig`

Add piped stdin detection via `std.posix.isatty(0)`. When stdin is a pipe, read up to 4096 bytes, parse JSON, extract `.latitude` and `.longitude` fields. This enables `whereami --json | nearme "coffee"`.

- [ ] **Step 1: Add stdin reading after arg parsing**

In `main.zig`, after the arg parsing loop and the query validation check, replace the placeholder code (the `_ = lat;` block through the end) with:

```zig
    // Coordinate resolution: flags > stdin > error
    if (lat == null or lon == null) {
        // Try reading from stdin if it's a pipe
        if (!std.posix.isatty(0)) {
            const stdin_file = std.Io.File.stdin();
            var stdin_buf: [4096]u8 = undefined;
            const stdin_reader = stdin_file.reader(init.io, &stdin_buf);
            var json_buf: [4096]u8 = undefined;
            var json_len: usize = 0;

            while (true) {
                const byte = stdin_reader.interface.readByte() catch break;
                if (json_len >= json_buf.len) break;
                json_buf[json_len] = byte;
                json_len += 1;
            }

            if (json_len > 0) {
                const parsed = std.json.parseFromSlice(std.json.Value, allocator, json_buf[0..json_len], .{}) catch {
                    try stderr.interface.print("Error: could not read coordinates from stdin\n", .{});
                    try stderr.interface.flush();
                    std.process.exit(2);
                };
                defer parsed.deinit();

                const root = parsed.value;
                if (root == .object) {
                    if (root.object.get("latitude")) |lat_val| {
                        if (lat_val == .float) lat = lat_val.float;
                        if (lat_val == .integer) lat = @floatFromInt(lat_val.integer);
                    }
                    if (root.object.get("longitude")) |lon_val| {
                        if (lon_val == .float) lon = lon_val.float;
                        if (lon_val == .integer) lon = @floatFromInt(lon_val.integer);
                    }
                }

                if (lat == null or lon == null) {
                    try stderr.interface.print("Error: could not read coordinates from stdin\n", .{});
                    try stderr.interface.flush();
                    std.process.exit(2);
                }
            }
        }
    }

    // Still no coordinates — print usage
    if (lat == null or lon == null) {
        try printUsage(&stderr.interface);
        try stderr.interface.flush();
        std.process.exit(1);
    }

    const final_lat = lat.?;
    const final_lon = lon.?;

    // Placeholder: print parsed state
    _ = final_lat;
    _ = final_lon;
    _ = radius;
    _ = count;
    _ = json_output;
    _ = query;

    try stdout.interface.print("Coordinates resolved OK\n", .{});
    try stdout.interface.flush();
```

- [ ] **Step 2: Build and test with flags**

Run: `zig build run -- "pizza" --lat=40.6892 --lon=-73.9857`
Expected: `Coordinates resolved OK`

- [ ] **Step 3: Test with piped JSON**

Run: `echo '{"latitude":40.6892,"longitude":-73.9857,"accuracy":10}' | zig build run -- "pizza"`
Expected: `Coordinates resolved OK`

- [ ] **Step 4: Test with no coordinates and no pipe**

Run: `zig build run -- "pizza"`
Expected: Prints usage, exit 1.

- [ ] **Step 5: Test with bad JSON on pipe**

Run: `echo 'not json' | zig build run -- "pizza"`
Expected: `Error: could not read coordinates from stdin`, exit 2.

- [ ] **Step 6: Commit**

```bash
git add src/main.zig
git commit -m "feat: read coordinates from piped stdin JSON"
```

---

### Task 4: MKLocalSearch implementation in platform/macos.zig

**Files:**
- Create: `src/platform/macos.zig`
- Modify: `src/search.zig`

This is the core task. Implement MKLocalSearch via the ObjC runtime, following the exact patterns from whereami's `platform/macos.zig` (block ABI, run loop pumping, module-level state, `extractPlacemarkField`, `c_allocator`).

- [ ] **Step 1: Create src/platform/macos.zig**

```zig
const std = @import("std");
const objc = @import("../objc.zig");

const Place = @import("../search.zig").Place;
const SearchError = @import("../search.zig").SearchError;

// MKCoordinateRegion — 4 x f64, HFA on ARM64, passes in FP registers
const CLLocationCoordinate2D = extern struct {
    latitude: f64,
    longitude: f64,
};

const MKCoordinateSpan = extern struct {
    latitudeDelta: f64,
    longitudeDelta: f64,
};

const MKCoordinateRegion = extern struct {
    center: CLLocationCoordinate2D,
    span: MKCoordinateSpan,
};

// CoreFoundation run loop externs
extern "c" fn CFRunLoopGetCurrent() *anyopaque;
extern "c" fn CFRunLoopStop(rl: *anyopaque) void;
extern "c" fn CFRunLoopRunInMode(mode: objc.id, seconds: f64, returnAfterSourceHandled: bool) i32;
extern "c" var kCFRunLoopDefaultMode: objc.id;

// ObjC block ABI (same pattern as whereami)
extern var _NSConcreteStackBlock: [1]usize;

const BlockDescriptor = extern struct {
    reserved: c_ulong,
    size: c_ulong,
};

const SearchBlockLiteral = extern struct {
    isa: *anyopaque,
    flags: c_int,
    reserved: c_int,
    invoke: *const fn (*SearchBlockLiteral, ?objc.id, ?objc.id) callconv(.c) void,
    descriptor: *const BlockDescriptor,
};

const search_block_descriptor = BlockDescriptor{
    .reserved = 0,
    .size = @sizeOf(SearchBlockLiteral),
};

// ---------------------------------------------------------------------------
// Module-level state for the search block callback
// ---------------------------------------------------------------------------
var search_results: ?[]Place = null;
var search_error: ?SearchError = null;
var search_completed: bool = false;
var current_run_loop: ?*anyopaque = null;

// ---------------------------------------------------------------------------
// Block callback — invoked by MKLocalSearch completion handler
// ---------------------------------------------------------------------------

fn searchBlockInvoke(block: *SearchBlockLiteral, response: ?objc.id, err: ?objc.id) callconv(.c) void {
    _ = block;

    if (err != null or response == null) {
        search_error = SearchError.SearchFailed;
        search_completed = true;
        if (current_run_loop) |rl| CFRunLoopStop(rl);
        return;
    }

    const resp = response.?;

    // Get mapItems array from MKLocalSearchResponse
    const map_items: ?objc.id = objc.msgSend(?objc.id, resp, objc.sel("mapItems"), .{});
    if (map_items == null) {
        search_error = SearchError.SearchFailed;
        search_completed = true;
        if (current_run_loop) |rl| CFRunLoopStop(rl);
        return;
    }

    const items = map_items.?;
    const item_count = objc.nsArrayCount(items);
    if (item_count == 0) {
        // Empty results — not an error, just no results
        search_results = &[_]Place{};
        search_completed = true;
        if (current_run_loop) |rl| CFRunLoopStop(rl);
        return;
    }

    const alloc = std.heap.c_allocator;
    const places = alloc.alloc(Place, item_count) catch {
        search_error = SearchError.SearchFailed;
        search_completed = true;
        if (current_run_loop) |rl| CFRunLoopStop(rl);
        return;
    };

    for (0..item_count) |i| {
        const map_item = objc.nsArrayObjectAtIndex(items, i);

        // Name
        const name_str = extractNSStringProperty(map_item, "name") catch "";

        // Placemark
        const placemark: ?objc.id = objc.msgSend(?objc.id, map_item, objc.sel("placemark"), .{});

        // Address from placemark components
        var address: []const u8 = "";
        if (placemark) |pm| {
            address = formatAddress(pm) catch "";
        }

        // Coordinate from placemark
        var place_lat: f64 = 0;
        var place_lon: f64 = 0;
        if (placemark) |pm| {
            const coord = objc.msgSend(CLLocationCoordinate2D, pm, objc.sel("coordinate"), .{});
            place_lat = coord.latitude;
            place_lon = coord.longitude;
        }

        // Phone number (nullable)
        const phone = extractNSStringProperty(map_item, "phoneNumber") catch null;
        const phone_opt: ?[]const u8 = if (phone != null and phone.?.len > 0) phone.? else null;

        // URL (nullable) — NSURL, convert via absoluteString
        const url_obj: ?objc.id = objc.msgSend(?objc.id, map_item, objc.sel("url"), .{});
        var url_str: ?[]const u8 = null;
        if (url_obj) |u| {
            const abs_nsstr: ?objc.id = objc.msgSend(?objc.id, u, objc.sel("absoluteString"), .{});
            if (abs_nsstr) |ns| {
                const cstr = objc.fromNSString(ns);
                if (cstr) |c| {
                    const len = std.mem.len(c);
                    if (len > 0) {
                        const copy = alloc.alloc(u8, len) catch null;
                        if (copy) |buf| {
                            @memcpy(buf, c[0..len]);
                            url_str = buf;
                        }
                    }
                }
            }
        }

        places[i] = Place{
            .name = name_str,
            .address = address,
            .latitude = place_lat,
            .longitude = place_lon,
            .phone = phone_opt,
            .url = url_str,
        };
    }

    search_results = places;
    search_completed = true;
    if (current_run_loop) |rl| CFRunLoopStop(rl);
}

/// Extract a string property from an ObjC object. Returns heap-allocated copy.
/// Uses c_allocator since we're inside an ObjC callback.
fn extractNSStringProperty(obj: objc.id, property: [*:0]const u8) ![]const u8 {
    const nsstr: ?objc.id = objc.msgSend(?objc.id, obj, objc.sel(property), .{});
    const str = nsstr orelse return "";
    const cstr = objc.fromNSString(str) orelse return "";
    const len = std.mem.len(cstr);
    if (len == 0) return "";
    const copy = try std.heap.c_allocator.alloc(u8, len);
    @memcpy(copy, cstr[0..len]);
    return copy;
}

/// Format address from CLPlacemark components (thoroughfare, locality, administrativeArea, postalCode).
/// Same pattern as whereami's extractPlacemarkField.
fn formatAddress(placemark: objc.id) ![]const u8 {
    const alloc = std.heap.c_allocator;

    const thoroughfare = extractNSStringProperty(placemark, "thoroughfare") catch "";
    defer if (thoroughfare.len > 0) alloc.free(@constCast(thoroughfare));

    const sub_thoroughfare = extractNSStringProperty(placemark, "subThoroughfare") catch "";
    defer if (sub_thoroughfare.len > 0) alloc.free(@constCast(sub_thoroughfare));

    const locality = extractNSStringProperty(placemark, "locality") catch "";
    defer if (locality.len > 0) alloc.free(@constCast(locality));

    const admin_area = extractNSStringProperty(placemark, "administrativeArea") catch "";
    defer if (admin_area.len > 0) alloc.free(@constCast(admin_area));

    const postal_code = extractNSStringProperty(placemark, "postalCode") catch "";
    defer if (postal_code.len > 0) alloc.free(@constCast(postal_code));

    // Build address string: "123 Main St, Brooklyn, NY 11201"
    var parts: [4][]const u8 = undefined;
    var part_count: usize = 0;

    // Street: combine subThoroughfare + thoroughfare
    var street_buf: [512]u8 = undefined;
    var street_len: usize = 0;
    if (sub_thoroughfare.len > 0) {
        @memcpy(street_buf[0..sub_thoroughfare.len], sub_thoroughfare);
        street_len = sub_thoroughfare.len;
        if (thoroughfare.len > 0) {
            street_buf[street_len] = ' ';
            street_len += 1;
            @memcpy(street_buf[street_len .. street_len + thoroughfare.len], thoroughfare);
            street_len += thoroughfare.len;
        }
    } else if (thoroughfare.len > 0) {
        @memcpy(street_buf[0..thoroughfare.len], thoroughfare);
        street_len = thoroughfare.len;
    }
    if (street_len > 0) {
        parts[part_count] = street_buf[0..street_len];
        part_count += 1;
    }

    if (locality.len > 0) {
        parts[part_count] = locality;
        part_count += 1;
    }

    // Combine admin_area + postal_code as one part: "NY 11201"
    var state_zip_buf: [256]u8 = undefined;
    var state_zip_len: usize = 0;
    if (admin_area.len > 0) {
        @memcpy(state_zip_buf[0..admin_area.len], admin_area);
        state_zip_len = admin_area.len;
        if (postal_code.len > 0) {
            state_zip_buf[state_zip_len] = ' ';
            state_zip_len += 1;
            @memcpy(state_zip_buf[state_zip_len .. state_zip_len + postal_code.len], postal_code);
            state_zip_len += postal_code.len;
        }
    } else if (postal_code.len > 0) {
        @memcpy(state_zip_buf[0..postal_code.len], postal_code);
        state_zip_len = postal_code.len;
    }
    if (state_zip_len > 0) {
        parts[part_count] = state_zip_buf[0..state_zip_len];
        part_count += 1;
    }

    if (part_count == 0) return "";

    // Join with ", "
    var total_len: usize = 0;
    for (0..part_count) |i| {
        total_len += parts[i].len;
        if (i > 0) total_len += 2; // ", "
    }

    const result = try alloc.alloc(u8, total_len);
    var pos: usize = 0;
    for (0..part_count) |i| {
        if (i > 0) {
            result[pos] = ',';
            result[pos + 1] = ' ';
            pos += 2;
        }
        @memcpy(result[pos .. pos + parts[i].len], parts[i]);
        pos += parts[i].len;
    }

    return result;
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

pub fn searchPlaces(query_str: []const u8, lat: f64, lon: f64, radius_meters: f64) SearchError![]Place {
    // Reset module state
    search_results = null;
    search_error = null;
    search_completed = false;

    // Create MKLocalSearchRequest: [[MKLocalSearchRequest alloc] init]
    const MKLocalSearchRequest = objc.getClass("MKLocalSearchRequest") orelse return SearchError.NotAvailable;
    const req_alloc = objc.msgSend(objc.id, MKLocalSearchRequest, objc.sel("alloc"), .{});
    const request = objc.msgSend(objc.id, req_alloc, objc.sel("init"), .{});

    // Set naturalLanguageQuery
    // Need null-terminated copy for nsString
    var query_buf: [1024]u8 = undefined;
    if (query_str.len >= query_buf.len) return SearchError.SearchFailed;
    @memcpy(query_buf[0..query_str.len], query_str);
    query_buf[query_str.len] = 0;
    const query_ns = objc.nsString(query_buf[0..query_str.len :0]);
    objc.msgSend(void, request, objc.sel("setNaturalLanguageQuery:"), .{query_ns});

    // Create MKCoordinateRegion from lat/lon/radius
    const lat_delta = (radius_meters / 111320.0) * 2.0;
    const lon_delta = (radius_meters / (111320.0 * @cos(lat * std.math.pi / 180.0))) * 2.0;

    const region = MKCoordinateRegion{
        .center = CLLocationCoordinate2D{ .latitude = lat, .longitude = lon },
        .span = MKCoordinateSpan{ .latitudeDelta = lat_delta, .longitudeDelta = lon_delta },
    };

    // Set region on request
    // MKCoordinateRegion is 4 x f64, an HFA on ARM64 — passes in FP registers d0-d3
    // We use a typed msgSend function that takes the struct directly
    const setRegionFn = objc.msgSendFn(void, struct { MKCoordinateRegion });
    setRegionFn(@ptrCast(request), objc.sel("setRegion:"), region);

    // Create MKLocalSearch: [[MKLocalSearch alloc] initWithRequest:]
    const MKLocalSearch = objc.getClass("MKLocalSearch") orelse return SearchError.NotAvailable;
    const search_alloc = objc.msgSend(objc.id, MKLocalSearch, objc.sel("alloc"), .{});
    const local_search = objc.msgSend(objc.id, search_alloc, objc.sel("initWithRequest:"), .{request});

    // Construct the ObjC block on the stack
    var block = SearchBlockLiteral{
        .isa = @ptrCast(&_NSConcreteStackBlock),
        .flags = 0,
        .reserved = 0,
        .invoke = &searchBlockInvoke,
        .descriptor = &search_block_descriptor,
    };

    // [localSearch startWithCompletionHandler:]
    current_run_loop = CFRunLoopGetCurrent();
    objc.msgSend(void, local_search, objc.sel("startWithCompletionHandler:"), .{@as(objc.id, @ptrCast(&block))});

    // Pump run loop (10 second timeout)
    _ = CFRunLoopRunInMode(kCFRunLoopDefaultMode, 10.0, false);
    current_run_loop = null;

    // Check results
    if (search_error) |err| return err;
    if (search_results) |results| return results;
    return SearchError.Timeout;
}

pub fn freePlaces(places: []Place) void {
    const alloc = std.heap.c_allocator;
    for (places) |place| {
        if (place.name.len > 0) alloc.free(@constCast(place.name));
        if (place.address.len > 0) alloc.free(@constCast(place.address));
        if (place.phone) |p| if (p.len > 0) alloc.free(@constCast(p));
        if (place.url) |u| if (u.len > 0) alloc.free(@constCast(u));
    }
    alloc.free(places);
}
```

- [ ] **Step 2: Update search.zig to dispatch to platform**

Replace `src/search.zig` with:

```zig
const std = @import("std");
const builtin = @import("builtin");

pub const Place = struct {
    name: []const u8,
    address: []const u8,
    latitude: f64,
    longitude: f64,
    phone: ?[]const u8,
    url: ?[]const u8,
};

pub const SearchError = error{
    NotAvailable,
    SearchFailed,
    Timeout,
};

const platform = switch (builtin.os.tag) {
    .macos => @import("platform/macos.zig"),
    else => @compileError("nearme currently requires macOS (MapKit)"),
};

pub fn search(query: []const u8, lat: f64, lon: f64, radius: f64) SearchError![]Place {
    return platform.searchPlaces(query, lat, lon, radius);
}

pub fn freePlaces(places: []Place) void {
    platform.freePlaces(places);
}
```

- [ ] **Step 3: Build and verify compilation**

Run: `cd /Users/georgemandis/Projects/recurse/2026/nearme && zig build`
Expected: Compiles without errors. (Can't test MKLocalSearch without running — that's the next step.)

**Note:** The spec mentions MKLocalSearch may not require an .app bundle (unlike CoreLocation). If the search silently returns zero results in Task 5 testing, this is the first thing to investigate — an .app bundle with entitlements may be needed. Also note: `MKCoordinateRegion` is an HFA (4 x f64) on ARM64 and passes in FP registers. If `setRegion:` doesn't work correctly (search returns wrong-location results), the struct may need to be decomposed into individual f64 args — check the spec's ARM64 ABI section.

- [ ] **Step 4: Commit**

```bash
git add src/platform/macos.zig src/search.zig
git commit -m "feat: MKLocalSearch implementation via ObjC runtime"
```

---

### Task 5: Wire search into main.zig and implement output formatting

**Files:**
- Modify: `src/main.zig`

Connect arg parsing to the search function. Implement both human-readable and JSON output formats. This completes the CLI.

- [ ] **Step 1: Add writeJsonString helper and output functions**

Add these functions to `main.zig` after the `printUsage` function:

```zig
fn writeJsonString(writer: *std.Io.Writer, s: []const u8) !void {
    for (s) |c| {
        switch (c) {
            '"' => try writer.print("\\\"", .{}),
            '\\' => try writer.print("\\\\", .{}),
            '\n' => try writer.print("\\n", .{}),
            '\r' => try writer.print("\\r", .{}),
            '\t' => try writer.print("\\t", .{}),
            0x00...0x08, 0x0B, 0x0C, 0x0E...0x1F => try writer.print("\\u{X:0>4}", .{c}),
            else => try writer.print("{c}", .{c}),
        }
    }
}

fn printHuman(writer: *std.Io.Writer, places: []const search.Place) !void {
    for (places, 1..) |place, i| {
        try writer.print("{d}. {s}", .{ i, place.name });
        if (place.address.len > 0) {
            // Pad name to 25 chars for alignment
            const name_len = place.name.len;
            const num_width = if (i < 10) @as(usize, 1) else if (i < 100) @as(usize, 2) else @as(usize, 3);
            const used = num_width + 2 + name_len; // "N. name"
            if (used < 30) {
                var pad: usize = 0;
                while (pad < 30 - used) : (pad += 1) {
                    try writer.print(" ", .{});
                }
            } else {
                try writer.print("  ", .{});
            }
            try writer.print("{s}", .{place.address});
        }
        try writer.print("\n", .{});
    }
}

fn printJson(writer: *std.Io.Writer, places: []const search.Place) !void {
    try writer.print("[\n", .{});
    for (places, 0..) |place, i| {
        try writer.print("  {{\"name\":\"", .{});
        try writeJsonString(writer, place.name);
        try writer.print("\",\"address\":\"", .{});
        try writeJsonString(writer, place.address);
        try writer.print("\",\"latitude\":{d},\"longitude\":{d}", .{ place.latitude, place.longitude });

        // phone
        try writer.print(",\"phone\":", .{});
        if (place.phone) |p| {
            try writer.print("\"", .{});
            try writeJsonString(writer, p);
            try writer.print("\"", .{});
        } else {
            try writer.print("null", .{});
        }

        // url
        try writer.print(",\"url\":", .{});
        if (place.url) |u| {
            try writer.print("\"", .{});
            try writeJsonString(writer, u);
            try writer.print("\"", .{});
        } else {
            try writer.print("null", .{});
        }

        try writer.print("}}", .{});
        if (i < places.len - 1) {
            try writer.print(",", .{});
        }
        try writer.print("\n", .{});
    }
    try writer.print("]\n", .{});
}
```

- [ ] **Step 2: Replace the placeholder code at the end of main with search + output**

Replace everything from the `// Still no coordinates` comment through the end of main with:

```zig
    // Still no coordinates — print usage
    if (lat == null or lon == null) {
        try printUsage(&stderr.interface);
        try stderr.interface.flush();
        std.process.exit(1);
    }

    const final_lat = lat.?;
    const final_lon = lon.?;
    const final_query = query.?;

    // Perform search
    const results = search.search(final_query, final_lat, final_lon, radius) catch |err| {
        switch (err) {
            search.SearchError.NotAvailable => {
                try stderr.interface.print("Error: nearme requires macOS (MapKit)\n", .{});
            },
            search.SearchError.Timeout => {
                try stderr.interface.print("Error: search timed out\n", .{});
            },
            search.SearchError.SearchFailed => {
                try stderr.interface.print("Error: search failed\n", .{});
            },
        }
        try stderr.interface.flush();
        std.process.exit(1);
    };
    defer search.freePlaces(results);

    // Truncate to --count
    const display_results = if (results.len > count) results[0..count] else results;

    if (display_results.len == 0) {
        try stderr.interface.print("No results found for '{s}' within {d:.0}m.\n", .{ final_query, radius });
        try stderr.interface.flush();
        return;
    }

    if (json_output) {
        try printJson(&stdout.interface, display_results);
    } else {
        try printHuman(&stdout.interface, display_results);
    }

    try stdout.interface.flush();
```

- [ ] **Step 3: Build**

Run: `cd /Users/georgemandis/Projects/recurse/2026/nearme && zig build`
Expected: Compiles.

- [ ] **Step 4: Test human-readable output**

Run: `zig build run -- "pizza" --lat=40.6892 --lon=-73.9857`
Expected: Numbered list of pizza places near the Statue of Liberty area. Something like:
```
1. Joe's Pizza              123 Some St, Brooklyn, NY 11201
2. ...
```

- [ ] **Step 5: Test JSON output**

Run: `zig build run -- "pizza" --lat=40.6892 --lon=-73.9857 --json`
Expected: JSON array with name, address, latitude, longitude, phone, url fields.

- [ ] **Step 6: Test piped from whereami**

Run: `whereami --json | zig build run -- "coffee"`
Expected: Coffee shops near your current location.

- [ ] **Step 7: Test --count flag**

Run: `zig build run -- "coffee" --lat=40.7128 --lon=-74.0060 --count=3`
Expected: At most 3 results.

- [ ] **Step 8: Commit**

```bash
git add src/main.zig
git commit -m "feat: wire search to main, human and JSON output formatting"
```

---

### Task 6: README and LICENSE

**Files:**
- Create: `README.md`
- Create: `LICENSE`

- [ ] **Step 1: Create README.md**

```markdown
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
```

- [ ] **Step 2: Create LICENSE**

MIT license with George Mandis as copyright holder, year 2026.

- [ ] **Step 3: Commit**

```bash
git add README.md LICENSE
git commit -m "docs: add README and LICENSE"
```

---

### Task 7: Manual end-to-end testing and edge case fixes

**Files:**
- Possibly modify: `src/main.zig`, `src/platform/macos.zig`

Run through all the test scenarios from the spec and fix any issues found.

- [ ] **Step 1: Test help flag**

Run: `zig build run -- --help`
Expected: Full usage text.

- [ ] **Step 2: Test version flag**

Run: `zig build run -- -v`
Expected: `nearme 0.1.0`

- [ ] **Step 3: Test no arguments**

Run: `zig build run`
Expected: Usage text on stderr, exit 1.

- [ ] **Step 4: Test invalid lat/lon**

Run: `zig build run -- "pizza" --lat=abc --lon=-73.9857`
Expected: `Error: invalid coordinates`, exit 2.

- [ ] **Step 5: Test basic search with flags**

Run: `zig build run -- "pizza" --lat=40.6892 --lon=-73.9857`
Expected: Numbered list of pizza places.

- [ ] **Step 6: Test JSON mode**

Run: `zig build run -- "pizza" --lat=40.6892 --lon=-73.9857 --json | head -5`
Expected: Valid JSON array.

- [ ] **Step 7: Test piped stdin**

Run: `echo '{"latitude":40.6892,"longitude":-73.9857,"accuracy":10}' | zig build run -- "coffee"`
Expected: Coffee places near those coordinates.

- [ ] **Step 8: Test whereami pipe (if whereami is installed)**

Run: `whereami --json | zig build run -- "pharmacy"`
Expected: Pharmacies near current location.

- [ ] **Step 9: Test count truncation**

Run: `zig build run -- "restaurant" --lat=40.7128 --lon=-74.0060 --count=2`
Expected: Exactly 2 results.

- [ ] **Step 10: Test custom radius**

Run: `zig build run -- "pizza" --lat=40.7128 --lon=-74.0060 --radius=500`
Expected: Results (possibly fewer due to smaller radius).

- [ ] **Step 11: Fix any issues found, commit if changes were made**

```bash
git add -A
git commit -m "fix: edge case fixes from end-to-end testing"
```
(Skip this commit if no fixes were needed.)
