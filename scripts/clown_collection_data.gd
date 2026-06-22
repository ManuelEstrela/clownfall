extends RefCounted
class_name ClownCollectionData

# ══════════════════════════════════════════════════════════════
#  TIERED GOAL SYSTEM
# ══════════════════════════════════════════════════════════════
# Each clown has a list of TIER INCREMENTS (not cumulative goals).
# The cumulative goal for tier N = sum of increments[0..N].
#
# Design logic:
#   - The first ~5 clowns (the ones spawnable without merging) share
#     the same increment pattern, since they're equally common.
#   - From there, increments shrink as the clown gets rarer/bigger,
#     meaning fewer merges are needed to hit each goal.
#   - Kirk (rarest, top tier) starts at just 1 for the first goal.
#
# Stars are flat per-tier for a given clown, but increase with rarity.
#
# Index matches CLOWNS array in clown_ball.gd:
#   0 Tessa, 1 Twinkles, 2 Reina, 3 Osvaldo, 4 Hazel,
#   5 Mumbles, 6 Sneaky, 7 Wendy, 8 Chatty, 9 Cups, 10 Kirk

const CLOWN_PROGRESS = [
	# Tessa — common, spawnable
	{ "increments": [250, 200, 200, 200, 200, 200, 200], "stars": 10 },
	# Twinkles — common, spawnable
	{ "increments": [250, 200, 200, 200, 200, 200, 200], "stars": 10 },
	# Reina — common, spawnable
	{ "increments": [250, 200, 200, 200, 200, 200, 200], "stars": 10 },
	# Osvaldo — common, spawnable
	{ "increments": [250, 200, 200, 200, 200, 200, 200], "stars": 10 },
	# Hazel — common, spawnable (last of the "starter" tier)
	{ "increments": [250, 200, 200, 200, 200, 200, 200], "stars": 10 },
	# Mumbles — first merge-only tier, noticeably rarer
	{ "increments": [100, 80, 80, 80, 80, 80], "stars": 15 },
	# Sneaky
	{ "increments": [60, 50, 50, 50, 50], "stars": 20 },
	# Wendy
	{ "increments": [30, 25, 25, 25], "stars": 25 },
	# Chatty
	{ "increments": [15, 10, 10, 10], "stars": 30 },
	# Cups
	{ "increments": [5, 5, 5, 5], "stars": 40 },
	# Kirk — rarest, top tier
	{ "increments": [1, 5, 10, 20], "stars": 50 },
]

# Returns { "goal": int, "tier": int, "stars": int } for the CURRENT
# (next unreached) goal for a clown, given its total merge count.
static func get_current_goal(clown_type: int, total_merges: int) -> Dictionary:
	var data = CLOWN_PROGRESS[clown_type]
	var increments: Array = data["increments"]
	var stars: int = data["stars"]

	var cumulative = 0
	for i in increments.size():
		cumulative += increments[i]
		if total_merges < cumulative:
			return { "goal": cumulative, "tier": i, "stars": stars }

	# All defined tiers cleared — keep extending using the last increment
	# so the bar never breaks even after exhausting the table.
	var last_increment = increments[increments.size() - 1]
	while total_merges >= cumulative:
		cumulative += last_increment
	return { "goal": cumulative, "tier": increments.size(), "stars": stars }

# Returns how many tiers have been fully cleared for a clown (used to
# calculate total stars earned from that clown so far).
static func get_cleared_tier_count(clown_type: int, total_merges: int) -> int:
	var data = CLOWN_PROGRESS[clown_type]
	var increments: Array = data["increments"]

	var cumulative = 0
	var cleared = 0
	for i in increments.size():
		cumulative += increments[i]
		if total_merges >= cumulative:
			cleared += 1
		else:
			return cleared

	# Extended tiers beyond the table
	var last_increment = increments[increments.size() - 1]
	while total_merges >= cumulative:
		cumulative += last_increment
		cleared += 1
	return cleared

# Total stars earned for a clown so far (cleared tiers × stars per tier)
static func get_stars_earned(clown_type: int, total_merges: int) -> int:
	var data = CLOWN_PROGRESS[clown_type]
	var cleared = get_cleared_tier_count(clown_type, total_merges)
	return cleared * int(data["stars"])
