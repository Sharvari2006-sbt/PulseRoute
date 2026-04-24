import math

def haversine_dist(c1, c2):
    """
    Calculate the great circle distance between two points 
    on the earth (specified in decimal degrees)
    c1, c2 are tuples of (lat, lng)
    """
    lat1, lon1 = c1
    lat2, lon2 = c2
    
    # Convert decimal degrees to radians 
    lat1, lon1, lat2, lon2 = map(math.radians, [lat1, lon1, lat2, lon2])

    # Haversine formula 
    dlon = lon2 - lon1 
    dlat = lat2 - lat1 
    a = math.sin(dlat/2)**2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon/2)**2
    c = 2 * math.asin(math.sqrt(a)) 
    r = 6371 # Radius of earth in kilometers. Use 3956 for miles.
    return c * r

def check_detour_efficiency(driver_start: tuple, driver_end: tuple, mission_loc: tuple) -> bool:
    """
    Determines if a detour to mission_loc is efficient.
    Returns True if the detour adds less than 20% to the total original distance.
    
    Args:
        driver_start: (lat, lng)
        driver_end: (lat, lng)
        mission_loc: (lat, lng)
    """
    original_distance = haversine_dist(driver_start, driver_end)
    detour_distance = haversine_dist(driver_start, mission_loc) + haversine_dist(mission_loc, driver_end)
    
    if original_distance == 0:
        return detour_distance == 0
        
    added_distance_ratio = (detour_distance - original_distance) / original_distance
    
    return added_distance_ratio < 0.20
