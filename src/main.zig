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
    std.mem.doNotOptimizeAway(lat);
    std.mem.doNotOptimizeAway(lon);
    std.mem.doNotOptimizeAway(radius);
    std.mem.doNotOptimizeAway(count);
    std.mem.doNotOptimizeAway(json_output);
    std.mem.doNotOptimizeAway(query);

    try stdout.interface.print("Args parsed OK\n", .{});
    try stdout.interface.flush();
}
