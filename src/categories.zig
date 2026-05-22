// MKPointOfInterestCategory mappings
// CLI name -> MKPOICategory NSString value

pub const Entry = struct {
    cli_name: []const u8,
    apple_id: []const u8,
};

pub const all = [_]Entry{
    // macOS 10.15+
    .{ .cli_name = "airport", .apple_id = "MKPOICategoryAirport" },
    .{ .cli_name = "amusement-park", .apple_id = "MKPOICategoryAmusementPark" },
    .{ .cli_name = "aquarium", .apple_id = "MKPOICategoryAquarium" },
    .{ .cli_name = "atm", .apple_id = "MKPOICategoryATM" },
    .{ .cli_name = "bakery", .apple_id = "MKPOICategoryBakery" },
    .{ .cli_name = "bank", .apple_id = "MKPOICategoryBank" },
    .{ .cli_name = "beach", .apple_id = "MKPOICategoryBeach" },
    .{ .cli_name = "brewery", .apple_id = "MKPOICategoryBrewery" },
    .{ .cli_name = "cafe", .apple_id = "MKPOICategoryCafe" },
    .{ .cli_name = "campground", .apple_id = "MKPOICategoryCampground" },
    .{ .cli_name = "car-rental", .apple_id = "MKPOICategoryCarRental" },
    .{ .cli_name = "ev-charger", .apple_id = "MKPOICategoryEVCharger" },
    .{ .cli_name = "fire-station", .apple_id = "MKPOICategoryFireStation" },
    .{ .cli_name = "fitness-center", .apple_id = "MKPOICategoryFitnessCenter" },
    .{ .cli_name = "food-market", .apple_id = "MKPOICategoryFoodMarket" },
    .{ .cli_name = "gas-station", .apple_id = "MKPOICategoryGasStation" },
    .{ .cli_name = "hospital", .apple_id = "MKPOICategoryHospital" },
    .{ .cli_name = "hotel", .apple_id = "MKPOICategoryHotel" },
    .{ .cli_name = "laundry", .apple_id = "MKPOICategoryLaundry" },
    .{ .cli_name = "library", .apple_id = "MKPOICategoryLibrary" },
    .{ .cli_name = "marina", .apple_id = "MKPOICategoryMarina" },
    .{ .cli_name = "movie-theater", .apple_id = "MKPOICategoryMovieTheater" },
    .{ .cli_name = "museum", .apple_id = "MKPOICategoryMuseum" },
    .{ .cli_name = "national-park", .apple_id = "MKPOICategoryNationalPark" },
    .{ .cli_name = "nightlife", .apple_id = "MKPOICategoryNightlife" },
    .{ .cli_name = "park", .apple_id = "MKPOICategoryPark" },
    .{ .cli_name = "parking", .apple_id = "MKPOICategoryParking" },
    .{ .cli_name = "pharmacy", .apple_id = "MKPOICategoryPharmacy" },
    .{ .cli_name = "police", .apple_id = "MKPOICategoryPolice" },
    .{ .cli_name = "post-office", .apple_id = "MKPOICategoryPostOffice" },
    .{ .cli_name = "public-transport", .apple_id = "MKPOICategoryPublicTransport" },
    .{ .cli_name = "restaurant", .apple_id = "MKPOICategoryRestaurant" },
    .{ .cli_name = "restroom", .apple_id = "MKPOICategoryRestroom" },
    .{ .cli_name = "school", .apple_id = "MKPOICategorySchool" },
    .{ .cli_name = "stadium", .apple_id = "MKPOICategoryStadium" },
    .{ .cli_name = "store", .apple_id = "MKPOICategoryStore" },
    .{ .cli_name = "theater", .apple_id = "MKPOICategoryTheater" },
    .{ .cli_name = "university", .apple_id = "MKPOICategoryUniversity" },
    .{ .cli_name = "winery", .apple_id = "MKPOICategoryWinery" },
    .{ .cli_name = "zoo", .apple_id = "MKPOICategoryZoo" },
    // macOS 15.0+
    .{ .cli_name = "animal-service", .apple_id = "MKPOICategoryAnimalService" },
    .{ .cli_name = "automotive-repair", .apple_id = "MKPOICategoryAutomotiveRepair" },
    .{ .cli_name = "baseball", .apple_id = "MKPOICategoryBaseball" },
    .{ .cli_name = "basketball", .apple_id = "MKPOICategoryBasketball" },
    .{ .cli_name = "beauty", .apple_id = "MKPOICategoryBeauty" },
    .{ .cli_name = "bowling", .apple_id = "MKPOICategoryBowling" },
    .{ .cli_name = "castle", .apple_id = "MKPOICategoryCastle" },
    .{ .cli_name = "convention-center", .apple_id = "MKPOICategoryConventionCenter" },
    .{ .cli_name = "distillery", .apple_id = "MKPOICategoryDistillery" },
    .{ .cli_name = "fairground", .apple_id = "MKPOICategoryFairground" },
    .{ .cli_name = "fishing", .apple_id = "MKPOICategoryFishing" },
    .{ .cli_name = "fortress", .apple_id = "MKPOICategoryFortress" },
    .{ .cli_name = "golf", .apple_id = "MKPOICategoryGolf" },
    .{ .cli_name = "go-kart", .apple_id = "MKPOICategoryGoKart" },
    .{ .cli_name = "hiking", .apple_id = "MKPOICategoryHiking" },
    .{ .cli_name = "kayaking", .apple_id = "MKPOICategoryKayaking" },
    .{ .cli_name = "landmark", .apple_id = "MKPOICategoryLandmark" },
    .{ .cli_name = "mailbox", .apple_id = "MKPOICategoryMailbox" },
    .{ .cli_name = "mini-golf", .apple_id = "MKPOICategoryMiniGolf" },
    .{ .cli_name = "music-venue", .apple_id = "MKPOICategoryMusicVenue" },
    .{ .cli_name = "national-monument", .apple_id = "MKPOICategoryNationalMonument" },
    .{ .cli_name = "planetarium", .apple_id = "MKPOICategoryPlanetarium" },
    .{ .cli_name = "rock-climbing", .apple_id = "MKPOICategoryRockClimbing" },
    .{ .cli_name = "rv-park", .apple_id = "MKPOICategoryRVPark" },
    .{ .cli_name = "skate-park", .apple_id = "MKPOICategorySkatePark" },
    .{ .cli_name = "skating", .apple_id = "MKPOICategorySkating" },
    .{ .cli_name = "skiing", .apple_id = "MKPOICategorySkiing" },
    .{ .cli_name = "soccer", .apple_id = "MKPOICategorySoccer" },
    .{ .cli_name = "spa", .apple_id = "MKPOICategorySpa" },
    .{ .cli_name = "surfing", .apple_id = "MKPOICategorySurfing" },
    .{ .cli_name = "swimming", .apple_id = "MKPOICategorySwimming" },
    .{ .cli_name = "tennis", .apple_id = "MKPOICategoryTennis" },
    .{ .cli_name = "volleyball", .apple_id = "MKPOICategoryVolleyball" },
};

pub fn findByCliName(name: []const u8) ?*const Entry {
    for (&all) |*entry| {
        if (std.mem.eql(u8, entry.cli_name, name)) return entry;
    }
    return null;
}

pub fn findByAppleId(apple_id: []const u8) ?*const Entry {
    for (&all) |*entry| {
        if (std.mem.eql(u8, entry.apple_id, apple_id)) return entry;
    }
    return null;
}

const std = @import("std");
