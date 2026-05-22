const std = @import("std");
const builtin = @import("builtin");
const search = @import("search");
const categories = @import("categories");

const version = "0.2.0";

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
        \\  --type=TYPE          Result type: poi, address, all (default: all)
        \\  --category=CAT       Filter by POI category (e.g. restaurant, cafe)
        \\  --json               Output as JSON
        \\  --categories         List all available categories
        \\  --completions=SHELL  Output shell completions (bash, zsh, fish)
        \\  -h, --help           Show help
        \\  -v, --version        Show version
        \\
        \\Examples:
        \\  nearme "pizza" --lat=40.6892 --lon=-73.9857
        \\  nearme "coffee" --category=cafe --lat=40.6892 --lon=-73.9857
        \\  nearme "123 Main St" --type=address --lat=40.6892 --lon=-73.9857
        \\  whereami --json | nearme "coffee"
        \\
        \\Created by George Mandis <george@mand.is>
        \\https://github.com/georgemandis/nearme
        \\
    , .{version});
}

fn printCategories(writer: *std.Io.Writer) !void {
    try writer.print("Available categories:\n\n", .{});
    for (&categories.all) |*entry| {
        try writer.print("  {s}\n", .{entry.cli_name});
    }
}

fn printCompletionsBash(writer: *std.Io.Writer) !void {
    try writer.print(
        \\_nearme_completions() {{
        \\  local cur prev opts categories
        \\  cur="${{COMP_WORDS[COMP_CWORD]}}"
        \\  prev="${{COMP_WORDS[COMP_CWORD-1]}}"
        \\
        \\  opts="--lat= --lon= --radius= --count= --type= --category= --json --categories --completions= --help --version"
        \\
    , .{});
    try writer.print("  categories=\"", .{});
    for (&categories.all, 0..) |*entry, i| {
        if (i > 0) try writer.print(" ", .{});
        try writer.print("{s}", .{entry.cli_name});
    }
    try writer.print(
        \\"
        \\
        \\  if [[ "$cur" == --category=* ]]; then
        \\    local prefix="${{cur%%=*}}="
        \\    local typed="${{cur#*=}}"
        \\    COMPREPLY=($(compgen -P "$prefix" -W "$categories" -- "$typed"))
        \\    return
        \\  fi
        \\
        \\  if [[ "$cur" == --type=* ]]; then
        \\    local prefix="${{cur%%=*}}="
        \\    local typed="${{cur#*=}}"
        \\    COMPREPLY=($(compgen -P "$prefix" -W "poi address all" -- "$typed"))
        \\    return
        \\  fi
        \\
        \\  if [[ "$cur" == --completions=* ]]; then
        \\    local prefix="${{cur%%=*}}="
        \\    local typed="${{cur#*=}}"
        \\    COMPREPLY=($(compgen -P "$prefix" -W "bash zsh fish" -- "$typed"))
        \\    return
        \\  fi
        \\
        \\  if [[ "$cur" == -* ]]; then
        \\    COMPREPLY=($(compgen -W "$opts" -- "$cur"))
        \\    return
        \\  fi
        \\}}
        \\complete -F _nearme_completions nearme
        \\
    , .{});
}

fn printCompletionsZsh(writer: *std.Io.Writer) !void {
    try writer.print(
        \\#compdef nearme
        \\
        \\_nearme() {{
        \\  local -a categories
        \\  categories=(
    , .{});
    try writer.print("\n", .{});
    for (&categories.all) |*entry| {
        try writer.print("    '{s}'\n", .{entry.cli_name});
    }
    try writer.print(
        \\  )
        \\
        \\  _arguments \
        \\    '1:query:' \
        \\    '--lat=[Latitude]:latitude:' \
        \\    '--lon=[Longitude]:longitude:' \
        \\    '--radius=[Search radius in meters]:radius:' \
        \\    '--count=[Max results]:count:' \
        \\    '--type=[Result type]:type:(poi address all)' \
        \\    '--category=[POI category]:category:($categories)' \
        \\    '--json[Output as JSON]' \
        \\    '--categories[List available categories]' \
        \\    '--completions=[Shell completions]:shell:(bash zsh fish)' \
        \\    '(-h --help)'{{-h,--help}}'[Show help]' \
        \\    '(-v --version)'{{-v,--version}}'[Show version]'
        \\}}
        \\
        \\_nearme "$@"
        \\
    , .{});
}

fn printCompletionsFish(writer: *std.Io.Writer) !void {
    try writer.print(
        \\# Fish completions for nearme
        \\complete -c nearme -l lat -x -d 'Latitude'
        \\complete -c nearme -l lon -x -d 'Longitude'
        \\complete -c nearme -l radius -x -d 'Search radius in meters'
        \\complete -c nearme -l count -x -d 'Max results'
        \\complete -c nearme -l type -x -a 'poi address all' -d 'Result type'
        \\complete -c nearme -l json -d 'Output as JSON'
        \\complete -c nearme -l categories -d 'List available categories'
        \\complete -c nearme -l completions -x -a 'bash zsh fish' -d 'Output shell completions'
        \\complete -c nearme -s h -l help -d 'Show help'
        \\complete -c nearme -s v -l version -d 'Show version'
        \\
    , .{});
    // Category completions
    try writer.print("complete -c nearme -l category -x -a '", .{});
    for (&categories.all, 0..) |*entry, i| {
        if (i > 0) try writer.print(" ", .{});
        try writer.print("{s}", .{entry.cli_name});
    }
    try writer.print("' -d 'POI category'\n", .{});
}

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

fn haversineKm(lat1: f64, lon1: f64, lat2: f64, lon2: f64) f64 {
    const R = 6371.0;
    const toRad = std.math.pi / 180.0;
    const dlat = (lat2 - lat1) * toRad;
    const dlon = (lon2 - lon1) * toRad;
    const a = std.math.sin(dlat / 2.0) * std.math.sin(dlat / 2.0) +
        std.math.cos(lat1 * toRad) * std.math.cos(lat2 * toRad) *
        std.math.sin(dlon / 2.0) * std.math.sin(dlon / 2.0);
    const c = 2.0 * std.math.atan2(std.math.sqrt(a), std.math.sqrt(1.0 - a));
    return R * c;
}

fn categoryDisplayName(apple_id: []const u8) []const u8 {
    if (categories.findByAppleId(apple_id)) |entry| return entry.cli_name;
    // Strip "MKPOICategory" prefix as fallback
    const prefix = "MKPOICategory";
    if (std.mem.startsWith(u8, apple_id, prefix)) return apple_id[prefix.len..];
    return apple_id;
}

fn printHuman(writer: *std.Io.Writer, places: []const search.Place, center_lat: f64, center_lon: f64) !void {
    for (places, 1..) |place, i| {
        // Line 1: number and name
        try writer.print("{d}. {s}", .{ i, place.name });
        if (place.category) |cat| {
            try writer.print(" ({s})", .{categoryDisplayName(cat)});
        }
        try writer.print("\n", .{});

        // Line 2: address
        if (place.address.len > 0) {
            try writer.print("   {s}\n", .{place.address});
        }

        // Line 3: phone, url, distance — joined with " · "
        const dist = haversineKm(center_lat, center_lon, place.latitude, place.longitude);
        var has_detail = false;

        try writer.print("   ", .{});

        if (place.phone) |p| {
            if (p.len > 0) {
                try writer.print("{s}", .{p});
                has_detail = true;
            }
        }

        if (place.url) |u| {
            if (u.len > 0) {
                if (has_detail) try writer.print(" · ", .{});
                try writer.print("{s}", .{u});
                has_detail = true;
            }
        }

        if (has_detail) try writer.print(" · ", .{});
        if (dist < 1.0) {
            try writer.print("{d:.0} m", .{dist * 1000.0});
        } else {
            try writer.print("{d:.1} km", .{dist});
        }

        try writer.print("\n", .{});

        // Blank line between results (except after last)
        if (i < places.len) {
            try writer.print("\n", .{});
        }
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

        // category
        try writer.print(",\"category\":", .{});
        if (place.category) |cat| {
            try writer.print("\"", .{});
            try writeJsonString(writer, categoryDisplayName(cat));
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
    var result_type: search.ResultType = .all;
    var category_filter: ?[]const u8 = null;

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
        } else if (std.mem.eql(u8, arg, "--categories")) {
            try printCategories(&stdout.interface);
            try stdout.interface.flush();
            return;
        } else if (std.mem.startsWith(u8, arg, "--completions=")) {
            const shell = arg["--completions=".len..];
            if (std.mem.eql(u8, shell, "bash")) {
                try printCompletionsBash(&stdout.interface);
            } else if (std.mem.eql(u8, shell, "zsh")) {
                try printCompletionsZsh(&stdout.interface);
            } else if (std.mem.eql(u8, shell, "fish")) {
                try printCompletionsFish(&stdout.interface);
            } else {
                try stderr.interface.print("Error: unknown shell '{s}' (use bash, zsh, or fish)\n", .{shell});
                try stderr.interface.flush();
                std.process.exit(2);
            }
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
            if (radius <= 0) {
                try stderr.interface.print("Error: --radius must be positive\n", .{});
                try stderr.interface.flush();
                std.process.exit(2);
            }
        } else if (std.mem.startsWith(u8, arg, "--count=")) {
            count = std.fmt.parseInt(usize, arg["--count=".len..], 10) catch {
                try stderr.interface.print("Error: invalid count\n", .{});
                try stderr.interface.flush();
                std.process.exit(2);
            };
            if (count == 0) {
                try stderr.interface.print("Error: --count must be at least 1\n", .{});
                try stderr.interface.flush();
                std.process.exit(2);
            }
        } else if (std.mem.startsWith(u8, arg, "--type=")) {
            const type_str = arg["--type=".len..];
            if (std.mem.eql(u8, type_str, "poi")) {
                result_type = .poi;
            } else if (std.mem.eql(u8, type_str, "address")) {
                result_type = .address;
            } else if (std.mem.eql(u8, type_str, "all")) {
                result_type = .all;
            } else {
                try stderr.interface.print("Error: unknown type '{s}' (use poi, address, or all)\n", .{type_str});
                try stderr.interface.flush();
                std.process.exit(2);
            }
        } else if (std.mem.startsWith(u8, arg, "--category=")) {
            const cat_name = arg["--category=".len..];
            if (categories.findByCliName(cat_name)) |entry| {
                category_filter = entry.apple_id;
            } else {
                try stderr.interface.print("Error: unknown category '{s}'\n", .{cat_name});
                try stderr.interface.print("Run 'nearme --categories' to see available categories.\n", .{});
                try stderr.interface.flush();
                std.process.exit(2);
            }
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

    // Coordinate resolution: flags > stdin > error
    if (lat == null or lon == null) {
        // Try reading from stdin if it's a pipe
        const stdin_file = std.Io.File.stdin();
        const stdin_is_tty = stdin_file.isTty(init.io) catch false;
        if (!stdin_is_tty) {
            var stdin_buf: [4096]u8 = undefined;
            var stdin_reader = stdin_file.readerStreaming(init.io, &stdin_buf);
            var json_buf: [4096]u8 = undefined;
            var json_len: usize = 0;

            while (true) {
                const byte = stdin_reader.interface.takeByte() catch break;
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
                    if (lat == null) {
                        if (root.object.get("latitude")) |lat_val| {
                            if (lat_val == .float) lat = lat_val.float;
                            if (lat_val == .integer) lat = @floatFromInt(lat_val.integer);
                        }
                    }
                    if (lon == null) {
                        if (root.object.get("longitude")) |lon_val| {
                            if (lon_val == .float) lon = lon_val.float;
                            if (lon_val == .integer) lon = @floatFromInt(lon_val.integer);
                        }
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
    const final_query = query.?;

    // Perform search
    const results = search.search(.{
        .query = final_query,
        .lat = final_lat,
        .lon = final_lon,
        .radius = radius,
        .result_type = result_type,
        .category_filter = category_filter,
    }) catch |err| {
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

    // Sort by distance from search center
    const SortCtx = struct {
        lat: f64,
        lon: f64,
    };
    const ctx = SortCtx{ .lat = final_lat, .lon = final_lon };
    std.mem.sort(search.Place, results, ctx, struct {
        fn lessThan(c: SortCtx, a: search.Place, b: search.Place) bool {
            const dist_a = haversineKm(c.lat, c.lon, a.latitude, a.longitude);
            const dist_b = haversineKm(c.lat, c.lon, b.latitude, b.longitude);
            return dist_a < dist_b;
        }
    }.lessThan);

    // Truncate to --count
    const display_results = if (results.len > count) results[0..count] else results;

    if (display_results.len == 0) {
        if (json_output) {
            try stdout.interface.print("[]\n", .{});
        } else {
            try stdout.interface.print("No results found for '{s}' within {d:.0}m.\n", .{ final_query, radius });
        }
        try stdout.interface.flush();
        return;
    }

    if (json_output) {
        try printJson(&stdout.interface, display_results);
    } else {
        try printHuman(&stdout.interface, display_results, final_lat, final_lon);
    }

    try stdout.interface.flush();
}
