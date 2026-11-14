"""Writes assets/data/competitions.json and teams.json.

Edit the tables below and rerun:  python3 tool/make_seed.py

Everything is invented: the leagues, the clubs and the players. A team row
holds a crest pattern and an index into Palette.teamTints, never a colour.
"""
import json
import random

R = random.Random(20261114)

FIRST = {
    "football": ["Tunde", "Kofi", "Marcus", "Luca", "Ibrahim", "Jonas", "Emeka", "Rafael", "Samir", "Theo",
                 "Dele", "Mateo", "Yusuf", "Callum", "Andre", "Kwame", "Hugo", "Femi", "Niko", "Oscar",
                 "Chidi", "Elias", "Baba", "Joao", "Reece", "Sani", "Milan", "Obi", "Leon", "Tariq"],
    "basketball": ["Jalen", "Amadou", "Tobi", "Malik", "Sekou", "Darius", "Kelechi", "Mamadou", "Zion", "Idris",
                   "Chuma", "Lamar", "Ousmane", "Dayo", "Tyrese", "Babajide", "Moussa", "Kwesi", "Jabari", "Nnamdi"],
    "cricket": ["Arjun", "Rohan", "Imran", "Kieran", "Dinesh", "Shai", "Tom", "Faisal", "Vikram", "Jason",
                "Sunil", "Bilal", "Rashid", "Aiden", "Kunal", "Marlon", "Hamza", "Nikhil", "Callum", "Tendai",
                "Pradeep", "Usman", "Liam", "Kagiso", "Ravi", "Darren", "Anil", "Shadab", "Wes", "Sipho"],
}
LAST = {
    "football": ["Adeyemi", "Mensah", "Okoro", "Bello", "Rossi", "Kalu", "Santos", "Hale", "Diallo", "Weller",
                 "Onuoha", "Marin", "Castell", "Boateng", "Lindqvist", "Okafor", "Reyes", "Ward", "Nwosu", "Petrov",
                 "Achebe", "Fontaine", "Musa", "Keller", "Duarte", "Eze", "Navarro", "Sarr", "Whitlock", "Ibe",
                 "Moreau", "Asante", "Brandt", "Cole", "Teixeira", "Onyeka", "Larsen", "Bangura", "Price", "Vidal"],
    "basketball": ["Okafor", "Diop", "Bello", "Carter", "Traore", "Adebayo", "Mensah", "Sow", "Banks", "Eze",
                   "Kamara", "Brooks", "Ndiaye", "Olatunji", "Reed", "Mutombo", "Asamoah", "Fall", "Greene", "Chukwu",
                   "Kone", "Hayes", "Owusu", "Sylla", "Price", "Nwora", "Toure", "Akins", "Barry", "Ojo"],
    "cricket": ["Rahman", "Mehta", "Khan", "Ashby", "Perera", "Hope", "Latham", "Iqbal", "Nair", "Holder",
                "Fernando", "Qureshi", "Malik", "Marsh", "Desai", "Charles", "Sheikh", "Reddy", "Hartley", "Moyo",
                "Silva", "Tariq", "Bancroft", "Ndlovu", "Kapoor", "Bravo", "Kumar", "Aziz", "Carter", "Zulu",
                "Chopra", "Farooq", "Pillai", "Greaves", "Mistry", "Joseph", "Bashir", "Sharma", "Dube", "Wade"],
}
PATTERNS = ["plain", "stripes", "hoops", "sash", "halves", "chevron", "quarters", "band"]

COMPETITIONS = [
    ("cpl", "Coastal Premier League", "Premier", "football", "Top flight", [
        ("nga", "Northgate Athletic", "NGA", "Northgate", "Gatehouse Park", 86),
        ("hbc", "Harbour City", "HBC", "Harbour City", "The Quay", 83),
        ("iru", "Ironbridge United", "IRU", "Ironbridge", "Foundry Lane", 80),
        ("smr", "Saltmarsh Rovers", "SMR", "Saltmarsh", "Tidewater Ground", 76),
        ("kpk", "Kestrel Park", "KPK", "Kestrel", "Kestrel Park", 78),
        ("dks", "Dockside", "DKS", "Dockside", "Crane Street", 73),
        ("lnh", "Lantern Hill", "LNH", "Lantern Hill", "The Beacon", 71),
        ("rct", "Redcliff Town", "RCT", "Redcliff", "Cliff Road", 69),
    ]),
    ("union", "Union Championship", "Union", "football", "Second tier", [
        ("mrw", "Marlow Wanderers", "MRW", "Marlow", "Weir Meadow", 77),
        ("ash", "Ashdown Albion", "ASH", "Ashdown", "Forest Edge", 75),
        ("fwc", "Fenwick City", "FWC", "Fenwick", "Mill Lane", 74),
        ("thu", "Thornbury United", "THU", "Thornbury", "Briar Field", 72),
        ("csr", "Castlereach", "CSR", "Castlereach", "Keep Road", 71),
        ("oak", "Oakhaven", "OAK", "Oakhaven", "The Grove", 69),
        ("gwf", "Greywater", "GWF", "Greywater", "Slate Park", 68),
        ("smf", "Summerfield", "SMF", "Summerfield", "Long Acre", 66),
    ]),
    ("abl", "Atlantic Basketball League", "ABL", "basketball", "Pro league", [
        ("lag", "Lagos Tide", "LAG", "Lagos", "Tide Arena", 86),
        ("acc", "Accra Comets", "ACC", "Accra", "Comet Dome", 82),
        ("dkr", "Dakar Lions", "DKR", "Dakar", "Lions Hall", 84),
        ("nbo", "Nairobi Heat", "NBO", "Nairobi", "Savannah Court", 78),
        ("cpt", "Cape Storm", "CPT", "Cape Town", "Table Bay Arena", 80),
        ("cai", "Cairo Suns", "CAI", "Cairo", "Delta Centre", 76),
        ("kgl", "Kigali Peaks", "KGL", "Kigali", "Hilltop Arena", 73),
        ("abj", "Abidjan Waves", "ABJ", "Abidjan", "Lagoon Pavilion", 71),
    ]),
    ("t20", "Super Twenty Series", "T20", "cricket", "Twenty over league", [
        ("cbs", "Coral Bay Strikers", "CBS", "Coral Bay", "Reef Oval", 85),
        ("hvh", "Highveld Hawks", "HVH", "Highveld", "Plateau Ground", 82),
        ("pam", "Port Albany Mariners", "PAM", "Port Albany", "Anchor Park", 80),
        ("src", "Sunridge Comets", "SRC", "Sunridge", "Ridge Stadium", 78),
        ("evr", "Emerald Vale Rangers", "EVR", "Emerald Vale", "Vale Green", 77),
        ("sbl", "Stonebridge Lancers", "SBL", "Stonebridge", "Old Bridge Ground", 74),
        ("bhk", "Blue Harbour Kites", "BHK", "Blue Harbour", "Kite Field", 72),
        ("acf", "Amber Coast Flames", "ACF", "Amber Coast", "Beacon Oval", 70),
    ]),
]

FORMATIONS = ["4-3-3", "4-4-2", "3-5-2", "4-2-3-1"]
BENCH_FOOTBALL = ["GK", "DF", "DF", "MF", "MF", "FW", "FW"]
BASKETBALL = ["G", "G", "F", "F", "C", "G", "F", "C", "G"]
CRICKET = ["BAT", "BAT", "BAT", "WK", "BAT", "AR", "AR", "BWL", "BWL", "BWL", "BWL"]


def names(sport, n, used):
    out = []
    while len(out) < n:
        name = f"{R.choice(FIRST[sport])} {R.choice(LAST[sport])}"
        if name not in used and name.split()[1] not in {x.split()[1] for x in out}:
            used.add(name)
            out.append(name)
    return out


def football_roles(formation):
    rows = [int(x) for x in formation.split("-")]
    roles = ["GK"] + ["DF"] * rows[0]
    roles += ["MF"] * sum(rows[1:-1]) + ["FW"] * rows[-1]
    return roles + BENCH_FOOTBALL


def squad(team_id, sport, rating, formation, used):
    roles = {"football": football_roles(formation), "basketball": BASKETBALL, "cricket": CRICKET}[sport]
    people = names(sport, len(roles), used)
    numbers = R.sample(range(2, 40), len(roles))
    out = []
    for i, (role, name) in enumerate(zip(roles, people)):
        starter = i < {"football": 11, "basketball": 5, "cricket": 11}[sport]
        skill = rating + R.randint(-6, 7) - (0 if starter else 7)
        if sport == "basketball" and i == 0:
            skill = rating + 9  # every side has one player the ball finds
        if sport == "cricket" and i < 3:
            skill += 3
        number = 1 if role == "GK" and starter else numbers[i]
        out.append({"id": f"{team_id}-{i + 1}", "name": name, "number": number,
                    "role": role, "rating": max(52, min(95, skill))})
    return out


teams, competitions = [], []
for cid, cname, short, sport, region, rows in COMPETITIONS:
    used = set()
    tints = list(range(8))
    R.shuffle(tints)
    patterns = PATTERNS[:]
    R.shuffle(patterns)
    for i, (tid, name, abbr, city, ground, rating) in enumerate(rows):
        formation = R.choice(FORMATIONS)
        teams.append({
            "id": tid, "name": name, "short": abbr, "city": city, "ground": ground,
            "sport": sport, "rating": rating, "formation": formation,
            "crest": {"pattern": patterns[i], "tint": tints[i]},
            "squad": squad(tid, sport, rating, formation, used),
        })
    # Draw order is shuffled so the strong sides do not all meet in round one.
    order = [r[0] for r in rows]
    R.shuffle(order)
    competitions.append({"id": cid, "name": cname, "short": short, "sport": sport,
                         "region": region, "teams": order})

json.dump(competitions, open("assets/data/competitions.json", "w"), indent=1)
json.dump(teams, open("assets/data/teams.json", "w"), indent=1)
print(len(teams), "teams,", sum(len(t["squad"]) for t in teams), "players")
