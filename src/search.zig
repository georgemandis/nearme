const std = @import("std");
const builtin = @import("builtin");

pub const Place = struct {
    name: []const u8,
    address: []const u8,
    latitude: f64,
    longitude: f64,
    phone: ?[]const u8,
    url: ?[]const u8,
    category: ?[]const u8, // MKPOICategory string, e.g. "MKPOICategoryRestaurant"
};

pub const ResultType = enum {
    all,
    poi,
    address,
};

pub const SearchOptions = struct {
    query: []const u8,
    lat: f64,
    lon: f64,
    radius: f64,
    result_type: ResultType = .all,
    category_filter: ?[]const u8 = null, // Apple ID string to filter by
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

pub fn search(opts: SearchOptions) SearchError![]Place {
    return platform.searchPlaces(opts);
}

pub fn freePlaces(places: []Place) void {
    platform.freePlaces(places);
}
