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
