import json
from datetime import datetime
from collections import defaultdict
import math
import re

# --- Core calculations ---


def haversine_distance(lat1, lon1, lat2, lon2):
    """Distance in meters between two lat/lon points"""
    R = 6371000
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)

    a = (
        math.sin(dphi / 2) ** 2
        + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    )
    return 2 * R * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def parse_point(lonlat_string):
    """Extract (lon, lat) from POINT string like 'POINT (-122.1759 48.1492)'"""
    if not lonlat_string:
        return None
    match = re.search(r"POINT \(([+-]?\d+\.?\d*) ([+-]?\d+\.?\d*)\)", lonlat_string)
    if match:
        return float(match.group(1)), float(match.group(2))
    return None


def extract_points(data):
    """Extract (timestamp, lat, lon) tuples from tracking data"""
    points = []

    for record in data:
        if not isinstance(record, dict):
            continue

        timestamp = record.get("timestamp")
        lonlat = record.get("lonlat")

        if timestamp and lonlat:
            coords = parse_point(lonlat)
            if coords:
                lon, lat = coords
                points.append((timestamp, lat, lon))

    return sorted(points, key=lambda p: p[0])


def calculate_velocities(points):
    """Returns list of (timestamp, velocity_m_s, time_delta_s)"""
    velocities = []

    for i in range(1, len(points)):
        t1, lat1, lon1 = points[i - 1]
        t2, lat2, lon2 = points[i]

        time_delta = t2 - t1

        if time_delta > 0:
            distance = haversine_distance(lat1, lon1, lat2, lon2)
            velocity = distance / time_delta
            velocities.append((t2, velocity, time_delta))

    return velocities


# --- Aggregations ---


def average_velocity(velocities, min_velocity=0.5):
    """Average velocity filtering out stopped/stationary points"""
    moving = [(v, dt) for _, v, dt in velocities if v >= min_velocity]
    if not moving:
        return 0.0

    total_distance = sum(v * dt for v, dt in moving)
    total_time = sum(dt for _, dt in moving)
    return total_distance / total_time if total_time > 0 else 0.0


def total_driving_time(velocities, min_velocity=0.5):
    """Total time spent moving in seconds"""
    return sum(dt for _, v, dt in velocities if v >= min_velocity)


def daily_summary(velocities, min_velocity=0.5):
    """Group driving time by date"""
    daily = defaultdict(float)

    for timestamp, velocity, time_delta in velocities:
        if velocity >= min_velocity:
            dt = datetime.fromtimestamp(timestamp)
            date = dt.date().isoformat()
            daily[date] += time_delta

    return dict(daily)


# --- Main ---


def analyze_party(json_path):
    """Analyze single party's tracking data"""
    with open(json_path) as f:
        data = json.load(f)

    points = extract_points(data)
    velocities = calculate_velocities(points)

    avg_vel = average_velocity(velocities)
    drive_time = total_driving_time(velocities)
    daily = daily_summary(velocities)

    return {
        "average_velocity_m_s": avg_vel,
        "average_velocity_km_h": avg_vel * 3.6,
        "total_driving_time_hours": drive_time / 3600,
        "daily_driving_hours": {d: t / 3600 for d, t in daily.items()},
        "point_count": len(points),
    }


def compare_parties(party1_path, party2_path):
    """Compare two parties and print results"""
    party1 = analyze_party(party1_path)
    party2 = analyze_party(party2_path)

    print("\n=== PARTY 1 ===")
    print(f"Points: {party1['point_count']}")
    print(f"Avg velocity: {party1['average_velocity_km_h']:.1f} km/h")
    print(f"Total driving: {party1['total_driving_time_hours']:.2f} hours")
    print("\nDaily breakdown:")
    for date, hours in sorted(party1["daily_driving_hours"].items()):
        print(f"  {date}: {hours:.2f} hours")

    print("\n=== PARTY 2 ===")
    print(f"Points: {party2['point_count']}")
    print(f"Avg velocity: {party2['average_velocity_km_h']:.1f} km/h")
    print(f"Total driving: {party2['total_driving_time_hours']:.2f} hours")
    print("\nDaily breakdown:")
    for date, hours in sorted(party2["daily_driving_hours"].items()):
        print(f"  {date}: {hours:.2f} hours")

    return party1, party2


if __name__ == "__main__":
    import sys

    if len(sys.argv) != 3:
        print("Usage: python script.py <party1.json> <party2.json>")
        sys.exit(1)

    compare_parties(sys.argv[1], sys.argv[2])
