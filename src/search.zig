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
