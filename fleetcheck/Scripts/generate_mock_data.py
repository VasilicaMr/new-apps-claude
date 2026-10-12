#!/usr/bin/env python3
"""
Generates the mock API responses used by FleetCheck's MockAPIClient.

Every file in FleetCheck/Resources/MockData maps 1:1 to an endpoint in
`Endpoint.swift` (see `Endpoint.mockResource`). The data is deterministic
(seeded) and anchored to --as-of so it can be regenerated whenever the
dates start looking stale:

    python3 Scripts/generate_mock_data.py --as-of 2026-10-11

Each vehicle has a "story" baked in so the insights engine has something
to find (an old van eating repair money, an underused van, a car burning
too much fuel, a harsh driver, documents about to expire, ...).
"""

import argparse
import json
import math
import random
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

OUT_DIR = Path(__file__).resolve().parent.parent / "FleetCheck" / "Resources" / "MockData"
HQ = (44.4355, 26.0450)  # Depot, west Bucharest
CITY_CENTER = (44.4268, 26.1025)
HISTORY_DAYS = 180
TRIP_DAYS = 7

FUEL_PRICE = {"diesel": 1.52, "petrol": 1.48, "hybrid": 1.48, "electric": 0.32}  # EUR per L / kWh

DRIVERS = [
    ("drv-01", "Andrei Popescu"), ("drv-02", "Mihai Ionescu"), ("drv-03", "Elena Dumitru"),
    ("drv-04", "Cristian Stan"), ("drv-05", "Ioana Gheorghe"), ("drv-06", "Vlad Marinescu"),
    ("drv-07", "Radu Constantin"), ("drv-08", "Ana Matei"), ("drv-09", "George Florea"),
    ("drv-10", "Maria Niculescu"),
]

# id, plate, make, model, year, fuel, segment, price, odometer, baseline consumption,
# avg km/day, revenue per km, active probability, consumption factor, harsh factor,
# service interval km, financed, status, story flags
VEHICLES = [
    dict(id="veh-001", plate="B-101-FLT", make="Dacia", model="Logan", year=2021, fuel="petrol", segment="economy",
         price=11900, odo=148_300, base=6.4, km=210, rpk=0.62, active=0.92, cf=1.00, harsh=0.6, svc=15000, financed=False),
    dict(id="veh-002", plate="B-102-FLT", make="Dacia", model="Logan", year=2019, fuel="petrol", segment="economy",
         price=10500, odo=231_900, base=6.6, km=195, rpk=0.60, active=0.90, cf=1.04, harsh=2.6, svc=15000, financed=False),
    dict(id="veh-003", plate="B-103-FLT", make="Skoda", model="Octavia", year=2022, fuel="diesel", segment="sedan",
         price=27500, odo=118_400, base=5.1, km=230, rpk=0.74, active=0.91, cf=1.22, harsh=0.8, svc=30000, financed=True),
    dict(id="veh-004", plate="B-104-FLT", make="Toyota", model="Corolla Hybrid", year=2023, fuel="hybrid", segment="sedan",
         price=26900, odo=74_200, base=4.5, km=220, rpk=0.76, active=0.93, cf=0.98, harsh=0.5, svc=15000, financed=True),
    dict(id="veh-005", plate="B-105-FLT", make="Volkswagen", model="Caddy", year=2020, fuel="diesel", segment="van",
         price=24300, odo=162_700, base=6.2, km=160, rpk=0.95, active=0.86, cf=1.02, harsh=0.9, svc=20000, financed=False),
    dict(id="veh-006", plate="B-106-FLT", make="Ford", model="Transit Custom", year=2017, fuel="diesel", segment="van",
         price=31200, odo=318_600, base=8.1, km=150, rpk=0.98, active=0.78, cf=1.08, harsh=1.0, svc=20000, financed=False),
    dict(id="veh-007", plate="B-107-FLT", make="Renault", model="Kangoo", year=2021, fuel="diesel", segment="van",
         price=21800, odo=64_900, base=5.8, km=120, rpk=0.90, active=0.36, cf=1.00, harsh=0.7, svc=20000, financed=True),
    dict(id="veh-008", plate="B-108-FLT", make="Hyundai", model="Tucson Hybrid", year=2022, fuel="hybrid", segment="suv",
         price=36400, odo=97_300, base=5.9, km=190, rpk=0.88, active=0.85, cf=1.01, harsh=0.7, svc=15000, financed=True),
    dict(id="veh-009", plate="B-109-FLT", make="Toyota", model="Corolla Hybrid", year=2022, fuel="hybrid", segment="sedan",
         price=25900, odo=121_800, base=4.5, km=235, rpk=0.75, active=0.94, cf=0.99, harsh=0.6, svc=15000, financed=False),
    dict(id="veh-010", plate="B-110-FLT", make="Dacia", model="Spring", year=2023, fuel="electric", segment="economy",
         price=21000, odo=41_600, base=14.5, km=140, rpk=0.58, active=0.88, cf=1.00, harsh=0.5, svc=30000, financed=False),
]

PLACES = [
    "Piata Victoriei", "Piata Unirii", "Gara de Nord", "Aeroportul Henri Coanda", "Baneasa Shopping City",
    "AFI Cotroceni", "Pipera Business Park", "Militari Residence", "Titan Park", "Piata Romana",
    "Universitate", "Herastrau Park", "Berceni", "Drumul Taberei", "Floreasca City Center",
    "Obor Market", "Crangasi", "Vitan Mall", "Politehnica", "Mega Mall",
]

GARAGES = ["Auto Service Militari", "Dacia Service Pipera", "Toyota Bavaria Bucuresti",
           "Euro Truck Service", "Hyundai Auto Class", "QuickFit Berceni"]


def iso(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def day(d: date) -> str:
    return d.isoformat()


def write(name: str, payload) -> None:
    path = OUT_DIR / f"{name}.json"
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n")
    print(f"  wrote {path.relative_to(OUT_DIR.parent.parent.parent)}")


def meters_to_deg(lat: float, dn: float, de: float):
    return dn / 111_320, de / (111_320 * math.cos(math.radians(lat)))


def build_company(as_of: date):
    return {
        "id": "cmp-001",
        "name": "Bucharest Mobility SRL",
        "currencyCode": "EUR",
        "timezone": "Europe/Bucharest",
        "dataAsOf": day(as_of),
        "homeBase": {"name": "Main Depot", "latitude": HQ[0], "longitude": HQ[1]},
        "trackingPolicy": {"distanceThresholdMeters": 50, "heartbeatSeconds": 300, "desiredAccuracyMeters": 100},
    }


def build_drivers(rng: random.Random, as_of: date):
    out = []
    for i, (did, name) in enumerate(DRIVERS):
        license_expiry = as_of + timedelta(days=rng.randint(200, 2000))
        if did == "drv-04":
            license_expiry = as_of + timedelta(days=19)  # expiring soon -> insight
        out.append({
            "id": did,
            "name": name,
            "phone": f"+40 7{rng.randint(20, 99)} {rng.randint(100, 999)} {rng.randint(100, 999)}",
            "hireDate": day(as_of - timedelta(days=rng.randint(200, 2400))),
            "licenseExpiry": day(license_expiry),
            "assignedVehicleId": VEHICLES[i]["id"],
        })
    return out


def build_vehicles(rng: random.Random, as_of: date):
    out = []
    for i, v in enumerate(VEHICLES):
        purchase = date(v["year"], rng.randint(1, 6), rng.randint(1, 28))
        last_service_km = (v["odo"] // v["svc"]) * v["svc"]
        next_service_km = last_service_km + v["svc"]
        insurance = as_of + timedelta(days=rng.randint(60, 330))
        inspection = as_of + timedelta(days=rng.randint(45, 700))
        road_tax = as_of + timedelta(days=rng.randint(40, 300))
        if v["id"] == "veh-005":
            insurance = as_of + timedelta(days=9)
        if v["id"] == "veh-006":
            inspection = as_of + timedelta(days=4)
            next_service_km = v["odo"] + 600
        if v["id"] == "veh-009":
            next_service_km = v["odo"] + 900
        out.append({
            "id": v["id"],
            "plate": v["plate"],
            "vin": "".join(rng.choice("ABCDEFGHJKLMNPRSTUVWXYZ0123456789") for _ in range(17)),
            "make": v["make"],
            "model": v["model"],
            "year": v["year"],
            "fuelType": v["fuel"],
            "segment": v["segment"],
            "color": rng.choice(["White", "Silver", "Black", "Blue", "Grey"]),
            "purchaseDate": day(purchase),
            "purchasePrice": v["price"],
            "odometerKm": v["odo"],
            "baselineConsumption": v["base"],
            "tankCapacity": 27 if v["fuel"] == "electric" else rng.choice([45, 50, 55, 70]),
            "serviceIntervalKm": v["svc"],
            "nextServiceKm": next_service_km,
            "insuranceExpiry": day(insurance),
            "inspectionExpiry": day(inspection),
            "roadTaxExpiry": day(road_tax),
            "assignedDriverId": DRIVERS[i][0],
            "operationalStatus": "inMaintenance" if v["id"] == "veh-008" else "active",
            "monthlyFinancingCost": rng.choice([390, 420, 460, 510]) if v["financed"] else 0,
        })
    return out


def build_daily_metrics(rng: random.Random, as_of: date):
    rows = []
    start = as_of - timedelta(days=HISTORY_DAYS)
    for v in VEHICLES:
        for n in range(HISTORY_DAYS):
            d = start + timedelta(days=n)
            weekend = d.weekday() >= 5
            active = rng.random() < (v["active"] * (0.7 if weekend else 1.0))
            # veh-008 has been in the shop for the last 3 days
            if v["id"] == "veh-008" and (as_of - d).days <= 3:
                active = False
            if not active:
                rows.append({"vehicleId": v["id"], "date": day(d), "distanceKm": 0, "drivingMinutes": 0,
                             "idleMinutes": 0, "energyUsed": 0, "energyCost": 0, "revenue": 0, "jobsCompleted": 0,
                             "harshBrakingEvents": 0, "harshAccelerationEvents": 0, "speedingEvents": 0})
                continue
            km = max(15.0, rng.gauss(v["km"], v["km"] * 0.22))
            consumption = v["base"] * v["cf"] * rng.uniform(0.93, 1.08)
            energy = km * consumption / 100
            driving = km / rng.uniform(24, 34) * 60
            idle_share = rng.uniform(0.08, 0.16) if v["id"] != "veh-005" else rng.uniform(0.22, 0.30)
            per100 = km / 100
            rows.append({
                "vehicleId": v["id"],
                "date": day(d),
                "distanceKm": round(km, 1),
                "drivingMinutes": round(driving),
                "idleMinutes": round(driving * idle_share),
                "energyUsed": round(energy, 2),
                "energyCost": round(energy * FUEL_PRICE[v["fuel"]] * rng.uniform(0.97, 1.03), 2),
                "revenue": round(km * v["rpk"] * rng.uniform(0.85, 1.15), 2),
                "jobsCompleted": max(1, round(km / rng.uniform(14, 22))),
                "harshBrakingEvents": int(rng.random() * per100 * 1.2 * v["harsh"] + 0.3),
                "harshAccelerationEvents": int(rng.random() * per100 * 0.9 * v["harsh"] + 0.2),
                "speedingEvents": int(rng.random() * per100 * 1.0 * v["harsh"] + 0.1),
            })
    return rows


def build_trips(rng: random.Random, as_of: date, metrics):
    trips = []
    recent = [m for m in metrics if (as_of - date.fromisoformat(m["date"])).days <= TRIP_DAYS and m["distanceKm"] > 0]
    tz = timezone(timedelta(hours=3))
    counter = 1
    for m in recent:
        d = date.fromisoformat(m["date"])
        n = max(2, m["jobsCompleted"])
        weights = [rng.uniform(0.6, 1.4) for _ in range(n)]
        total_w = sum(weights)
        clock = datetime(d.year, d.month, d.day, rng.randint(6, 8), rng.randint(0, 59), tzinfo=tz)
        driver = DRIVERS[int(m["vehicleId"][-3:]) - 1][0]
        for w in weights:
            share = w / total_w
            km = m["distanceKm"] * share
            minutes = max(6, m["drivingMinutes"] * share)
            start_place, end_place = rng.sample(PLACES, 2)
            end = clock + timedelta(minutes=minutes)
            avg_speed = km / (minutes / 60)
            trips.append({
                "id": f"trp-{counter:05d}",
                "vehicleId": m["vehicleId"],
                "driverId": driver,
                "startTime": iso(clock),
                "endTime": iso(end),
                "startAddress": start_place,
                "endAddress": end_place,
                "distanceKm": round(km, 1),
                "revenue": round(m["revenue"] * share, 2),
                "averageSpeedKmh": round(avg_speed, 1),
                "maxSpeedKmh": round(min(130, avg_speed * rng.uniform(1.8, 2.6)), 1),
            })
            counter += 1
            clock = end + timedelta(minutes=rng.randint(5, 40))
    return trips


def build_maintenance(rng: random.Random, as_of: date, vehicles):
    records = []
    counter = 1

    def add(v, when: date, odo, category, description, parts, labor, garage, downtime, unplanned):
        nonlocal counter
        records.append({
            "id": f"mnt-{counter:04d}", "vehicleId": v["id"], "date": day(when), "odometerKm": int(odo),
            "category": category, "description": description, "partsCost": round(parts, 2),
            "laborCost": round(labor, 2), "garage": garage, "downtimeDays": downtime, "isUnplanned": unplanned,
        })
        counter += 1

    for v, spec in zip(vehicles, VEHICLES):
        purchase = date.fromisoformat(v["purchaseDate"])
        age_days = (as_of - purchase).days
        km_per_day = spec["odo"] / age_days
        garage = rng.choice(GARAGES)

        def at_km(km):
            return purchase + timedelta(days=int(km / km_per_day))

        km = spec["svc"]
        while km <= spec["odo"]:
            add(v, at_km(km), km, "service", "Scheduled service: oil, filters, inspection",
                rng.uniform(110, 190), rng.uniform(60, 110), garage, 1, False)
            km += spec["svc"]

        for k in range(40_000, spec["odo"], 45_000):
            add(v, at_km(k), k, "tires", "Replace 4 tires", rng.uniform(280, 420), 40, "QuickFit Berceni", 0, False)
        for k in range(60_000, spec["odo"], 60_000):
            add(v, at_km(k), k, "brakes", "Front brake pads and discs", rng.uniform(140, 260), rng.uniform(60, 90),
                garage, 1, False)

        for _ in range(rng.randint(0, 2)):
            k = rng.randint(10_000, spec["odo"])
            add(v, at_km(k), k, rng.choice(["electrical", "bodywork"]),
                rng.choice(["Replace 12V battery", "Bumper repair after parking damage", "Replace headlight bulb",
                            "Windshield chip repair"]),
                rng.uniform(40, 220), rng.uniform(30, 160), garage, rng.randint(0, 2), True)

        if v["id"] == "veh-006":
            for days_ago, cat, desc, parts, labor, down in [
                (310, "engine", "EGR valve replacement", 640, 280, 3),
                (240, "transmission", "Clutch kit and dual-mass flywheel", 1380, 520, 4),
                (150, "engine", "Turbocharger rebuild", 1150, 420, 5),
                (90, "electrical", "Alternator replacement", 390, 140, 2),
                (35, "engine", "Injector replacement (2x)", 820, 260, 3),
                (12, "suspension", "Rear leaf springs and shock absorbers", 610, 230, 2),
            ]:
                when = as_of - timedelta(days=days_ago)
                add(v, when, spec["odo"] - days_ago * spec["km"] * 0.75, cat, desc, parts, labor,
                    "Euro Truck Service", down, True)
        if v["id"] == "veh-008":
            add(v, as_of - timedelta(days=3), spec["odo"], "electrical", "Hybrid inverter diagnostics (in progress)",
                0, 180, "Hyundai Auto Class", 4, True)
        if v["id"] == "veh-002":
            add(v, as_of - timedelta(days=58), spec["odo"] - 9_000, "brakes",
                "Brake pads worn early (aggressive braking)", 120, 70, garage, 1, True)

    records.sort(key=lambda r: r["date"])
    return records


def build_expenses(rng: random.Random, as_of: date, vehicles):
    out = []
    counter = 1

    def add(v, when, category, amount, note):
        nonlocal counter
        out.append({"id": f"exp-{counter:05d}", "vehicleId": v["id"], "date": day(when), "category": category,
                    "amount": round(amount, 2), "note": note})
        counter += 1

    wages = {v["id"]: round(rng.uniform(1050, 1350), 2) for v in vehicles}
    for v in vehicles:
        insurance_renewal = date.fromisoformat(v["insuranceExpiry"]) - timedelta(days=365)
        if insurance_renewal <= as_of:
            add(v, insurance_renewal, "insurance", rng.uniform(620, 1150), "Annual RCA + CASCO")
        tax_paid = date.fromisoformat(v["roadTaxExpiry"]) - timedelta(days=365)
        if tax_paid <= as_of:
            add(v, tax_paid, "roadTax", 58 if v["segment"] != "van" else 96, "Rovinieta 12 months")
        for month in range(12):
            first = (as_of.replace(day=1) - timedelta(days=30 * month)).replace(day=1)
            if v["monthlyFinancingCost"]:
                add(v, first + timedelta(days=4), "financing", v["monthlyFinancingCost"], "Leasing installment")
            add(v, first + timedelta(days=9), "driverWages", wages[v["id"]], "Driver salary incl. taxes")
            add(v, first + timedelta(days=rng.randint(5, 25)), "parking", rng.uniform(25, 70), "Parking & city fees")
            add(v, first + timedelta(days=rng.randint(5, 25)), "cleaning", rng.uniform(18, 40), "Car wash")
            if rng.random() < 0.35:
                add(v, first + timedelta(days=rng.randint(1, 27)), "tolls", rng.uniform(8, 35), "Bridge / highway toll")
            if rng.random() < (0.25 if v["id"] == "veh-002" else 0.05):
                add(v, first + timedelta(days=rng.randint(1, 27)), "fines", rng.choice([58, 116, 290]),
                    "Speeding / parking fine")
    out.sort(key=lambda e: e["date"])
    return out


def build_valuation_models():
    return [
        {"segment": "economy", "firstYearRate": 0.18, "annualRate": 0.11, "expectedAnnualKm": 25000,
         "mileageAdjustmentPer10kKm": 0.025, "residualFloorRate": 0.12},
        {"segment": "sedan", "firstYearRate": 0.20, "annualRate": 0.12, "expectedAnnualKm": 30000,
         "mileageAdjustmentPer10kKm": 0.020, "residualFloorRate": 0.12},
        {"segment": "suv", "firstYearRate": 0.19, "annualRate": 0.11, "expectedAnnualKm": 25000,
         "mileageAdjustmentPer10kKm": 0.020, "residualFloorRate": 0.15},
        {"segment": "van", "firstYearRate": 0.16, "annualRate": 0.10, "expectedAnnualKm": 30000,
         "mileageAdjustmentPer10kKm": 0.015, "residualFloorRate": 0.10},
    ]


def build_geofences():
    return [
        {"id": "geo-01", "name": "Main Depot", "type": "depot", "latitude": HQ[0], "longitude": HQ[1], "radiusMeters": 150},
        {"id": "geo-02", "name": "Pipera Client Hub", "type": "client", "latitude": 44.4830, "longitude": 26.1180, "radiusMeters": 250},
        {"id": "geo-03", "name": "Airport Pickup", "type": "client", "latitude": 44.5711, "longitude": 26.0850, "radiusMeters": 400},
        {"id": "geo-04", "name": "Old Town (restricted)", "type": "restricted", "latitude": 44.4310, "longitude": 26.1010, "radiusMeters": 350},
    ]


def build_live_routes(rng: random.Random):
    """Road-ish loops (L-shaped legs between waypoints) sampled every tick."""
    routes = []
    for v in VEHICLES:
        vid = v["id"]
        if vid == "veh-008":  # parked at the garage
            routes.append({"vehicleId": vid, "tickSeconds": 2, "points": [[44.4512, 26.1310]]})
            continue
        center = (CITY_CENTER[0] + rng.uniform(-0.03, 0.03), CITY_CENTER[1] + rng.uniform(-0.05, 0.05))
        radius_m = rng.uniform(900, 2200)
        waypoints = []
        for k in range(8):
            angle = 2 * math.pi * k / 8 + rng.uniform(-0.2, 0.2)
            r = radius_m * rng.uniform(0.7, 1.2)
            dlat, dlon = meters_to_deg(center[0], r * math.sin(angle), r * math.cos(angle))
            waypoints.append((center[0] + dlat, center[1] + dlon))
        waypoints.append(waypoints[0])

        step_m = rng.uniform(16, 26) if vid != "veh-007" else 8  # meters travelled per 2s tick
        points = []
        for (a, b) in zip(waypoints, waypoints[1:]):
            corner = (a[0], b[1])  # drive east/west first, then north/south
            for (p, q) in ((a, corner), (corner, b)):
                dist = haversine(p, q)
                steps = max(1, int(dist / step_m))
                for s in range(steps):
                    t = s / steps
                    points.append([round(p[0] + (q[0] - p[0]) * t, 6), round(p[1] + (q[1] - p[1]) * t, 6)])
            # a short stop at each waypoint (traffic light / delivery)
            points.extend([[round(b[0], 6), round(b[1], 6)]] * rng.randint(2, 6))
        routes.append({"vehicleId": vid, "tickSeconds": 2, "points": points})
    return routes


def haversine(a, b):
    r = 6_371_000
    p1, p2 = math.radians(a[0]), math.radians(b[0])
    dp, dl = p2 - p1, math.radians(b[1] - a[1])
    h = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(h))


def build_telemetry(rng: random.Random, as_of: date, routes):
    now = datetime(as_of.year, as_of.month, as_of.day, 9, 30, tzinfo=timezone.utc)
    out = []
    for v, route in zip(VEHICLES, routes):
        lat, lon = route["points"][0]
        parked = v["id"] in ("veh-008", "veh-007")
        dtc = []
        if v["id"] == "veh-006":
            dtc = ["P0401", "P0299"]
        if v["id"] == "veh-008":
            dtc = ["P0A94"]
        out.append({
            "vehicleId": v["id"],
            "timestamp": iso(now - timedelta(seconds=rng.randint(5, 90))),
            "latitude": lat, "longitude": lon,
            "speedKmh": 0 if parked else round(rng.uniform(18, 55), 1),
            "headingDegrees": rng.randint(0, 359),
            "ignitionOn": not parked,
            "fuelLevelPercent": 12 if v["id"] == "veh-005" else rng.randint(28, 95),
            "batteryVoltage": 11.7 if v["id"] == "veh-006" else round(rng.uniform(12.4, 14.4), 1),
            "engineTemperatureC": 0 if v["fuel"] == "electric" else (104 if v["id"] == "veh-006" else rng.randint(84, 96)),
            "odometerKm": v["odo"],
            "diagnosticCodes": dtc,
        })
    return out


def build_alerts(as_of: date):
    base = datetime(as_of.year, as_of.month, as_of.day, 9, 0, tzinfo=timezone.utc)

    def a(i, vid, hours_ago, severity, kind, message):
        return {"id": f"alr-{i:03d}", "vehicleId": vid, "timestamp": iso(base - timedelta(hours=hours_ago)),
                "severity": severity, "type": kind, "message": message, "acknowledged": hours_ago > 30}

    return [
        a(1, "veh-006", 1, "critical", "diagnosticCode", "Engine code P0299: turbocharger underboost"),
        a(2, "veh-006", 2, "warning", "batteryLow", "12V battery at 11.7 V while parked"),
        a(3, "veh-005", 3, "warning", "lowFuel", "Fuel level 12% - nearest station 1.2 km"),
        a(4, "veh-002", 5, "warning", "harshBraking", "4 harsh braking events in 20 minutes"),
        a(5, "veh-008", 70, "critical", "diagnosticCode", "Hybrid system code P0A94 - vehicle sent to service"),
        a(6, "veh-003", 8, "info", "geofenceExit", "Left Main Depot at 06:42"),
        a(7, "veh-002", 26, "warning", "speeding", "92 km/h in a 50 km/h zone on Bd. Iuliu Maniu"),
        a(8, "veh-001", 28, "info", "geofenceEnter", "Entered Airport Pickup"),
        a(9, "veh-009", 30, "info", "maintenanceDue", "Service due in less than 1,000 km"),
        a(10, "veh-007", 48, "info", "idle", "Vehicle parked for 52 hours"),
        a(11, "veh-004", 54, "warning", "geofenceEnter", "Entered Old Town (restricted) zone"),
        a(12, "veh-006", 96, "warning", "engineTemperature", "Engine temperature 104 C"),
    ]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--as-of", default=date.today().isoformat(), help="YYYY-MM-DD, the 'today' of the data set")
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()
    as_of = date.fromisoformat(args.as_of)
    rng = random.Random(args.seed)
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    print(f"Generating mock data as of {as_of}")
    vehicles = build_vehicles(rng, as_of)
    metrics = build_daily_metrics(rng, as_of)
    routes = build_live_routes(rng)

    write("company", build_company(as_of))
    write("vehicles", vehicles)
    write("drivers", build_drivers(rng, as_of))
    write("daily_metrics", metrics)
    write("trips", build_trips(rng, as_of, metrics))
    write("maintenance_records", build_maintenance(rng, as_of, vehicles))
    write("expenses", build_expenses(rng, as_of, vehicles))
    write("valuation_models", build_valuation_models())
    write("geofences", build_geofences())
    write("live_routes", routes)
    write("telemetry_latest", build_telemetry(rng, as_of, routes))
    write("alerts", build_alerts(as_of))
    write("location_event_ack", {"accepted": True, "serverTime": iso(datetime.now(timezone.utc)), "nextHeartbeatSeconds": 300})


if __name__ == "__main__":
    main()
