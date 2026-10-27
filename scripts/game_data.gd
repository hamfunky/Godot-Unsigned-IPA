extends RefCounted
## All tunable numbers live here. Balance changes should only need edits in this file.
##
## The shop is a 3-station chain, like Idle Miner's shaft -> elevator -> warehouse:
##   BAYS        detail cars. Finished cars wait in the bay (their value piles up as "keys").
##   VALET       drives down the lane, collects finished cars from the bays, brings them up.
##   FRONT DESK  hands keys back to customers and takes payment. Only this makes cash.
## Your income is limited by the slowest station (the bottleneck).

const MAX_LEVEL := 400

# ------------------------------------------------------------------ bays

const MAX_BAYS := 20

# Cost to build bay n (bay 0 is free). v0.17 whole-economy tuning (tools/sim/tune_world.py):
# Bay 5 ~20 min, renovation 1 ~30 min. Bays 7-20 keep the old shape x RENO_TIER_INCOME per
# renovation tier (renovations: 3x the next bay's build cost).
# v0.17g (Hamza's playtest: Bay 7 was a 200x wall ~20 min in): Bays 7-10 smoothed (tools/sim/sim_v17g.py).
const BAY_BUILD_COSTS := [0.0, 61.09, 3666.0, 8.553e4, 2.077e6, 1.897e7, 3.0e8, 4.0e9, 6.0e10, 1.2e12,
	1.707e15, 4.552e16, 1.138e18, 3.414e19, 9.104e20, 8.535e22, 2.39e24, 6.828e25, 2.048e27, 6.828e28]

const BAY_BASE_IPS := 1.0        # income/sec of bay 0 at level 1 (before boosts)
const BAY_IPS_GROWTH := 8.0      # each deeper bay earns this many times more
const BAY_BASE_TIME := 4.0       # seconds per car in bay 0
const BAY_TIME_STEP := 0.5       # each deeper bay takes this much longer per car
const PC_LEVEL := 100             # v0.18 (Hamza, 19 Oct): from Paint Correction (bay Lv 100) a car takes at least
const PC_MIN_CAR_TIME := 9.0      # this many seconds, so foam + hand wash + polish all play out. Pay per car scales
                                  # with it, so income per second is unchanged. Rare-car pay ignores it.
const BAY_LEVEL_COST := 12.0     # cost of bay 0 level 1 -> 2
const BAY_LEVEL_COST_GROWTH := 12.0  # each deeper bay's levels cost this many times more
const BAY_LEVEL_GROWTH := 1.10   # cost multiplier per level

# Boost ladder for bays. Reaching each level upgrades the bay's service.
# mult = income multiplier, crew = detailers visible in the bay from that level.
const BAY_BOOSTS := [
	{"level": 1, "name": "Quick Wash", "mult": 1.0, "crew": 1},
	{"level": 10, "name": "Foam Cannon", "mult": 2.0, "crew": 1},
	{"level": 25, "name": "Full Detail", "mult": 2.0, "crew": 2},
	{"level": 50, "name": "Clay Bar & Decon", "mult": 3.0, "crew": 2},
	{"level": 100, "name": "Paint Correction", "mult": 3.0, "crew": 3},
	{"level": 150, "name": "Interior Steam Clean", "mult": 2.0, "crew": 3},
	{"level": 200, "name": "Ceramic Coating", "mult": 3.0, "crew": 4},
	{"level": 250, "name": "Engine Bay Detail", "mult": 2.0, "crew": 4},
	{"level": 300, "name": "Graphene Coating", "mult": 3.0, "crew": 5},
	{"level": 350, "name": "Show Car Prep", "mult": 2.0, "crew": 5},
	{"level": 400, "name": "Paint Protection Film", "mult": 5.0, "crew": 6},
]

# ------------------------------------------------------------------ valet

# Valet + front desk (v0.17b, after Hamza's playtest): they start ~2x the first bay and sit at
# about 1.5x the bays early if you level them alongside (roughly half what you put into bays
# each), so they need regular upgrades but never fall far behind. Capacity grows 1.05x per
# level (on top of linear): late, big cities hit a "wall" where they can't keep up even at
# Lv 400 - on purpose (Hamza): specialist managers will get you past it later.
const VALET_BASE_CAP := 6.0   # $ of cars the valet carries per trip at level 1
const VALET_CAP_GROWTH := 1.05  # extra capacity growth per level (on top of linear)
# v0.17g (Hamza): the valet drives calmer, and its DRIVING speed only steps up at its boost levels
# (10, 25, 50 ...): to what the old +2%/level curve gave at that level. Every level still makes it load
# faster (+2%/level) and carry more. To keep the money the same, it carries VALET_CAP_COMP x more, plus
# whatever speed the step lags behind the old curve (so it moves the same or a little more per second).
const VALET_FLOOR_TIME := 1.8    # seconds to drive one bay up or down at level 1 (was 1.2)
const VALET_CAP_COMP := 1.72     # v0.17g 1.5 (= 1.8 / 1.2, calmer driving); v0.19p x1.15 more for the slower,
                                 # visible loading, so it still moves the same money or a bit more (x1.02 .. x1.19)
const VALET_SPEED_PER_LEVEL := 0.02  # the speed curve: +2% per level (driving takes it at each boost level)
const VALET_LOAD_TIME := 0.9     # seconds to load at each bay (v0.19p, Hamza: loading is a real, visible step: the
                                 # keys / cash hop from the cabinet into the ute; was 0.25). Loading Speed +2%/level.
const VALET_UNLOAD_TIME := 0.5   # seconds to unload at the front desk
const VALET_LEVEL_COST := 15.0
const VALET_LEVEL_GROWTH := 1.11

const VALET_BOOSTS := [
	{"level": 1, "name": "Old Ute", "mult": 1.0, "crew": 1},
	{"level": 10, "name": "Key Cabinet", "mult": 2.0, "crew": 1},
	{"level": 25, "name": "Dual Cab Ute", "mult": 2.0, "crew": 1},
	{"level": 50, "name": "Second Valet", "mult": 3.0, "crew": 2},
	{"level": 100, "name": "V8 Ute", "mult": 3.0, "crew": 2},
	{"level": 150, "name": "Valet App", "mult": 2.0, "crew": 2},
	{"level": 200, "name": "Car Transporter", "mult": 3.0, "crew": 3},
	{"level": 250, "name": "Radio Dispatch", "mult": 2.0, "crew": 3},
	{"level": 300, "name": "Double-Deck Transporter", "mult": 3.0, "crew": 3},
	{"level": 350, "name": "Fleet Tracking", "mult": 2.0, "crew": 4},
	{"level": 400, "name": "Helipad Delivery", "mult": 5.0, "crew": 4},
]

# ------------------------------------------------------------------ front desk

const DESK_BASE_CAP := 6.0     # $ processed per cycle at level 1
const DESK_CAP_GROWTH := 1.05
const DESK_CYCLE_TIME := 3.0     # seconds per checkout cycle
const DESK_LEVEL_COST := 15.0
const DESK_LEVEL_GROWTH := 1.11

const DESK_BOOSTS := [
	{"level": 1, "name": "Cash Tin", "mult": 1.0, "crew": 1},
	{"level": 10, "name": "Card Reader", "mult": 2.0, "crew": 1},
	{"level": 25, "name": "Second Cashier", "mult": 2.0, "crew": 2},
	{"level": 50, "name": "Booking App", "mult": 3.0, "crew": 2},
	{"level": 100, "name": "Waiting Lounge", "mult": 3.0, "crew": 3},
	{"level": 150, "name": "Loyalty Program", "mult": 2.0, "crew": 3},
	{"level": 200, "name": "Express Checkout", "mult": 3.0, "crew": 3},
	{"level": 250, "name": "Coffee Bar", "mult": 2.0, "crew": 4},
	{"level": 300, "name": "Showroom", "mult": 3.0, "crew": 4},
	{"level": 350, "name": "Membership Club", "mult": 2.0, "crew": 4},
	{"level": 400, "name": "Concierge", "mult": 5.0, "crew": 5},
]

# ------------------------------------------------------------------ managers
# Two tabs when you hire for a station:
#  MANAGERS - hired with cash, random rarity (Junior / Senior / Executive), an ability
#             and a crew. They belong to the city they were hired in.
#  PREMIUM  - unique named people (only one of each exists). Found by collecting 6
#             clues into their dossier, then "called in" for a small flat fee. Work in
#             any city, one station at a time. Ability + passive (always on while
#             seated) + perks at Lv20 and Lv50. Levelled up with Certs.
# Either kind automates the station it sits at. One manager per station.

const MANAGER_AREAS := ["bay", "valet", "desk"]
const MANAGER_HIRE_BASE := {"bay": 10.0, "valet": 25.0, "desk": 25.0}  # x city scale; cheap first hires for the tutorial
const MANAGER_HIRE_GROWTH := 3.0  # each hire in the same area (in that city) costs this many times more (v0.17d: was 8)

# Cash-hired managers (v0.17d, Idle Miner style): short abilities with short recharges, so using
# them becomes a habit. Executive = 80% off for 10 min, the big "save up and spend" window.
# duration/cooldown in seconds (speed abilities last SPEED_DURATION_MULT x longer).
const RARITIES := [
	{"name": "Junior", "odds": 70.0, "mult": 2.0, "discount": 0.30, "duration": 60.0, "cooldown": 240.0, "color": "8bc34a"},
	{"name": "Senior", "odds": 25.0, "mult": 3.0, "discount": 0.50, "duration": 240.0, "cooldown": 720.0, "color": "42a5f5"},
	{"name": "Executive", "odds": 5.0, "mult": 5.0, "discount": 0.80, "duration": 600.0, "cooldown": 1200.0, "color": "ffb300"},
]
const MANAGER_NAMES := ["Bazza", "Kylie", "Brodie", "Jess", "Tommo", "Raj", "Luca", "Mo", "Nguyen", "Sione",
	"Macca", "Chloe", "Wazza", "Deano", "Rhys", "Zoe", "Hamo", "Steph", "Benny", "Lachie"]

const PREMIUM_RARITIES := [   # named (premium) managers
	# mult/discount/duration = the ability. passive = base passive at Lv1. cert = Certs per level base.
	{"name": "Common", "color": "9e9e9e", "mult": 2.0, "discount": 0.20, "duration": 120.0, "passive": 0.10, "cert": 2.0},
	{"name": "Uncommon", "color": "66bb6a", "mult": 2.5, "discount": 0.30, "duration": 180.0, "passive": 0.15, "cert": 3.0},
	{"name": "Rare", "color": "42a5f5", "mult": 3.0, "discount": 0.40, "duration": 240.0, "passive": 0.25, "cert": 4.0},
	{"name": "Epic", "color": "ab47bc", "mult": 4.0, "discount": 0.50, "duration": 300.0, "passive": 0.40, "cert": 6.0},
	{"name": "Legendary", "color": "ffb300", "mult": 5.0, "discount": 0.60, "duration": 420.0, "passive": 0.60, "cert": 8.0},
]
const ABILITY_COOLDOWN := 1800.0  # PREMIUM managers: seconds after an ability ends before it can be used again (cash tiers have their own "cooldown")
const SPEED_DURATION_MULT := 2.0  # "speed" abilities last this much longer than "income" ones (steady vs burst pick)

# PREMIUM signature abilities (v0.17d): unique moves, not a plain multiplier. The premium overhaul
# will give every premium manager one (see PREMIUM_PROPOSAL.md). "duration" replaces the rarity's.
#  tip_jar (Dazza): for the duration, everything his bay finishes goes into his tip jar instead of
#           the key cabinet. When it ends he cashes the jar: x TIP_JAR_MULT (Lv1) .. TIP_JAR_MULT_MAX
#           (Lv50), paid straight into your wallet (skips the valet and the front desk).
const SIGNATURE_ABILITIES := {
	"tip_jar": {"id": "tip_jar", "name": "Tip Jar", "kind": "signature", "duration": 30.0,
		"desc": "this bay's cars go in his tip jar, then he cashes it x%s straight to you"},
	# v0.19o (PREMIUM_PROPOSAL.md): Kev's SHORTCUT (valet): for 30s (Lv1) .. 60s (Lv50) every car finished in
	# his city skips the key cabinets and the valet and lands straight in the pickup lot. Use it when the
	# valet has the red "!". Cooldown 30 min.
	"shortcut": {"id": "shortcut", "name": "Shortcut", "kind": "signature", "duration": 30.0, "duration_max": 60.0,
		"cooldown": 1800.0, "desc": "for %ss every finished car skips the valet: straight to the pickup lot"},
	# Priya's FINISH LINE (desk): for 60s, in her city the last 10 levels before each station's next boost
	# cost 50% less (Lv50: last 20 levels, 70% off). Multiplies with other discounts (95% ceiling).
	# Cooldown 45 min.
	"finish_line": {"id": "finish_line", "name": "Finish Line", "kind": "signature", "duration": 60.0,
		"cooldown": 2700.0, "desc": "the last %s levels before every station's next boost cost %s less"},
	# v0.19q Marco's CONVOY (valet, Uncommon): his next 5 (Lv1) .. 8 (Lv50) trips carry x10, with two extra utes
	# following the main one. Hamza: 3 trips (the proposal) is over too fast; 5-8 is ~2-3 min ahead at 5 bays,
	# longer in deeper shops. Cooldown 40 min. Counted in trips, not seconds ("duration" only for old code).
	"clear_lot": {"id": "clear_lot", "name": "Clear the Lot", "kind": "signature", "duration": 2.0, "cooldown": 1800.0,
		"desc": "checks out the whole pickup lot right now, x%s"},
	"showstopper": {"id": "showstopper", "name": "Showstopper", "kind": "signature", "duration": 120.0, "cooldown": 1800.0,
		"desc": "her bay's next car is a show car: x%s pay and followers"},
	"mates_rates": {"id": "mates_rates", "name": "Mate's Rates", "kind": "signature", "duration": 120.0, "cooldown": 1800.0,
		"desc": "his bay's next %s levels are free"},
	"loyalty_card": {"id": "loyalty_card", "name": "Loyalty Card", "kind": "signature", "duration": 60.0, "cooldown": 1800.0,
		"desc": "every checkout also brings +%s followers"},
	"tow_truck": {"id": "tow_truck", "name": "Tow Truck", "kind": "signature", "duration": 120.0, "cooldown": 1800.0,
		"desc": "the next trip has no carry limit: it empties every key cabinet"},
	"convoy": {"id": "convoy", "name": "Convoy", "kind": "signature", "duration": 120.0, "cooldown": 2400.0,
		"desc": "his next %s trips carry x10, with two more utes following"},
	# v0.19t: the Uncommon bay + desk signatures (Hamza: "happy with whatever you think")
	"foam_cannon": {"id": "foam_cannon", "name": "Foam Cannon", "kind": "signature", "duration": 45.0, "duration_max": 90.0,
		"cooldown": 1800.0, "desc": "for %ss his bay and the bays either side earn x%s"},
	"flash_polish": {"id": "flash_polish", "name": "Flash Polish", "kind": "signature", "duration": 120.0, "cooldown": 1800.0,
		"desc": "her bay's next %s cars are polished in a flash"},
	"training_day": {"id": "training_day", "name": "Training Day", "kind": "signature", "duration": 60.0, "duration_max": 90.0,
		"cooldown": 1800.0, "desc": "for %ss every bay works like it's %s levels higher"},
	"referral": {"id": "referral", "name": "Referral", "kind": "signature", "duration": 120.0, "cooldown": 2400.0,
		"desc": "a happy customer sends a friend: a rare car rolls in now"},
}
# v0.19t Uncommons: Gazza FOAM CANNON (bay): his bay + both neighbours x3 .. x5 for 45 .. 90s.
#   Yuki FLASH POLISH (bay): her bay's next 10 .. 20 cars take FLASH_POLISH_TIME each. Counted (ends after the last).
#   Lukas TRAINING DAY (bay): for 60 .. 90s every bay in his city earns like it's +10 .. +25 levels (services included).
#   Rosa REFERRAL (desk): a rare car rolls into the pickup lot now (or right after the one that's here), 40 min recharge.
# v0.19t DAILY DELIVERY: a parcel waits in the pickup lot once a (local) day; the 7-day track loops and NEVER resets
# (miss a day and you just carry on where you were: calm, no streak pressure).
const DELIVERY_FROM_BAYS := 6   # the first parcel turns up once Bay 6 is built (after the first renovation)
const DELIVERY_REWARDS := [
	{"kind": "booster", "booster": "x2_30m", "n": 2},
	{"kind": "gloss", "n": 15},
	{"kind": "case", "file": "basic", "n": 1},
	{"kind": "booster", "booster": "x3_1h", "n": 1},
	{"kind": "gloss", "n": 30},
	{"kind": "booster", "booster": "x5_2h", "n": 1},
	{"kind": "case", "file": "classified", "n": 1, "gloss": 50},
]
# v0.19t the SHOP CAT: naps on the forecourt; pet her for hearts, the first pet of a day leaves a small treat.
const CAT_NAME := "Suds"
const CAT_TREAT_GLOSS := 5
# v0.19t DECOR (a Shine Bucks sink, Hamza 21 Oct: they pile up with little to spend on): bought once, shown in
# every city, each adds DECOR_FOLLOWERS followers an hour (curb appeal), also while away.
const DECOR := [
	{"id": "bunting", "name": "Bunting", "desc": "Bright flags along the valet's fence", "price": 40},
	{"id": "palms", "name": "Potted Palm", "desc": "A palm beside the front desk", "price": 60},
	{"id": "neon", "name": "Neon OPEN Sign", "desc": "Glows over the showroom (best at night)", "price": 90},
	{"id": "balloons", "name": "Balloons", "desc": "A bunch of balloons on the pickup lot sign", "price": 120},
	{"id": "fountain", "name": "Fountain", "desc": "A little fountain on the lawn", "price": 180},
	{"id": "gold_sign", "name": "Gold Sign", "desc": "Gold trim round your shop sign", "price": 300},
]
const DECOR_FOLLOWERS := 1.0
# v0.19t customer reviews on the Reputation card (3 shown, changing every day; their stars sit around your rating)
const REVIEWS := [
	"My ute hasn't been this clean since the day I drove it off the lot.",
	"Dropped off a family wagon full of crumbs, picked up a showroom car.",
	"They got the dog hair out. ALL of it. Witchcraft.",
	"Friendly crew, fair prices, and the foam cannon is a show in itself.",
	"I could see my reflection in the bonnet. Bit of a shock, needed a haircut.",
	"Came for a quick wash, stayed for the free coffee and the chat.",
	"The valet parked my car better than I ever have.",
	"Ten out of ten, would get bird-bombed again just to come back.",
	"Booked a full detail before selling my car. Now I don't want to sell it.",
	"They treated my old hatchback like it was a supercar. Legends.",
	"Quick, careful, and they remembered my name the second time.",
	"Wheels so shiny my neighbour asked if they were new.",
	"Honestly cheaper than therapy, and my car smells amazing.",
	"I left the windows down at the beach once. They fixed my mistake.",
	"Spotless. Even the cup holders. I didn't know they came in that colour.",
	"The cashier counted my change faster than I could find my wallet.",
	"Got a polish and a pep talk. Both were excellent.",
	"Five stars for the shop cat alone.",
	"Watching them work is weirdly relaxing. Car looks great too.",
	"My kids call it the bubble car wash and beg to come along.",
	"They found three lost fries and a twenty dollar note. Kept neither.",
	"Ceramic coat still beading water months later. Worth every cent.",
	"Mud from a weekend off-road, gone in an afternoon.",
	"Proper detailers. They care about the little things.",
	"Paint correction took years off my car. Wish they did people.",
	"Clean car, clean conscience. See you next month.",
	"Rolled in dusty, rolled out glowing.",
	"Best wax on my side of town, no contest.",
]
const REVIEW_NAMES := ["Darren", "Priya", "Mel", "Tom", "Aisha", "Kenji", "Lena", "Bruno", "Sophie", "Raj", "Hannah", "Marcus",
	"Yasmin", "Callum", "Ines", "Dev", "Chloe", "Omar", "Ruby", "Felix", "Nadia", "Sam", "Grace", "Leo"]
# v0.19t RAINY DAYS: the sky clouds over now and then (each RAIN_WINDOW_H hours of the real clock has a RAIN_CHANCE,
# the same for everyone); muddy cars pay RAIN_PAY_MULT while it rains. Calm: grey sky + rain streaks, no sound.
const RAIN_WINDOW_H := 3.0
const RAIN_CHANCE := 0.18
const RAIN_PAY_MULT := 1.25
# v0.19t CAR OF THE WEEK: one everyday model per city per week (from the city's first-bay tier): it pays
# COTW_PAY_MULT and brings COTW_FOLLOWERS followers whenever one is washed.
const COTW_PAY_MULT := 3.0
const COTW_FOLLOWERS := 3.0
const SHOP_NAME_MAX := 22   # v0.19t: the player's own shop name on the sign
const FOAM_CANNON_MULT := [3.0, 5.0]
const FLASH_POLISH_CARS := [10, 20]
const FLASH_POLISH_TIME := 0.3
const TRAINING_DAY_LEVELS := [10, 25]
# v0.19r: the early Commons' signatures (Hamza OK'd 26 Oct). All 30 min recharge. Lv1 .. Lv50 ranges below.
#   Shazza CLEAR THE LOT (desk): checks out the whole pickup lot right now and pays it x1.5 .. x2.
#   Tash SHOWSTOPPER (bay): her bay's next car is a show car: x25 .. x50 pay, +5 .. +10 followers.
#   Jono MATE'S RATES (bay): his bay's next 5 .. 10 levels are free.
#   Bec LOYALTY CARD (desk): for 60s every checkout also brings +1 .. +2 followers.
#   Mick TOW TRUCK (valet): the next trip has no carry limit: it empties every key cabinet in the shop.
const CLEAR_LOT_MULT := [1.5, 2.0]
const SHOW_CAR_MULT := [25.0, 50.0]
const SHOW_CAR_FOLLOWERS := [5.0, 10.0]
const MATES_RATES_LEVELS := [5, 10]
const LOYALTY_FOLLOWERS := [1.0, 2.0]
const CONVOY_TRIPS := [5, 8]     # Lv1 .. Lv50
const CONVOY_MULT := 10.0
const FINISH_LINE_LEVELS := [10, 20]      # window Lv1 .. Lv50
const FINISH_LINE_DISCOUNT := [0.5, 0.7]  # off Lv1 .. Lv50
const DISCOUNT_FLOOR := 0.05              # all level discounts multiply, but you always pay at least 5%
const TIP_JAR_MULT := 3.0
const TIP_JAR_MULT_MAX := 5.0

# kind: "income" (x income/capacity), "speed" (x speed), "discount" (% off level-ups)
const ABILITIES := {
	"bay": [
		{"id": "foam_party", "name": "Foam Party", "kind": "income", "desc": "Bay income x%s"},
		{"id": "elbow_grease", "name": "Elbow Grease", "kind": "speed", "desc": "Bay works x%s faster"},
		{"id": "trade_prices", "name": "Trade Prices", "kind": "discount", "desc": "Bay level-ups %s off"},
	],
	"valet": [
		{"id": "lead_foot", "name": "Lead Foot", "kind": "speed", "desc": "Valet drives and loads x%s faster"},
		{"id": "big_trailer", "name": "Big Trailer", "kind": "income", "desc": "Valet carries x%s more"},
		{"id": "fleet_deal", "name": "Fleet Deal", "kind": "discount", "desc": "Valet level-ups %s off"},
	],
	"desk": [
		{"id": "upsell", "name": "Upsell", "kind": "income", "desc": "Desk processes x%s more"},
		{"id": "express_lane", "name": "Express Lane", "kind": "speed", "desc": "Checkout x%s faster"},
		{"id": "supplier_deal", "name": "Supplier Deal", "kind": "discount", "desc": "Desk level-ups %s off"},
	],
}

# Crews match car classes. Bonuses:
#  SPECIALIST: a bay manager whose crew matches the class of the car being detailed
#              gets CREW_SPECIALIST_BONUS on that car. (Your Book display steers the
#              customer mix, so pick managers that match the cars you attract.)
#  CHAIN: bay manager in the same crew as BOTH valet + desk managers -> CREW_CHAIN_BONUS.
#  PAIR:  valet + desk managers in the same crew -> both get CREW_PAIR_BONUS.
const CREWS := [
	{"id": "jdm", "name": "JDM Crew", "color": "e53935"},
	{"id": "euro", "name": "Euro Crew", "color": "1e88e5"},
	{"id": "muscle", "name": "Muscle Crew", "color": "fb8c00"},
	{"id": "offroad", "name": "4x4 Crew", "color": "43a047"},
]
const CREW_SPECIALIST_BONUS := 1.5
const CREW_CHAIN_BONUS := 1.5
const CREW_PAIR_BONUS := 1.25


const MAX_MANAGER_LEVEL := 50
const PASSIVE_PER_LEVEL := 0.04       # passive grows +4% of its base per level
const DURATION_PER_LEVEL := 0.01      # ability lasts +1% per level
const CERT_GROWTH := 1.08             # Certs for the next level = rarity cert x 1.08^(level-1)
const CALL_FEE := 100.0               # flat signing fee (local currency) once a dossier is complete
const PROMOTIONS := [[1, "Rookie"], [10, "Pro"], [20, "Lead"], [35, "Chief"], [50, "Master"]]

const CLUES := ["shirt", "pants", "shoes", "hair", "face", "tool"]
const CLUE_NAMES := {"shirt": "Shirt", "pants": "Pants", "shoes": "Shoes", "hair": "Hair", "face": "Face", "tool": "Signature tool"}

# Passive while seated: bay = this bay's income, valet = what it carries, desk = checkout.
const PASSIVE_TEXT := {"bay": "This bay earns +%s", "valet": "Valet carries +%s", "desk": "Checkout handles +%s"}

# Perks. Lv20 = small, Lv50 = big.
const PERKS := {
	"cooldown": {"name": "Quick Recovery", "desc": "Ability recharges 25% faster", "value": 0.25},
	"duration": {"name": "Stamina", "desc": "Ability lasts 30% longer", "value": 0.30},
	"crew_cars": {"name": "Crew Regular", "desc": "Their crew's cars pay +25% in this city", "value": 0.25},
	"vip_pay": {"name": "VIP Handler", "desc": "Rare cars pay +30% in this city", "value": 0.30},
	"passive_x2": {"name": "Veteran", "desc": "Passive doubled", "value": 2.0},
	"city_income": {"name": "Shop Boss", "desc": "This whole city earns +30%", "value": 0.30},
	"wildcard": {"name": "All-Rounder", "desc": "Counts as every crew (specialist, chain, pair)", "value": 1.0},
	"ability_plus": {"name": "Signature Move", "desc": "Ability is one step stronger (+x1 / +10% off)", "value": 1.0},
}

# Legendary managers have a unique, big passive that works while they're seated anywhere.
const LEGEND_PASSIVES := {
	"mirror": {"name": "Mirror Finish", "desc": "EVERY city earns +25%", "value": 0.25},
	"autopilot": {"name": "Autopilot", "desc": "Managers in this city use their abilities by themselves", "value": 1.0},
	"vip_magnet": {"name": "VIP Magnet", "desc": "Rare cars come twice as often and pay x2 everywhere", "value": 2.0},
}

# skin 0-4, hair colour, style 0-3 (short / long / bun / cap), shirt, pants, shoes, tool
const NAMED_MANAGERS := [
	# ---- Common
	{"id": "dazza", "name": "Dazza", "rarity": 0, "area": "bay", "crew": "offroad", "ability": "tip_jar", "perk20": "duration", "perk50": "passive_x2",
		"look": {"skin": 0, "hair": "6a4e2e", "style": 3, "shirt": "f9a825", "pants": "37474f", "shoes": "5d4037", "tool": "sponge"}},
	{"id": "shazza", "name": "Shazza", "rarity": 0, "area": "desk", "crew": "muscle", "ability": "clear_lot", "perk20": "cooldown", "perk50": "city_income",
		"look": {"skin": 4, "hair": "d9b36c", "style": 1, "shirt": "ec407a", "pants": "1a237e", "shoes": "212121", "tool": "card"}},
	{"id": "kev", "name": "Kev", "rarity": 0, "area": "valet", "crew": "muscle", "ability": "shortcut", "perk20": "duration", "perk50": "passive_x2",
		"look": {"skin": 1, "hair": "111111", "style": 0, "shirt": "e53935", "pants": "263238", "shoes": "fafafa", "tool": "keys"}},
	{"id": "tash", "name": "Tash", "rarity": 0, "area": "bay", "crew": "euro", "ability": "showstopper", "perk20": "cooldown", "perk50": "passive_x2",
		"look": {"skin": 0, "hair": "a33b20", "style": 2, "shirt": "26a69a", "pants": "455a64", "shoes": "212121", "tool": "spray"}},
	{"id": "jono", "name": "Jono", "rarity": 0, "area": "bay", "crew": "jdm", "ability": "mates_rates", "perk20": "crew_cars", "perk50": "ability_plus",
		"look": {"skin": 2, "hair": "2c1b10", "style": 0, "shirt": "5c6bc0", "pants": "3e2723", "shoes": "8d6e63", "tool": "wrench"}},
	{"id": "bec", "name": "Bec", "rarity": 0, "area": "desk", "crew": "euro", "ability": "loyalty_card", "perk20": "duration", "perk50": "passive_x2",
		"look": {"skin": 4, "hair": "2c1b10", "style": 2, "shirt": "7e57c2", "pants": "212121", "shoes": "c62828", "tool": "coffee"}},
	{"id": "mick", "name": "Mick", "rarity": 0, "area": "valet", "crew": "offroad", "ability": "tow_truck", "perk20": "cooldown", "perk50": "city_income",
		"look": {"skin": 3, "hair": "111111", "style": 3, "shirt": "558b2f", "pants": "4e342e", "shoes": "3e2723", "tool": "radio"}},
	# ---- Uncommon
	{"id": "gazza", "name": "Gazza", "rarity": 1, "area": "bay", "crew": "muscle", "ability": "foam_cannon", "perk20": "crew_cars", "perk50": "passive_x2",
		"look": {"skin": 0, "hair": "d9b36c", "style": 0, "shirt": "ff7043", "pants": "1565c0", "shoes": "fafafa", "tool": "foam"}},
	{"id": "yuki", "name": "Yuki", "rarity": 1, "area": "bay", "crew": "jdm", "ability": "flash_polish", "perk20": "duration", "perk50": "ability_plus",
		"look": {"skin": 4, "hair": "111111", "style": 1, "shirt": "f06292", "pants": "fafafa", "shoes": "f06292", "tool": "polisher"}},
	{"id": "marco", "name": "Marco", "rarity": 1, "area": "valet", "crew": "euro", "ability": "convoy", "perk20": "vip_pay", "perk50": "passive_x2",
		"look": {"skin": 1, "hair": "2c1b10", "style": 0, "shirt": "fafafa", "pants": "1a237e", "shoes": "5d4037", "tool": "keys"}},
	{"id": "priya", "name": "Priya", "rarity": 1, "area": "desk", "crew": "jdm", "ability": "finish_line", "perk20": "cooldown", "perk50": "city_income",
		"look": {"skin": 2, "hair": "111111", "style": 2, "shirt": "00897b", "pants": "37474f", "shoes": "212121", "tool": "clipboard"}},
	{"id": "lukas", "name": "Lukas", "rarity": 1, "area": "bay", "crew": "euro", "ability": "training_day", "perk20": "duration", "perk50": "wildcard",
		"look": {"skin": 4, "hair": "d9b36c", "style": 0, "shirt": "1e88e5", "pants": "212121", "shoes": "212121", "tool": "spray"}},
	{"id": "rosa", "name": "Rosa", "rarity": 1, "area": "desk", "crew": "offroad", "ability": "referral", "perk20": "vip_pay", "perk50": "passive_x2",
		"look": {"skin": 1, "hair": "4e342e", "style": 1, "shirt": "c62828", "pants": "3e2723", "shoes": "6d4c41", "tool": "card"}},
	# ---- Rare
	{"id": "tony", "name": "Two-Bucket Tony", "rarity": 2, "area": "bay", "crew": "muscle", "ability": "foam_party", "perk20": "crew_cars", "perk50": "city_income",
		"look": {"skin": 0, "hair": "111111", "style": 0, "shirt": "212121", "pants": "1565c0", "shoes": "fafafa", "tool": "sponge"}},
	{"id": "hana", "name": "Hana", "rarity": 2, "area": "bay", "crew": "jdm", "ability": "elbow_grease", "perk20": "cooldown", "perk50": "passive_x2",
		"look": {"skin": 4, "hair": "6a1b9a", "style": 2, "shirt": "fafafa", "pants": "212121", "shoes": "6a1b9a", "tool": "polisher"}},
	{"id": "bruno", "name": "Bruno", "rarity": 2, "area": "valet", "crew": "muscle", "ability": "big_trailer", "perk20": "duration", "perk50": "wildcard",
		"look": {"skin": 2, "hair": "111111", "style": 3, "shirt": "ff8f00", "pants": "263238", "shoes": "212121", "tool": "radio"}},
	{"id": "fatima", "name": "Fatima", "rarity": 2, "area": "desk", "crew": "euro", "ability": "upsell", "perk20": "vip_pay", "perk50": "ability_plus",
		"look": {"skin": 2, "hair": "111111", "style": 2, "shirt": "3949ab", "pants": "212121", "shoes": "fafafa", "tool": "clipboard"}},
	{"id": "ollie", "name": "Ollie", "rarity": 2, "area": "bay", "crew": "offroad", "ability": "trade_prices", "perk20": "crew_cars", "perk50": "passive_x2",
		"look": {"skin": 0, "hair": "a33b20", "style": 3, "shirt": "43a047", "pants": "5d4037", "shoes": "3e2723", "tool": "wrench"}},
	# ---- Epic
	{"id": "sergei", "name": "Sergei Claybar", "rarity": 3, "area": "bay", "crew": "euro", "ability": "foam_party", "perk20": "duration", "perk50": "city_income",
		"look": {"skin": 4, "hair": "9e9e9e", "style": 0, "shirt": "263238", "pants": "263238", "shoes": "b71c1c", "tool": "polisher"}},
	{"id": "kaito", "name": "Kaito Drift", "rarity": 3, "area": "valet", "crew": "jdm", "ability": "lead_foot", "perk20": "cooldown", "perk50": "ability_plus",
		"look": {"skin": 4, "hair": "f5f5f5", "style": 1, "shirt": "d32f2f", "pants": "212121", "shoes": "fafafa", "tool": "keys"}},
	{"id": "aisha", "name": "Aisha", "rarity": 3, "area": "desk", "crew": "muscle", "ability": "express_lane", "perk20": "vip_pay", "perk50": "wildcard",
		"look": {"skin": 3, "hair": "111111", "style": 1, "shirt": "ffd600", "pants": "212121", "shoes": "212121", "tool": "card"}},
	{"id": "rhonda", "name": "Big Rhonda", "rarity": 3, "area": "bay", "crew": "offroad", "ability": "elbow_grease", "perk20": "crew_cars", "perk50": "passive_x2",
		"look": {"skin": 1, "hair": "ff7043", "style": 2, "shirt": "6d4c41", "pants": "33691e", "shoes": "3e2723", "tool": "foam"}},
	# ---- Legendary
	{"id": "mori", "name": "Mirror Mori", "rarity": 4, "area": "bay", "crew": "jdm", "ability": "foam_party", "perk20": "duration", "perk50": "wildcard", "legend": "mirror",
		"look": {"skin": 4, "hair": "111111", "style": 0, "shirt": "fafafa", "pants": "fafafa", "shoes": "111111", "tool": "polisher"}},
	{"id": "gaffer", "name": "The Gaffer", "rarity": 4, "area": "desk", "crew": "muscle", "ability": "upsell", "perk20": "cooldown", "perk50": "city_income", "legend": "autopilot",
		"look": {"skin": 0, "hair": "9e9e9e", "style": 3, "shirt": "37474f", "pants": "263238", "shoes": "5d4037", "tool": "clipboard"}},
	{"id": "simone", "name": "Simone Laurent", "rarity": 4, "area": "valet", "crew": "euro", "ability": "big_trailer", "perk20": "vip_pay", "perk50": "ability_plus", "legend": "vip_magnet",
		"look": {"skin": 1, "hair": "2c1b10", "style": 1, "shirt": "880e4f", "pants": "212121", "shoes": "880e4f", "tool": "keys"}},
]
const STARTER_MANAGER := "dazza"     # whole dossier: reward for Hometown run 1's first renovation

# Case Files: only from the Hometown Garage (v0.17c), never sold without limit.
# A file holds `cards` cards, revealed one at a time. Each card rolls a manager rarity
# (`odds`), then a manager of that rarity you haven't finished (prefers dossiers you've
# started; the same manager can come up on two cards), then how many clues: 1-6 by
# CLUE_ROLL_ODDS, capped at the file's `max_clues`. A card never repeats a clue you have:
# clues beyond what that manager is missing become Certs. 6 clues = an instant full
# dossier: a jackpot that only Classified Files can give, a few times in a whole run.
const CASE_FILES := [
	{"id": "basic", "name": "Case File", "cards": 2, "max_clues": 2, "certs": 5, "odds": [60.0, 28.0, 10.0, 2.0, 0.0], "color": "8d6e63"},
	{"id": "detailed", "name": "Detailed Case File", "cards": 3, "max_clues": 3, "certs": 15, "odds": [30.0, 35.0, 22.0, 10.0, 3.0], "color": "1e88e5"},
	{"id": "classified", "name": "Classified File", "cards": 4, "max_clues": 6, "certs": 40, "odds": [0.0, 20.0, 40.0, 28.0, 12.0], "color": "ffb300"},
]
const CLUE_ROLL_ODDS := [45.0, 30.0, 15.0, 7.0, 2.5, 0.5]   # chance of 1, 2, 3, 4, 5, 6 clues on a card (capped per file)
const CASE_STARTED_PREF := 0.6      # chance a clue goes to a dossier you've already started
const LEFTOVER_CLUE_CERTS := 3      # every dossier of that rarity done -> Certs instead

# Certs from playing the shops. Case Files only come from the Hometown Garage (v0.17c):
# your first premium manager (Dazza's dossier) is a Hometown run 1 reward.
const STAR_CERTS := 10
const PRESTIGE_CERTS := 25
const VIP_CERTS := 3

# ------------------------------------------------------------------ misc

# Premium currency for reaching boost levels (Lv 10, 25, 50...): the 1st boost on
# a station gives BOOST_GLOSS[0], the 2nd BOOST_GLOSS[1], every later one BOOST_GLOSS_REST.
const BOOST_GLOSS := [5, 3]
const BOOST_GLOSS_REST := 1

# v0.19v (Hamza 27 Oct): no offline cap and no Night Shift: time away always earns in full.

const CAR_COLORS := ["e63946", "f1faee", "457b9d", "1d3557", "f4a261", "2a9d8f", "8338ec",
	"ffbe0b", "2b2d42", "adb5bd"]

# ------------------------------------------------------------------ world: countries + cities
# The world has COUNTRIES (own currency + own cash wallet) that each have 5 CITIES.
# Every city is its own shop (bays, levels, managers) and they ALL earn at the same
# time: the city on screen runs live, the others earn their idle rate in the background.
# Each city in world order costs and earns CITY_SCALE_GROWTH x more than the last
# (bigger city, bigger jobs). Cities prestige up to MAX_PRESTIGE times: each
# prestige upgrades the premises (see PREMISES), costs cash, resets that city only,
# and multiplies its income by PRESTIGE_MULT. A prestiged early city can out-earn a
# newer city - that leapfrog is the core strategy.
# All prices here are placeholders for playtesting.

const CITY_SCALE_GROWTH := 10.0
const CITY_UNLOCK_BASE := 1.768e7        # x city scale, paid in that country's currency ...
const CITY_UNLOCK_GROWTH := 14.27         # ... x this per city already open there (Detroit x14.27, LA x14.27^2 ...)
# Fixed unlock prices that replace the formula (v0.17d, Hamza: Detroit should open around when Lima's Bay 8 -> 9
# gets slow, ~600M/s). PLACEHOLDERS to tune by playtest. Note Lima's prestige needs LA (3rd city).
const CITY_UNLOCK_OVERRIDE := {"detroit": 4.0e9, "los_angeles": 5.0e12}   # v0.17g: Detroit ~50 min, LA ~3.5h (sim, no ads)
const PRESTIGE_MULT := 3.0   # v0.19t: was 4 (x1024 at prestige 5 made the whole game ~3 weeks, tools/econ_sim.gd)
const MAX_PRESTIGE := 5
const PRESTIGE_COSTS := [3.846e11, 1.686e15, 9.232e17, 5.058e20, 2.771e23]   # x city scale. v0.19t: prestiges 2-5 x8 (tools/econ_sim.gd pacing)
const PRESTIGE_GLOSS := 50             # premium currency per prestige
const PRESTIGE_NEEDS_CITY := 0         # v0.17g (Hamza): no city needed. 0 = off (was 3: "needs your 3rd city")
# v0.17g: a city's FIRST prestige costs the same as unlocking the next city in its country (the player picks:
# expand or prestige). The last city of a country uses PRESTIGE_COSTS[0]. Later prestiges keep PRESTIGE_COSTS.

# Premises = what your shop looks like at each prestige (0 = starting shop).
# tiers = car tier for each of the 20 bays.
const PREMISES := [
	{"name": "Suburban Car Wash", "color": "2b5d8a", "tiers": [1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5]},
	{"name": "Detailing Studio", "color": "37474f", "tiers": [2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 5, 5, 5, 5]},
	{"name": "Performance Garage", "color": "4a148c", "tiers": [2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5]},
	{"name": "Prestige Atelier", "color": "1b5e20", "tiers": [3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5]},
	{"name": "Hypercar Hangar", "color": "263238", "tiers": [3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5]},
	{"name": "Concours Pavilion", "color": "6d4c41", "tiers": [4, 4, 4, 4, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5]},
]

# bias = extra customer weight for car classes in that country (on top of the Book display).
# unlock_cost = price in the PREVIOUS country's currency (needs its last city unlocked).
# v0.19t: about 1.5 days of the previous country's MAXED income (Valet/Desk Lv 400 ceiling, x1e5 per country), so a
# maxed country never waits weeks (tools/econ_sim.gd). Was 7.557e17 / 4.333e25 / 6.2e31 / 2.549e39.
const COUNTRIES := [
	{"id": "usa", "name": "USA", "currency": "USD", "symbol": "$", "color": "1565c0",
		"bias": {"muscle": 2.0, "offroad": 1.0}, "unlock_cost": 0.0,
		"cities": [
			{"id": "lima", "name": "Lima, Ohio"},
			{"id": "detroit", "name": "Detroit"},
			{"id": "los_angeles", "name": "Los Angeles"},
			{"id": "miami", "name": "Miami"},
			{"id": "houston", "name": "Houston, Texas"},
		]},
	{"id": "japan", "name": "Japan", "currency": "JPY", "symbol": "¥", "color": "c62828",
		"bias": {"jdm": 3.0}, "unlock_cost": 5e26,
		"cities": [
			{"id": "shibukawa", "name": "Shibukawa, Gunma"},
			{"id": "osaka", "name": "Osaka"},
			{"id": "nagoya", "name": "Nagoya"},
			{"id": "yokohama", "name": "Yokohama"},
			{"id": "tokyo", "name": "Tokyo"},
		]},
	{"id": "germany", "name": "Germany", "currency": "EUR", "symbol": "€", "color": "424242",
		"bias": {"euro": 3.0}, "unlock_cost": 5e31,
		"cities": [
			{"id": "nurburg", "name": "Nürburg"},
			{"id": "cologne", "name": "Cologne"},
			{"id": "stuttgart", "name": "Stuttgart"},
			{"id": "munich", "name": "Munich"},
			{"id": "berlin", "name": "Berlin"},
		]},
	{"id": "australia", "name": "Australia", "currency": "AUD", "symbol": "A$", "color": "ef6c00",
		"bias": {"muscle": 2.0, "offroad": 2.0}, "unlock_cost": 5e36,
		"cities": [
			{"id": "wagga", "name": "Wagga Wagga"},
			{"id": "adelaide", "name": "Adelaide"},
			{"id": "bathurst", "name": "Bathurst"},
			{"id": "melbourne", "name": "Melbourne"},
			{"id": "sydney", "name": "Sydney"},
		]},
	{"id": "uae", "name": "UAE", "currency": "AED", "symbol": "AED ", "color": "00897b",
		"bias": {"euro": 2.0}, "unlock_cost": 5e41,
		"cities": [
			{"id": "ajman", "name": "Ajman"},
			{"id": "sharjah", "name": "Sharjah"},
			{"id": "al_ain", "name": "Al Ain"},
			{"id": "abu_dhabi", "name": "Abu Dhabi"},
			{"id": "dubai", "name": "Dubai"},
		]},
]

# ------------------------------------------------------------------ cars
# Every job is a specific car. Brands are ORIGINAL (GTA-style): they hint at a real
# maker's country/style without copying its name. Never use real brands, models,
# badges or logos. (Ids are internal and never shown; keep them so saves still work.)
# Brands: Hoshino, Raiden, Hikari, Kazemoto, Seiza, Tsurugi, Minato (JDM) / Isarwerk,
# Sternwagen, Vierling, Volkmann, Falkner, Rossetti, Bravura, Halden, Celestine,
# Fjellborg, Ashcombe, Harrowgate, Moorland (Euro) / Henderson, Vance, Durant,
# Carrow, Southcross (Muscle/Aussie).
# class = which crew specialises in it. Normal cars all pay the bay's rate; the car
# just decides crew specialist bonuses and what gets logged in your Book.

const CAR_CLASSES := ["jdm", "euro", "muscle", "offroad"]   # same ids as CREWS
const CLASS_NAMES := {"jdm": "JDM", "euro": "Euro", "muscle": "Muscle", "offroad": "4x4"}

const TIER_NAMES := ["", "Bombs", "Daily Drivers", "Enthusiast", "Performance & Luxury", "Exotics"]

const CARS := [
	# tier 1: bombs
	{"id": "swiff", "name": "Minato Breeze", "tier": 1, "class": "jdm"},
	{"id": "corollo98", "name": "Hoshino Pebble '98", "tier": 1, "class": "jdm"},
	{"id": "lanzer", "name": "Tsurugi Lancet", "tier": 1, "class": "jdm"},
	{"id": "pollo", "name": "Volkmann Pip", "tier": 1, "class": "euro"},
	{"id": "fiestah", "name": "Henderson Fizz", "tier": 1, "class": "euro"},
	{"id": "commodoor_vt", "name": "Southcross Larrikin", "tier": 1, "class": "muscle"},
	{"id": "falcone_el", "name": "Henderson Fairway", "tier": 1, "class": "muscle"},
	{"id": "hilox04", "name": "Hoshino Workhorse '04", "tier": 1, "class": "offroad"},
	{"id": "trighton", "name": "Tsurugi Tradie", "tier": 1, "class": "offroad"},
	# tier 2: daily drivers
	{"id": "cammy", "name": "Hoshino Meridian", "tier": 2, "class": "jdm"},
	{"id": "mazdo3", "name": "Kazemoto Kaze", "tier": 2, "class": "jdm"},
	{"id": "civvic", "name": "Hikari Metro", "tier": 2, "class": "jdm"},
	{"id": "gulf", "name": "Volkmann Hatch", "tier": 2, "class": "euro"},
	{"id": "audee_a3", "name": "Vierling Vier", "tier": 2, "class": "euro"},
	{"id": "commodoor_ss", "name": "Southcross Larrikin SV8", "tier": 2, "class": "muscle"},
	{"id": "rangah", "name": "Henderson Ridgeback", "tier": 2, "class": "offroad"},
	{"id": "rav5", "name": "Hoshino Wanderer", "tier": 2, "class": "offroad"},
	# tier 3: enthusiast
	{"id": "wrz", "name": "Seiza Comet RS", "tier": 3, "class": "jdm"},
	{"id": "civvic_z", "name": "Hikari Metro Kaiju", "tier": 3, "class": "jdm"},
	{"id": "nizzan_370", "name": "Raiden Zenith", "tier": 3, "class": "jdm"},
	{"id": "gulf_r", "name": "Volkmann Hatch GTX", "tier": 3, "class": "euro"},
	{"id": "mustank", "name": "Henderson Stallion GT", "tier": 3, "class": "muscle"},
	{"id": "camero", "name": "Vance Corsair", "tier": 3, "class": "muscle"},
	{"id": "landcrusher", "name": "Hoshino Ironbark", "tier": 3, "class": "offroad"},
	{"id": "raptoar", "name": "Henderson Ridgeback Talon", "tier": 3, "class": "offroad"},
	# tier 4: performance & luxury
	{"id": "n3_comp", "name": "Isarwerk Kaiser", "tier": 4, "class": "euro"},
	{"id": "ang_c63", "name": "Sternwagen Schwarz 63", "tier": 4, "class": "euro"},
	{"id": "rz6", "name": "Vierling Turbokombi", "tier": 4, "class": "euro"},
	{"id": "gtz", "name": "Raiden Thunderclap", "tier": 4, "class": "jdm"},
	{"id": "soupra", "name": "Hoshino Raijin", "tier": 4, "class": "jdm"},
	{"id": "hellkat", "name": "Durant Brimstone", "tier": 4, "class": "muscle"},
	{"id": "rangey", "name": "Moorland Sport", "tier": 4, "class": "offroad"},
	{"id": "g_wagan", "name": "Sternwagen Bunker", "tier": 4, "class": "offroad"},
	# tier 5: exotics
	{"id": "gt3rz", "name": "Falkner Kestrel GT", "tier": 5, "class": "euro"},
	{"id": "hurrycane", "name": "Bravura Tempesta", "tier": 5, "class": "euro"},
	{"id": "mcc_702", "name": "Halden Apex", "tier": 5, "class": "euro"},
	{"id": "ferrori_roamer", "name": "Rossetti Strada", "tier": 5, "class": "euro"},
	{"id": "skyliner", "name": "Raiden Skyrunner R", "tier": 5, "class": "jdm"},
	{"id": "nzx", "name": "Hikari Ronin", "tier": 5, "class": "jdm"},
	{"id": "corvetta", "name": "Vance Riptide", "tier": 5, "class": "muscle"},
	{"id": "ewrus", "name": "Bravura Montagna", "tier": 5, "class": "offroad"},
	{"id": "cullinin", "name": "Ashcombe Monarch", "tier": 5, "class": "offroad"},
]

# ------------------------------------------------------------------ VIP visits (rare cars)
# Now and then a rare car rolls into the pickup lot. It waits VIP_LOT_WAIT seconds
# (so you have time to open the game and get boosts ready), then goes to a bay.
# It pays bay pay-per-car x rarity mult, worked out when it FINISHES, so having
# manager income boosts running at that moment pays off.

const VIP_RARITIES := [
	{"name": "Rare", "odds": 70.0, "pay_mult": 25.0, "followers": 10.0, "gloss": 2, "color": "42a5f5"},
	{"name": "Epic", "odds": 25.0, "pay_mult": 75.0, "followers": 50.0, "gloss": 5, "color": "ab47bc"},
	{"name": "Legendary", "odds": 5.0, "pay_mult": 250.0, "followers": 250.0, "gloss": 20, "color": "ffb300"},
]
# country = where it shows up (v0.17c): each country has its own rare visitors, so the
# Book's rare section fills over weeks as you open countries. Hometown gets every
# unlocked country's. rarity: 0 Rare, 1 Epic, 2 Legendary.
const VIP_CARS := [
	# USA
	{"id": "demon", "name": "Durant Inferno", "rarity": 0, "class": "muscle", "color": "4e342e", "country": "usa"},
	{"id": "dune_king", "name": "Henderson Ridgeback Dune King", "rarity": 0, "class": "offroad", "color": "ff8f00", "country": "usa"},
	{"id": "interceptor", "name": "Vance Corsair Interceptor", "rarity": 0, "class": "muscle", "color": "263238", "country": "usa"},
	{"id": "cobrah", "name": "Carrow Serpent", "rarity": 1, "class": "muscle", "color": "1565c0", "country": "usa"},
	{"id": "gt41", "name": "Henderson Endurance", "rarity": 1, "class": "muscle", "color": "0277bd", "country": "usa"},
	{"id": "thunderhawk", "name": "Vance Thunderhawk", "rarity": 2, "class": "muscle", "color": "c62828", "country": "usa"},
	# Japan
	{"id": "nzx_z", "name": "Hikari Ronin Shogun", "rarity": 0, "class": "jdm", "color": "fdd835", "country": "japan"},
	{"id": "rz7", "name": "Kazemoto Vortex", "rarity": 0, "class": "jdm", "color": "c62828", "country": "japan"},
	{"id": "kaminari", "name": "Seiza Comet Kaminari", "rarity": 0, "class": "jdm", "color": "1e88e5", "country": "japan"},
	{"id": "toyoter_2000", "name": "Hoshino Heritage GT", "rarity": 1, "class": "jdm", "color": "f5f5f5", "country": "japan"},
	{"id": "lancet_final", "name": "Tsurugi Lancet Final Edition", "rarity": 1, "class": "jdm", "color": "eceff1", "country": "japan"},
	{"id": "z_toon", "name": "Raiden Skyrunner Z-Spec", "rarity": 2, "class": "jdm", "color": "b0bec5", "country": "japan"},
	# Germany
	{"id": "kaiser_csl", "name": "Isarwerk Kaiser Leichtbau", "rarity": 0, "class": "euro", "color": "fafafa", "country": "germany"},
	{"id": "ringmeister", "name": "Vierling Ringmeister", "rarity": 0, "class": "euro", "color": "455a64", "country": "germany"},
	{"id": "hatch_club", "name": "Volkmann Hatch GTX Clubsport", "rarity": 0, "class": "euro", "color": "d32f2f", "country": "germany"},
	{"id": "wagan6x6", "name": "Sternwagen Bunker 6x6", "rarity": 1, "class": "offroad", "color": "6d4c41", "country": "germany"},
	{"id": "kestrel_rs", "name": "Falkner Kestrel RS", "rarity": 1, "class": "euro", "color": "43a047", "country": "germany"},
	{"id": "silberpfeil", "name": "Sternwagen Silberpfeil", "rarity": 2, "class": "euro", "color": "cfd8dc", "country": "germany"},
	# Australia
	{"id": "hilox_rally", "name": "Hoshino Workhorse Desert Raid", "rarity": 0, "class": "offroad", "color": "fafafa", "country": "australia"},
	{"id": "larrikin_gtsr", "name": "Southcross Larrikin GTS-R", "rarity": 0, "class": "muscle", "color": "ffd600", "country": "australia"},
	{"id": "fairway_p4", "name": "Henderson Fairway Phase Four", "rarity": 0, "class": "muscle", "color": "2e7d32", "country": "australia"},
	{"id": "boomerang", "name": "Southcross Boomerang", "rarity": 1, "class": "muscle", "color": "ff6f00", "country": "australia"},
	{"id": "trailblazer", "name": "Moorland Trailblazer", "rarity": 1, "class": "offroad", "color": "8d6e63", "country": "australia"},
	{"id": "mountain_king", "name": "Southcross Mountain King", "rarity": 2, "class": "muscle", "color": "6a1b9a", "country": "australia"},
	# UAE
	{"id": "phantum", "name": "Ashcombe Sovereign", "rarity": 0, "class": "euro", "color": "212121", "country": "uae"},
	{"id": "continentil", "name": "Harrowgate Grand Tourer", "rarity": 0, "class": "euro", "color": "2e7d32", "country": "uae"},
	{"id": "adventurdor", "name": "Bravura Diavolo", "rarity": 1, "class": "euro", "color": "9ccc28", "country": "uae"},
	{"id": "mcc_q1", "name": "Halden Apex One", "rarity": 1, "class": "euro", "color": "ff9100", "country": "uae"},
	{"id": "laferrori", "name": "Rossetti Ultima", "rarity": 2, "class": "euro", "color": "d50000", "country": "uae"},
	{"id": "chiroon", "name": "Celestine Noir", "rarity": 2, "class": "euro", "color": "1a3c8c", "country": "uae"},
	{"id": "jesco", "name": "Fjellborg Ragnar", "rarity": 2, "class": "euro", "color": "eceff1", "country": "uae"},
]
const VIP_LOT_WAIT := 120.0        # seconds a VIP waits in the lot before heading to a bay
const VIP_JOB_TIME := 20.0         # seconds to detail a VIP car (speed boosts help)
const VIP_MEAN_INTERVAL := 1200.0  # average seconds between VIPs while playing (1 star); none before the first one
const FIRST_VIP_BAYS := 3          # the first rare car is guaranteed when you build this many bays ...
const FIRST_VIP_DELAY := 5.0       # ... this many seconds after
const VIP_WELCOME_CHANCE := 0.4    # chance a VIP is waiting when you come back (away 20m+)
const VIP_DISPLAY_WEIGHT := 4.0    # VIPs you display in your Book are this many times likelier

# ------------------------------------------------------------------ reputation (followers)
# Followers come from VIP visits, new cars logged in your Book, completing Book tiers,
# and cars on display (people see them on your page). Followers set your star rating.
# Stars boost all bay income and bring VIPs more often. Followers + Book are kept
# when you move to a new workshop (prestige).

# v0.19l (Hamza): a new shop starts with NO REVIEWS YET (step 1 = 0 followers). Then 9 rated steps,
# 1.0 1.5 ... 5.0, so the first one is ~10% of the climb. Rough targets (sim not re-run, set from the
# 26 Oct playbot data + the old v0.17 curve; polish Lima first, tune the rest later):
#   1.0 ~10 min (guaranteed: the Bombs set's 9 followers + the first rare car's 10; and any rare car payout
#   brings at least the first review), 1.5 ~day 1, 2.0 day 1-3, 2.5 ~week 1, 3.0 weeks 2-3,
#   3.5 ~month 1, 4.0 ~month 2, 4.5 ~month 4, 5.0 ~month 6 (about when the last country opens).
const STAR_THRESHOLDS := [0.0, 15.0, 150.0, 600.0, 4000.0, 30000.0, 150000.0, 500000.0, 1500000.0, 5000000.0]
# One more step than before, so each gives a touch less: 9 steps x1.18 = x4.44 at 5.0 (was 8 x1.2 = x4.30),
# rare cars 9 x 22% = 2.98x as often (was 8 x 25% = 3x).
const STAR_INCOME_BONUS := 1.18    # bay income x this per rated step (No reviews = x1)
const STAR_VIP_BONUS := 0.22       # +22% rare car visits per rated step
const NEW_CAR_FOLLOWERS := 1.0     # x car tier, for each first-time car
# followers per hour for each car on display, by tier 1-5 (VIP cars use VIP_DISPLAY_FPH by rarity)
const DISPLAY_FPH := [0.0, 0.4, 1.0, 3.0, 8.0, 20.0]
const VIP_DISPLAY_FPH := [40.0, 100.0, 250.0]

# ------------------------------------------------------------------ the Book
# Every car you've detailed gets logged. Put cars on display to attract more of
# their class (customer mix) and grow followers. Completing a whole tier = bonus.

const BASE_DISPLAY_SLOTS := 3
const DISPLAY_SLOT_STARS := [5, 7]   # +1 slot at these steps (= 2.5 and 3.5 stars, same ratings as before v0.19l)
const MAX_BOUGHT_SLOTS := 3          # extra slots buyable with premium currency
const TIER_SET_INCOME_BONUS := 1.1   # x income for each completed tier set (permanent)
const TIER_SET_GLOSS := 50

# ------------------------------------------------------------------ premium currency
# Bought with real money later. Also earned from VIPs, stars and Book sets.
# The name is a placeholder: change PREMIUM_NAME and it updates everywhere.

const PREMIUM_NAME := "Shine Bucks"   # v0.17h (Hamza): was "Gloss". Code still calls it gloss.
const START_GLOSS := 25
const STAR_GLOSS := 10              # per new star reached
const SLOT_COST := 150              # premium cost of an extra display slot
# v0.19i (Hamza): Shine Bucks for a bay you can't afford yet, priced by how long your income would take to earn
# the missing cash: BAY_GLOSS_MIN + 1 per BAY_GLOSS_MINUTES short, up to BAY_GLOSS_MAX.
const BAY_GLOSS_MIN := 10
const BAY_GLOSS_MINUTES := 5.0
const BAY_GLOSS_MAX := 300
# Finishing a running renovation with Shine Bucks always completes it (no partial skips, stays expensive):
# 1 per RENO_GLOSS_MINUTES of time left, at least RENO_FINISH_MIN.
const RENO_GLOSS_MINUTES := 2.0
const RENO_FINISH_MIN := 10

# ------------------------------------------------------------------ skill tree
# Each country has a branch. Buy that country's TOKENS with its cash: the price
# goes x TOKEN_GROWTH every token (1K, 10K, 100K... scaled to the country's size).
# Spend tokens on nodes. Nodes can boost things anywhere in the world, so it's a
# strategic choice which branch to push.
#
# Node: id, name, desc (%s = total effect), type, value per level, max level,
# cost = tokens per level (level n costs cost * n), parents = nodes that need
# at least Lv 1 first, row/col = position in the tree (3 columns).
# type:
#   country_income  +value income for cities in THIS branch's country
#   all_income      +value income everywhere
#   bg_income       +value income from cities you're NOT looking at
#   valet_speed / desk_speed / bay_speed   +value speed everywhere
#   specialist      +value to the crew specialist bonus for `class`
#   level_discount / hire_discount         -value cost everywhere
#   vip_rate / vip_pay      rare cars +value more often / pay +value more
#   vip_gloss       +value premium currency per rare car
#   followers       +value followers gained
#   display_slot    +value Book display slots
#   ability_duration        manager abilities last +value longer

const TOKEN_BASE := 1000.0
const TOKEN_GROWTH := 10.0

const SKILL_BRANCHES := {
	"usa": [
		{"id": "usa_main_street", "name": "Main Street", "desc": "USA cities earn +%s", "type": "country_income", "value": 0.10, "max": 10, "cost": 1, "parents": [], "row": 0, "col": 1},
		{"id": "usa_hot_rods", "name": "Hot Rod Valets", "desc": "Valets drive %s faster everywhere", "type": "valet_speed", "value": 0.05, "max": 10, "cost": 1, "parents": ["usa_main_street"], "row": 1, "col": 0},
		{"id": "usa_drive_thru", "name": "Drive-Thru", "desc": "Checkout %s faster everywhere", "type": "desk_speed", "value": 0.05, "max": 10, "cost": 1, "parents": ["usa_main_street"], "row": 1, "col": 2},
		{"id": "usa_big_block", "name": "Big Block", "desc": "Muscle specialists +%s", "type": "specialist", "class": "muscle", "value": 0.10, "max": 5, "cost": 2, "parents": ["usa_hot_rods"], "row": 2, "col": 0},
		{"id": "usa_franchise", "name": "Franchise", "desc": "Cities you're not in earn +%s", "type": "bg_income", "value": 0.10, "max": 10, "cost": 2, "parents": ["usa_drive_thru"], "row": 2, "col": 2},
		{"id": "usa_dream", "name": "American Dream", "desc": "ALL cities earn +%s", "type": "all_income", "value": 0.25, "max": 5, "cost": 3, "parents": ["usa_big_block", "usa_franchise"], "row": 3, "col": 1},
	],
	"japan": [
		{"id": "jp_kaizen", "name": "Kaizen", "desc": "Japan cities earn +%s", "type": "country_income", "value": 0.10, "max": 10, "cost": 1, "parents": [], "row": 0, "col": 1},
		{"id": "jp_tuner", "name": "Tuner Culture", "desc": "JDM specialists +%s", "type": "specialist", "class": "jdm", "value": 0.10, "max": 5, "cost": 1, "parents": ["jp_kaizen"], "row": 1, "col": 0},
		{"id": "jp_lean", "name": "Lean Process", "desc": "Level-ups cost %s less everywhere", "type": "level_discount", "value": 0.02, "max": 10, "cost": 1, "parents": ["jp_kaizen"], "row": 1, "col": 2},
		{"id": "jp_shaken", "name": "Shaken Inspection", "desc": "Bays work %s faster everywhere", "type": "bay_speed", "value": 0.05, "max": 10, "cost": 2, "parents": ["jp_tuner"], "row": 2, "col": 0},
		{"id": "jp_daikoku", "name": "Daikoku Nights", "desc": "Rare cars come %s more often", "type": "vip_rate", "value": 0.10, "max": 5, "cost": 2, "parents": ["jp_lean"], "row": 2, "col": 2},
		{"id": "jp_zen", "name": "Zen Master", "desc": "Manager boosts last %s longer", "type": "ability_duration", "value": 0.10, "max": 5, "cost": 3, "parents": ["jp_shaken", "jp_daikoku"], "row": 3, "col": 1},
	],
	"germany": [
		{"id": "de_handwerk", "name": "Handwerk", "desc": "Germany cities earn +%s", "type": "country_income", "value": 0.10, "max": 10, "cost": 1, "parents": [], "row": 0, "col": 1},
		{"id": "de_autobahn", "name": "Autobahn", "desc": "Valets drive %s faster everywhere", "type": "valet_speed", "value": 0.08, "max": 10, "cost": 1, "parents": ["de_handwerk"], "row": 1, "col": 0},
		{"id": "de_precision", "name": "Precision", "desc": "Euro specialists +%s", "type": "specialist", "class": "euro", "value": 0.10, "max": 5, "cost": 1, "parents": ["de_handwerk"], "row": 1, "col": 2},
		{"id": "de_engineering", "name": "Engineering", "desc": "Checkout %s faster everywhere", "type": "desk_speed", "value": 0.08, "max": 10, "cost": 2, "parents": ["de_autobahn"], "row": 2, "col": 0},
		{"id": "de_concours", "name": "Concours d'Elegance", "desc": "Rare cars pay +%s", "type": "vip_pay", "value": 0.20, "max": 5, "cost": 2, "parents": ["de_precision"], "row": 2, "col": 2},
		{"id": "de_wunderbar", "name": "Wunderbar", "desc": "ALL cities earn +%s", "type": "all_income", "value": 0.30, "max": 5, "cost": 3, "parents": ["de_engineering", "de_concours"], "row": 3, "col": 1},
	],
	"australia": [
		{"id": "au_fair_dinkum", "name": "Fair Dinkum", "desc": "Australia cities earn +%s", "type": "country_income", "value": 0.10, "max": 10, "cost": 1, "parents": [], "row": 0, "col": 1},
		{"id": "au_ute_muster", "name": "Ute Muster", "desc": "4x4 specialists +%s", "type": "specialist", "class": "offroad", "value": 0.10, "max": 5, "cost": 1, "parents": ["au_fair_dinkum"], "row": 1, "col": 0},
		{"id": "au_mates_rates", "name": "Mate's Rates", "desc": "Hiring managers costs %s less", "type": "hire_discount", "value": 0.05, "max": 10, "cost": 1, "parents": ["au_fair_dinkum"], "row": 1, "col": 2},
		{"id": "au_larrikin", "name": "Larrikin", "desc": "Muscle specialists +%s", "type": "specialist", "class": "muscle", "value": 0.10, "max": 5, "cost": 2, "parents": ["au_ute_muster"], "row": 2, "col": 0},
		{"id": "au_bush_telegraph", "name": "Bush Telegraph", "desc": "+%s followers gained", "type": "followers", "value": 0.10, "max": 10, "cost": 2, "parents": ["au_mates_rates"], "row": 2, "col": 2},
		{"id": "au_outback", "name": "Outback Empire", "desc": "Cities you're not in earn +%s", "type": "bg_income", "value": 0.25, "max": 5, "cost": 3, "parents": ["au_larrikin", "au_bush_telegraph"], "row": 3, "col": 1},
	],
	"uae": [
		{"id": "ae_oasis", "name": "Oasis", "desc": "UAE cities earn +%s", "type": "country_income", "value": 0.10, "max": 10, "cost": 1, "parents": [], "row": 0, "col": 1},
		{"id": "ae_gold_souk", "name": "Gold Souk", "desc": "+%s premium per rare car", "type": "vip_gloss", "value": 1.0, "max": 5, "cost": 1, "parents": ["ae_oasis"], "row": 1, "col": 0},
		{"id": "ae_hypercar_club", "name": "Hypercar Club", "desc": "Rare cars pay +%s", "type": "vip_pay", "value": 0.25, "max": 5, "cost": 1, "parents": ["ae_oasis"], "row": 1, "col": 2},
		{"id": "ae_convoy", "name": "Desert Convoy", "desc": "Rare cars come %s more often", "type": "vip_rate", "value": 0.15, "max": 5, "cost": 2, "parents": ["ae_gold_souk"], "row": 2, "col": 0},
		{"id": "ae_royal", "name": "Royal Collection", "desc": "+%s Book display slots", "type": "display_slot", "value": 1.0, "max": 2, "cost": 3, "parents": ["ae_hypercar_club"], "row": 2, "col": 2},
		{"id": "ae_mirage", "name": "Mirage", "desc": "ALL cities earn +%s", "type": "all_income", "value": 0.50, "max": 5, "cost": 3, "parents": ["ae_convoy", "ae_royal"], "row": 3, "col": 1},
	],
}
# Flat-number effects shown as "+N" instead of "+N%"
const SKILL_FLAT_TYPES := ["vip_gloss", "display_slot"]

# ------------------------------------------------------------------ boosts
# TOTAL BOOST = BASE x BOOSTERS
#   BASE  = permanent boosts x the ad boost (they multiply: lifetime x2 * ad x2 = x4)
#   BOOSTERS = boosters you activate from your inventory ADD together (x5 + x2 = x7)
#   e.g. ad x2 with a x5 and a x2 booster running = 2 x (5 + 2) = x14
# The boost multiplies everything every city produces (bays, valet, front desk),
# including cities in the background and earnings while you're away.

const AD_BOOST_MULT := 2.0
const AD_BOOST_HOURS := 4.0        # each ad adds this much time
const AD_BOOST_MAX_HOURS := 24.0   # banked time cap (v0.19w: BOOST ALL fills every city of a country to this in one ad)
const COLLECT_AD_MULT := 2.0       # v0.19w: the map's COLLECT (ad only, like Idle Miner) pays the stashes x this
const BOOSTERS := [
	{"id": "x2_30m", "name": "x2 Booster", "mult": 2.0, "minutes": 30.0, "price": 20},
	{"id": "x3_1h", "name": "x3 Booster", "mult": 3.0, "minutes": 60.0, "price": 60},
	{"id": "x5_15m", "name": "x5 Booster", "mult": 5.0, "minutes": 15.0, "price": 50},
	{"id": "x5_2h", "name": "x5 Booster", "mult": 5.0, "minutes": 120.0, "price": 200},
	{"id": "x2_24h", "name": "x2 Day Pass", "mult": 2.0, "minutes": 1440.0, "price": 300},
	{"id": "x4_7d", "name": "x4 Week Pass", "mult": 4.0, "minutes": 10080.0, "price": 2500},
	# v0.19n: Lucky Wheel only (never in the deals)
	{"id": "x10_10m", "name": "x10 Booster", "mult": 10.0, "minutes": 10.0, "price": 0},
	{"id": "x20_5m", "name": "x20 Booster", "mult": 20.0, "minutes": 5.0, "price": 0},
	{"id": "x50_5m", "name": "x50 Booster", "mult": 50.0, "minutes": 5.0, "price": 0},
	{"id": "x500_5m", "name": "x500 Booster", "mult": 500.0, "minutes": 5.0, "price": 0},
]

# ------------------------------------------------------------------ v0.19n LUCKY WHEEL (Hamza 26 Oct)
# The early Shine Bucks sink. A free spin every WHEEL_FREE_HOURS (real clock), more for WHEEL_SPIN_COST
# Shine Bucks. 12 prizes in 4 tiers (like Idle Miner's wheel); every prize in a tier is equally likely;
# the "i" on the wheel lists the odds. All numbers are placeholders (Hamza balances by playtest).
# Kinds: booster (into YOUR BOOSTERS), cash (that many minutes of your income, now), case (a Case File),
# legend (a whole Legendary premium manager joins; 3 Classified Files if you already have them all).
const WHEEL_FREE_HOURS := 8.0
const WHEEL_SPIN_COST := 50
const WHEEL_TIERS := [
	{"name": "Common", "chance": 70.5, "color": "5b8def"},
	{"name": "Rare", "chance": 27.0, "color": "2fc28a"},
	{"name": "Epic", "chance": 2.0, "color": "a35ee8"},
	{"name": "Legendary", "chance": 0.5, "color": "ffb300"},
]
const WHEEL_PRIZES := [   # in order round the wheel, clockwise from the top
	{"id": "legend", "tier": 3, "kind": "legend"},
	{"id": "cash_30m", "tier": 0, "kind": "cash", "minutes": 30.0},
	{"id": "x10_10m", "tier": 1, "kind": "booster", "booster": "x10_10m"},
	{"id": "x2_30m", "tier": 0, "kind": "booster", "booster": "x2_30m"},
	{"id": "case_classified", "tier": 2, "kind": "case", "file": "classified"},
	{"id": "cash_4h", "tier": 1, "kind": "cash", "minutes": 240.0},
	{"id": "case_basic", "tier": 0, "kind": "case", "file": "basic"},
	{"id": "x20_5m", "tier": 1, "kind": "booster", "booster": "x20_5m"},
	{"id": "x500_5m", "tier": 3, "kind": "booster", "booster": "x500_5m"},
	{"id": "x5_15m", "tier": 0, "kind": "booster", "booster": "x5_15m"},
	{"id": "case_detailed", "tier": 1, "kind": "case", "file": "detailed"},
	{"id": "x50_5m", "tier": 2, "kind": "booster", "booster": "x50_5m"},
]
const WHEEL_LEGEND_FALLBACK := 3   # Classified Files instead, once every Legendary manager is yours
# v0.19j TODAY'S DEALS (Hamza): boosters aren't an endless shop. Every DEAL_HOURS (real clock, same for
# everyone, so reopening the game can't reroll) DEAL_COUNT different boosters are on offer, each buyable
# once. Bigger ones turn up less often (weights). A crate system for boosters comes later.
const DEAL_COUNT := 3
const DEAL_HOURS := 12.0
const DEAL_WEIGHTS := {"x2_30m": 30, "x3_1h": 20, "x5_15m": 20, "x5_2h": 12, "x2_24h": 12, "x4_7d": 6}
const STARTER_BOOSTERS := {"x2_30m": 2, "x5_15m": 1}   # given on a new game
const STAR_BOOSTER := "x2_30m"                          # reward for each new star

# ------------------------------------------------------------------ equipment (crafted)
# Generic gear for PREMIUM managers: 1 slot each, swap any time. Only one of each
# item exists: you craft the Common, then upgrade it to Rare and Epic (the item below
# is used up + materials). Crafting is instant.
# Materials only come from the Hometown Garage + car show events (not built yet;
# debug builds can grant them for testing).
# effect scope: "station" = works on the station the wearer runs,
#               "global"  = works everywhere while the wearer is working anywhere.

const EQUIP_TIERS := [
	{"name": "Common", "color": "9e9e9e"},
	{"name": "Rare", "color": "42a5f5"},
	{"name": "Epic", "color": "ab47bc"},
]

const MATERIALS := [
	{"id": "microfibre", "name": "Microfibre", "tier": 0, "color": "4fc3f7"},
	{"id": "rubber", "name": "Rubber", "tier": 0, "color": "616161"},
	{"id": "steel", "name": "Steel", "tier": 0, "color": "b0bec5"},
	{"id": "chrome", "name": "Chrome", "tier": 1, "color": "e0f7fa"},
	{"id": "compound", "name": "Polishing Compound", "tier": 1, "color": "ff8a65"},
	{"id": "carbon", "name": "Carbon Fibre", "tier": 2, "color": "37474f"},
	{"id": "ceramic", "name": "Ceramic", "tier": 2, "color": "fff8e1"},
	{"id": "alcantara", "name": "Alcantara", "tier": 2, "color": "6a1b9a"},
]
const MATERIAL_SOURCE := "Hometown Garage + car show events (coming soon)"

# values = effect at Common / Rare / Epic. recipes[t] = materials to reach tier t
# (t=0 is crafting the Common).
const EQUIPMENT := [
	{"id": "stopwatch", "name": "Pro Stopwatch", "effect": "cooldown", "scope": "station", "values": [0.10, 0.20, 0.30],
		"desc": "Ability recharges %s faster", "recipes": [
		{"steel": 20, "rubber": 10}, {"steel": 40, "chrome": 12}, {"chrome": 25, "carbon": 10, "alcantara": 4}]},
	{"id": "fridge", "name": "Energy Drink Fridge", "effect": "ability_time", "scope": "station", "values": [0.15, 0.30, 0.50],
		"desc": "Ability lasts %s longer", "recipes": [
		{"steel": 15, "microfibre": 15}, {"rubber": 40, "chrome": 10}, {"chrome": 20, "ceramic": 10, "carbon": 5}]},
	{"id": "air_freshener", "name": "Lucky Air Freshener", "effect": "passive", "scope": "station", "values": [0.20, 0.40, 0.75],
		"desc": "Passive is %s stronger", "recipes": [
		{"microfibre": 25}, {"microfibre": 50, "compound": 12}, {"compound": 25, "alcantara": 10, "ceramic": 5}]},
	{"id": "gloves", "name": "Microfibre Gloves", "effect": "speed", "scope": "station", "values": [0.10, 0.20, 0.35],
		"desc": "Their station works %s faster", "recipes": [
		{"microfibre": 20, "rubber": 10}, {"microfibre": 40, "compound": 12}, {"compound": 25, "alcantara": 10, "carbon": 5}]},
	{"id": "apron", "name": "Detailing Apron", "effect": "income", "scope": "station", "values": [0.10, 0.25, 0.50],
		"desc": "Their station earns %s more", "recipes": [
		{"microfibre": 15, "steel": 15}, {"steel": 30, "rubber": 20, "compound": 10}, {"compound": 20, "alcantara": 12, "ceramic": 6}]},
	{"id": "crew_jacket", "name": "Crew Jacket", "effect": "crew", "scope": "station", "values": [0.10, 0.20, 0.35],
		"desc": "Their crew bonuses are %s stronger", "recipes": [
		{"rubber": 15, "microfibre": 15}, {"rubber": 40, "chrome": 10}, {"chrome": 20, "alcantara": 12, "carbon": 5}]},
	{"id": "clipboard", "name": "Deal Clipboard", "effect": "discount", "scope": "station", "values": [0.05, 0.10, 0.15],
		"desc": "Level-ups at their station cost %s less", "recipes": [
		{"steel": 20, "microfibre": 10}, {"steel": 40, "compound": 12}, {"compound": 25, "carbon": 10, "ceramic": 5}]},
	{"id": "lanyard", "name": "VIP Lanyard", "effect": "vip_rate", "scope": "global", "values": [0.10, 0.20, 0.35],
		"desc": "Rare cars come %s more often", "recipes": [
		{"rubber": 20, "microfibre": 15}, {"rubber": 30, "chrome": 15}, {"chrome": 25, "ceramic": 10, "alcantara": 6}]},
	{"id": "night_lamp", "name": "Night Lamp", "effect": "offline", "scope": "global", "values": [0.05, 0.10, 0.20],
		"desc": "Earn %s more while you're away", "recipes": [
		{"steel": 25, "rubber": 10}, {"steel": 40, "chrome": 15}, {"chrome": 30, "carbon": 10, "ceramic": 6}]},
	{"id": "blueprints", "name": "Blueprint Tube", "effect": "renovation", "scope": "global", "values": [0.10, 0.20, 0.30],
		"desc": "Hometown renovations %s faster", "recipes": [
		{"steel": 20, "microfibre": 10}, {"steel": 30, "compound": 15}, {"compound": 25, "carbon": 12, "alcantara": 4}]},
]

# ------------------------------------------------------------------ Hometown Garage
# Your own garage back home. Never affected by prestige. Played in RUNS: run 1 has
# 5 bays, then 10, 15, then 20 forever. Finish a run (every bay built and maxed,
# valet + desk maxed) and it starts over a little more rewarding. Main source of
# Certs, Case Files and crafting materials, with rewards weighted to the end.
# Own currency. Each deeper bay earns AND costs x2.5 (vs x8 / x12 in cities). v0.17 sim
# (tools/sim/home.py, ad x2 + skills): runs take ~5.3h / 8.9h / 12.3h / 18.5h for 5 / 10 / 15 /
# 20 bays incl. renovations, valet + desk ~1/3 of the level-up spending, renovation tiers.

const HOMETOWN_ID := "hometown"
const HOMETOWN_COUNTRY := {"id": "hometown", "name": "Hometown", "currency": "Hometown cash", "symbol": "HT$", "color": "8d6e63",
	"bias": {"jdm": 1.0, "euro": 1.0, "muscle": 1.0, "offroad": 1.0}, "unlock_cost": 0.0,
	"cities": [{"id": "hometown", "name": "Hometown Garage"}]}
const HOMETOWN_UNLOCK_BAYS := 5         # build this many bays in any city to unlock it
const HOMETOWN_RUN_BAYS := [5, 10, 15, 20]   # run 4 onwards stays at 20
const HOMETOWN_BAY_TARGET := 50         # every bay must reach this level
const HOMETOWN_VD_PER_BAY := 10         # valet + desk must reach 10 x run bays (50 / 100 / 150 / 200)
const HOMETOWN_GROWTH := 2.5            # each deeper bay earns and costs this much more
const HOMETOWN_COST_MULT := 0.4693       # all Hometown bay costs x this (sets the pace)
const HOMETOWN_BUILD_BASE := 40.0       # build cost of bay n = base x COST_MULT x GROWTH^n
const HOMETOWN_HIRE_MULT := 0.16        # cash manager hires cost x this (kept in proportion to bay costs) ...
const HOMETOWN_HIRE_GROWTH := 2.5       # ... and x this per hire (not x8)

# 3 renovations per run, at 1/4, 2/4 and 3/4 of the bays. Each moves you up a stage.
const HOMETOWN_STAGES := [
	{"name": "Dirt Lot", "color": "6d5843", "tiers": [1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3, 3, 3, 3]},
	{"name": "House Garage", "color": "5b6a7a", "tiers": [1, 1, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4, 4, 4, 4]},
	{"name": "Detailing Shop", "color": "2b5d8a", "tiers": [2, 2, 2, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4, 5, 5, 5, 5, 5, 5, 5]},
	{"name": "Premium Studio", "color": "263238", "tiers": [3, 3, 3, 4, 4, 4, 4, 4, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5]},
]
const HOMETOWN_RENO_HOURS := [2.0, 5.0, 10.0]   # at 20 bays; smaller runs scale down (x run bays / 20)
# Rewards (x run reward mult = 1 + 0.2 per run finished). Weighted to the end.
const HT_REWARD_GROWTH := 0.2

# ------------------------------------------------------------------ Wardrobe (Gloss crates)
# Crew uniforms for the three station types. Wearing one is a permanent income boost
# for that station type in EVERY city (Hometown too). One worn per station type.
# Crates give a random uniform; a duplicate levels that uniform up. The long game:
# land a Legendary and keep levelling it.
#   boost = 1 + base x (1 + LEVEL_STEP x (level - 1))

const UNIFORM_RARITIES := [
	{"name": "Common", "color": "9e9e9e", "base": 0.10},
	{"name": "Uncommon", "color": "66bb6a", "base": 0.20},
	{"name": "Rare", "color": "42a5f5", "base": 0.40},
	{"name": "Epic", "color": "ab47bc", "base": 0.75},
	{"name": "Legendary", "color": "ffb300", "base": 1.50},
]
const UNIFORM_LEVEL_STEP := 0.15
const UNIFORM_MAX_LEVEL := 25
# copies needed to go from level L to L+1 = L (so Lv 5 needs 1+2+3+4 = 10 extra copies)

const UNIFORM_AREAS := {"bay": "Detailers", "valet": "Valets", "desk": "Front Desk"}
const UNIFORM_EFFECT := {"bay": "Bays earn x%s", "valet": "Valets carry x%s", "desk": "Checkout handles x%s"}
const UNIFORMS := [
	{"id": "bay_tee", "area": "bay", "rarity": 0, "name": "Plain Tee", "color": "eceff1"},
	{"id": "bay_polo", "area": "bay", "rarity": 1, "name": "Shop Polo", "color": "43a047"},
	{"id": "bay_overalls", "area": "bay", "rarity": 2, "name": "Detailer Overalls", "color": "1e88e5"},
	{"id": "bay_suit", "area": "bay", "rarity": 3, "name": "Pro Detailing Suit", "color": "8e24aa"},
	{"id": "bay_gold", "area": "bay", "rarity": 4, "name": "Golden Glove Uniform", "color": "ffb300"},
	{"id": "valet_vest", "area": "valet", "rarity": 0, "name": "Hi-Vis Vest", "color": "ffeb3b"},
	{"id": "valet_waistcoat", "area": "valet", "rarity": 1, "name": "Valet Waistcoat", "color": "2e7d32"},
	{"id": "valet_jacket", "area": "valet", "rarity": 2, "name": "Driving Jacket", "color": "1565c0"},
	{"id": "valet_race", "area": "valet", "rarity": 3, "name": "Racing Suit", "color": "c62828"},
	{"id": "valet_gold", "area": "valet", "rarity": 4, "name": "Chauffeur's Gold Suit", "color": "ffb300"},
	{"id": "desk_badge", "area": "desk", "rarity": 0, "name": "Name Badge Tee", "color": "b0bec5"},
	{"id": "desk_blazer", "area": "desk", "rarity": 1, "name": "Front Desk Blazer", "color": "388e3c"},
	{"id": "desk_vest", "area": "desk", "rarity": 2, "name": "Concierge Vest", "color": "283593"},
	{"id": "desk_tailored", "area": "desk", "rarity": 3, "name": "Tailored Suit", "color": "4a148c"},
	{"id": "desk_diamond", "area": "desk", "rarity": 4, "name": "Diamond Concierge Suit", "color": "ffb300"},
]
# odds = Common / Uncommon / Rare / Epic / Legendary. min_rarity = at least one item this good.
const WARDROBE_CRATES := [
	{"id": "wardrobe", "name": "Wardrobe Crate", "cost": 100, "items": 1, "odds": [55.0, 28.0, 12.0, 4.0, 1.0], "min_rarity": 0,
		"desc": "1 uniform"},
	{"id": "big_wardrobe", "name": "Big Wardrobe Crate", "cost": 450, "items": 5, "odds": [55.0, 28.0, 12.0, 4.0, 1.0], "min_rarity": 2,
		"desc": "5 uniforms, at least one Rare or better"},
	{"id": "designer", "name": "Designer Crate", "cost": 1200, "items": 1, "odds": [0.0, 0.0, 0.0, 85.0, 15.0], "min_rarity": 3,
		"desc": "1 Epic or Legendary uniform"},
]
const WARDROBE_PITY := 40   # a Legendary is guaranteed within this many uniforms

# ------------------------------------------------------------------ renovations (every city + Hometown)
# Like Idle Miner's rock barriers: before bays 6, 11 and 16 (Hometown: at 1/4, 2/4, 3/4
# of the run) you must renovate. Costs RENO_COST_BUILDS x the next bay's build cost and
# takes a timer. Every city uses the same timers; prestige brings them back (the shop
# resets to 1 bay). Event cities may skip them later.
const RENO_COST_BUILDS := 3.0
# v0.19k (Hamza): the TEACHING renovation. A city's 1st renovation costs only 1x the next bay (Lima ~$19M,
# was ~$57M), so the player meets the 1h timer (and the WATCH AD / FINISH NOW buttons) sooner.
# Renovations 2 and 3 and the Hometown keep RENO_COST_BUILDS.
const RENO_FIRST_COST_BUILDS := 1.0
const CITY_RENO_HOURS := [1.0, 8.0, 48.0]
const CITY_RENOS := ["Expand into the lot next door", "Add a mezzanine level", "Build a showroom wing"]
const RENO_AD_SECONDS := 1800.0     # an ad (or the no-ads pack) takes 30 minutes off ...
const RENO_ADS_PER_HOUR := 2        # ... twice an hour, per renovation site
const RENO_GLOSS := 10              # reward when a city renovation finishes
# Renovation tiers: bays after each renovation (6-10, 11-15, 16-20 in cities; Hometown: after
# each of its renovation points) earn RENO_TIER_INCOME x more per tier, but their levels
# cost RENO_TIER_COST x more per tier. So their first levels are a worse deal than levelling
# the older bays until they reach their 1st-2nd boost (Lv10 / Lv25), then they take over.
const RENO_TIER_INCOME := 3.0
const RENO_TIER_COST := 120.0       # v0.17g (was 352.5): a new tier bay pulls its weight straight away
const HOMETOWN_TIER_INCOME := 2.4      # older bays sit at their Lv 50 cap, so this sets the take-over (~Lv 25)
const HOMETOWN_TIER_COST := 3.6        # kept small: every bay must reach Lv 50, so a big jump would stretch runs
# Hometown valet + front desk level prices (they must reach Lv 10 x run bays to finish a run)
const HOMETOWN_VD_COST_MULT := 362.8   # x VALET/DESK_LEVEL_COST (same Hometown prices as v0.17)
const HOMETOWN_VD_LEVEL_GROWTH := 1.093
const RENO_CERTS := 5
