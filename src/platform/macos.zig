const std = @import("std");
const objc = @import("../objc.zig");
const Place = @import("../search.zig").Place;
const SearchError = @import("../search.zig").SearchError;
const SearchOptions = @import("../search.zig").SearchOptions;
const ResultType = @import("../search.zig").ResultType;

// ---------------------------------------------------------------------------
// CoreLocation coordinate type
// ---------------------------------------------------------------------------
const CLLocationCoordinate2D = extern struct {
    latitude: f64,
    longitude: f64,
};

// ---------------------------------------------------------------------------
// MKCoordinateRegion — 4 x f64 (HFA on ARM64, passes in FP registers)
// ---------------------------------------------------------------------------
const MKCoordinateSpan = extern struct {
    latitudeDelta: f64,
    longitudeDelta: f64,
};

const MKCoordinateRegion = extern struct {
    center: CLLocationCoordinate2D,
    span: MKCoordinateSpan,
};

// ---------------------------------------------------------------------------
// CoreFoundation run loop externs
// ---------------------------------------------------------------------------
extern "c" fn CFRunLoopGetCurrent() *anyopaque;
extern "c" fn CFRunLoopStop(rl: *anyopaque) void;
extern "c" fn CFRunLoopRunInMode(mode: objc.id, seconds: f64, returnAfterSourceHandled: bool) i32;
extern "c" var kCFRunLoopDefaultMode: objc.id;

// ---------------------------------------------------------------------------
// ObjC block ABI layout
// See: https://clang.llvm.org/docs/Block-ABI-Apple.html
// ---------------------------------------------------------------------------
extern var _NSConcreteStackBlock: [1]usize;

const BlockDescriptor = extern struct {
    reserved: c_ulong,
    size: c_ulong,
};

// Block for MKLocalSearch completion: ^(MKLocalSearchResponse *response, NSError *error)
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
// Module-level state shared between block callback and searchPlaces
// ---------------------------------------------------------------------------
var search_results: ?[]Place = null;
var search_error: ?SearchError = null;
var search_completed: bool = false;
var current_run_loop: ?*anyopaque = null;

// ---------------------------------------------------------------------------
// Helper: extract a string property from an ObjC object
// Returns heap-allocated copy via c_allocator, or empty string if nil/empty.
// ---------------------------------------------------------------------------
fn extractStringField(obj: objc.id, property: [*:0]const u8) []const u8 {
    const nsstr: ?objc.id = objc.msgSend(?objc.id, obj, objc.sel(property), .{});
    const str = nsstr orelse return "";
    const cstr = objc.fromNSString(str) orelse return "";
    const len = std.mem.len(cstr);
    if (len == 0) return "";
    const copy = std.heap.c_allocator.alloc(u8, len) catch return "";
    @memcpy(copy, cstr[0..len]);
    return copy;
}

/// Extract URL as string: call [url absoluteString] then convert NSString -> Zig string
fn extractUrlString(map_item: objc.id) ?[]const u8 {
    const nsurl: ?objc.id = objc.msgSend(?objc.id, map_item, objc.sel("url"), .{});
    const url_obj = nsurl orelse return null;
    const abs_str: ?objc.id = objc.msgSend(?objc.id, url_obj, objc.sel("absoluteString"), .{});
    const ns_str = abs_str orelse return null;
    const cstr = objc.fromNSString(ns_str) orelse return null;
    const len = std.mem.len(cstr);
    if (len == 0) return null;
    const copy = std.heap.c_allocator.alloc(u8, len) catch return null;
    @memcpy(copy, cstr[0..len]);
    return copy;
}

/// Extract pointOfInterestCategory from MKMapItem (nullable NSString)
fn extractCategory(map_item: objc.id) ?[]const u8 {
    const nsstr: ?objc.id = objc.msgSend(?objc.id, map_item, objc.sel("pointOfInterestCategory"), .{});
    const str = nsstr orelse return null;
    const cstr = objc.fromNSString(str) orelse return null;
    const len = std.mem.len(cstr);
    if (len == 0) return null;
    const copy = std.heap.c_allocator.alloc(u8, len) catch return null;
    @memcpy(copy, cstr[0..len]);
    return copy;
}

/// Format address from placemark components
fn formatAddress(placemark: objc.id) []const u8 {
    const sub_thoroughfare = extractStringField(placemark, "subThoroughfare");
    defer if (sub_thoroughfare.len > 0) std.heap.c_allocator.free(@constCast(sub_thoroughfare));

    const thoroughfare = extractStringField(placemark, "thoroughfare");
    defer if (thoroughfare.len > 0) std.heap.c_allocator.free(@constCast(thoroughfare));

    const locality = extractStringField(placemark, "locality");
    defer if (locality.len > 0) std.heap.c_allocator.free(@constCast(locality));

    const admin_area = extractStringField(placemark, "administrativeArea");
    defer if (admin_area.len > 0) std.heap.c_allocator.free(@constCast(admin_area));

    const postal_code = extractStringField(placemark, "postalCode");
    defer if (postal_code.len > 0) std.heap.c_allocator.free(@constCast(postal_code));

    // Build address parts
    var parts: [3][]const u8 = undefined;
    var part_count: usize = 0;

    // Street: subThoroughfare + thoroughfare
    var street_buf: [512]u8 = undefined;
    var street_len: usize = 0;
    if (sub_thoroughfare.len > 0 and thoroughfare.len > 0) {
        const total = sub_thoroughfare.len + 1 + thoroughfare.len;
        if (total <= street_buf.len) {
            @memcpy(street_buf[0..sub_thoroughfare.len], sub_thoroughfare);
            street_buf[sub_thoroughfare.len] = ' ';
            @memcpy(street_buf[sub_thoroughfare.len + 1 ..][0..thoroughfare.len], thoroughfare);
            street_len = total;
        }
    } else if (thoroughfare.len > 0) {
        @memcpy(street_buf[0..thoroughfare.len], thoroughfare);
        street_len = thoroughfare.len;
    }

    if (street_len > 0) {
        parts[part_count] = street_buf[0..street_len];
        part_count += 1;
    }

    // Locality (city)
    if (locality.len > 0) {
        parts[part_count] = locality;
        part_count += 1;
    }

    // State + postal code
    var state_zip_buf: [256]u8 = undefined;
    var state_zip_len: usize = 0;
    if (admin_area.len > 0 and postal_code.len > 0) {
        const total = admin_area.len + 1 + postal_code.len;
        if (total <= state_zip_buf.len) {
            @memcpy(state_zip_buf[0..admin_area.len], admin_area);
            state_zip_buf[admin_area.len] = ' ';
            @memcpy(state_zip_buf[admin_area.len + 1 ..][0..postal_code.len], postal_code);
            state_zip_len = total;
        }
    } else if (admin_area.len > 0) {
        @memcpy(state_zip_buf[0..admin_area.len], admin_area);
        state_zip_len = admin_area.len;
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

    const result = std.heap.c_allocator.alloc(u8, total_len) catch return "";
    var pos: usize = 0;
    for (0..part_count) |i| {
        if (i > 0) {
            result[pos] = ',';
            result[pos + 1] = ' ';
            pos += 2;
        }
        @memcpy(result[pos..][0..parts[i].len], parts[i]);
        pos += parts[i].len;
    }

    return result;
}

// ---------------------------------------------------------------------------
// Block callback: invoked by MKLocalSearch completion handler
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

    // Get mapItems array from response
    const map_items: ?objc.id = objc.msgSend(?objc.id, resp, objc.sel("mapItems"), .{});
    const items = map_items orelse {
        search_error = SearchError.SearchFailed;
        search_completed = true;
        if (current_run_loop) |rl| CFRunLoopStop(rl);
        return;
    };

    const count = objc.nsArrayCount(items);
    if (count == 0) {
        // Zero results is not an error — just empty
        search_results = std.heap.c_allocator.alloc(Place, 0) catch {
            search_error = SearchError.SearchFailed;
            search_completed = true;
            if (current_run_loop) |rl| CFRunLoopStop(rl);
            return;
        };
        search_completed = true;
        if (current_run_loop) |rl| CFRunLoopStop(rl);
        return;
    }

    const places = std.heap.c_allocator.alloc(Place, count) catch {
        search_error = SearchError.SearchFailed;
        search_completed = true;
        if (current_run_loop) |rl| CFRunLoopStop(rl);
        return;
    };

    for (0..count) |i| {
        const map_item = objc.nsArrayObjectAtIndex(items, i);

        // Name
        const name = extractStringField(map_item, "name");

        // Phone number
        const phone_str = extractStringField(map_item, "phoneNumber");
        const phone: ?[]const u8 = if (phone_str.len > 0) phone_str else null;

        // URL
        const url = extractUrlString(map_item);

        // Category
        const category = extractCategory(map_item);

        // Placemark
        const placemark: objc.id = objc.msgSend(objc.id, map_item, objc.sel("placemark"), .{});

        // Coordinate from placemark
        const coord = objc.msgSend(CLLocationCoordinate2D, placemark, objc.sel("coordinate"), .{});

        // Address
        const address = formatAddress(placemark);

        places[i] = Place{
            .name = name,
            .address = address,
            .latitude = coord.latitude,
            .longitude = coord.longitude,
            .phone = phone,
            .url = url,
            .category = category,
        };
    }

    search_results = places;
    search_completed = true;
    if (current_run_loop) |rl| CFRunLoopStop(rl);
}

// ---------------------------------------------------------------------------
// Convert Zig []const u8 to NSString (handles non-null-terminated slices)
// ---------------------------------------------------------------------------
fn nsStringFromSlice(slice: []const u8) ?objc.id {
    const NSString = objc.getClass("NSString") orelse return null;
    const alloc_obj = objc.msgSend(objc.id, NSString, objc.sel("alloc"), .{});
    // initWithBytes:length:encoding: — encoding 4 = NSUTF8StringEncoding
    const ns_str: ?objc.id = objc.msgSend(
        ?objc.id,
        alloc_obj,
        objc.sel("initWithBytes:length:encoding:"),
        .{ slice.ptr, @as(objc.NSUInteger, slice.len), @as(objc.NSUInteger, 4) },
    );
    return ns_str;
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

pub fn searchPlaces(opts: SearchOptions) SearchError![]Place {
    // Reset module state
    search_results = null;
    search_error = null;
    search_completed = false;

    // Create MKLocalSearchRequest
    const MKLocalSearchRequest = objc.getClass("MKLocalSearchRequest") orelse return SearchError.NotAvailable;
    const req_alloc = objc.msgSend(objc.id, MKLocalSearchRequest, objc.sel("alloc"), .{});
    const request = objc.msgSend(objc.id, req_alloc, objc.sel("init"), .{});

    // Set naturalLanguageQuery
    const query_ns = nsStringFromSlice(opts.query) orelse return SearchError.SearchFailed;
    objc.msgSend(void, request, objc.sel("setNaturalLanguageQuery:"), .{query_ns});

    // Set resultTypes if not "all"
    // MKLocalSearchResultType: address = 1, pointOfInterest = 2
    switch (opts.result_type) {
        .poi => {
            objc.msgSend(void, request, objc.sel("setResultTypes:"), .{@as(objc.NSUInteger, 2)});
        },
        .address => {
            objc.msgSend(void, request, objc.sel("setResultTypes:"), .{@as(objc.NSUInteger, 1)});
        },
        .all => {},
    }

    // Set pointOfInterestFilter if category specified
    if (opts.category_filter) |cat_id| {
        const MKPointOfInterestFilter = objc.getClass("MKPointOfInterestFilter") orelse return SearchError.NotAvailable;
        const cat_nsstr = nsStringFromSlice(cat_id) orelse return SearchError.SearchFailed;

        // Build NSArray with one category string
        const NSArray = objc.getClass("NSArray") orelse return SearchError.NotAvailable;
        const array = objc.msgSend(objc.id, NSArray, objc.sel("arrayWithObject:"), .{cat_nsstr});

        // [[MKPointOfInterestFilter alloc] initWithIncludingCategories:]
        const filter_alloc = objc.msgSend(objc.id, MKPointOfInterestFilter, objc.sel("alloc"), .{});
        const filter = objc.msgSend(objc.id, filter_alloc, objc.sel("initIncludingCategories:"), .{array});

        objc.msgSend(void, request, objc.sel("setPointOfInterestFilter:"), .{filter});
    }

    // Build MKCoordinateRegion from lat/lon/radius
    const lat_delta = (opts.radius / 111320.0) * 2.0;
    const cos_lat = @cos(opts.lat * std.math.pi / 180.0);
    const lon_delta = (opts.radius / (111320.0 * cos_lat)) * 2.0;

    const region = MKCoordinateRegion{
        .center = CLLocationCoordinate2D{
            .latitude = opts.lat,
            .longitude = opts.lon,
        },
        .span = MKCoordinateSpan{
            .latitudeDelta = lat_delta,
            .longitudeDelta = lon_delta,
        },
    };

    // Set region on request.
    // MKCoordinateRegion is 4 x f64 — an HFA on ARM64, passed in FP registers.
    // We use msgSendFn to get a typed function pointer and call it directly.
    const setRegionFn = objc.msgSendFn(void, struct { MKCoordinateRegion });
    setRegionFn(@ptrCast(request), objc.sel("setRegion:"), region);

    // Enforce region as a strict boundary (macOS 15+, MKLocalSearchRegionPriority.required = 1)
    if (objc.msgSend(bool, request, objc.sel("respondsToSelector:"), .{objc.sel("setRegionPriority:")})) {
        objc.msgSend(void, request, objc.sel("setRegionPriority:"), .{@as(objc.NSUInteger, 1)});
    }

    // Create MKLocalSearch with request
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

    // Start the search: [localSearch startWithCompletionHandler:block]
    current_run_loop = CFRunLoopGetCurrent();
    objc.msgSend(void, local_search, objc.sel("startWithCompletionHandler:"), .{@as(objc.id, @ptrCast(&block))});

    // Pump run loop with 10 second timeout
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
        if (place.phone) |phone| {
            if (phone.len > 0) alloc.free(@constCast(phone));
        }
        if (place.url) |url| {
            if (url.len > 0) alloc.free(@constCast(url));
        }
        if (place.category) |cat| {
            if (cat.len > 0) alloc.free(@constCast(cat));
        }
    }
    alloc.free(places);
}
