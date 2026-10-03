class_name EvolvableGenome
extends RefCounted

# Variable-length ecological program. Modules are deliberately compact
# dictionaries so the CPU reference can mutate/copy them cheaply and the data
# can later map to fixed GPU buffers.

const MODULE_NUTRIENT_UPTAKE := 0
const MODULE_EXUDATE_UPTAKE := 1
const MODULE_DETRITUS_SCAVENGE := 2
const MODULE_PHOTOTROPHY := 3
const MODULE_MATRIX := 4
const MODULE_QUORUM_SIGNAL := 5
const MODULE_COUNT := 6

const SENSOR_ALWAYS := 0
const SENSOR_NUTRIENT := 1
const SENSOR_EXUDATE := 2
const SENSOR_DETRITUS := 3
const SENSOR_LIGHT := 4
const SENSOR_QUORUM := 5
const SENSOR_DAMAGE := 6
const SENSOR_LOW_ENERGY := 7
const SENSOR_OXYGEN := 8
const SENSOR_COUNT := 9

const MIN_MODULES := 2
const MAX_MODULES := 14

var modules: Array = []
var last_structural_changes: int = 0
var last_event: String = "founder"


func configure_founder(p_rng: RandomNumberGenerator) -> void:
	modules.clear()
	last_structural_changes = 0
	last_event = "founder"

	# Every founder can use the common dissolved pool, but strength and
	# regulation are already variable.
	_add_module(
		MODULE_NUTRIENT_UPTAKE,
		p_rng.randf_range(0.82, 1.16),
		SENSOR_NUTRIENT,
		p_rng.randf_range(0.08, 0.28),
		1,
		_new_innovation(p_rng)
	)
	_add_module(
		MODULE_EXUDATE_UPTAKE,
		p_rng.randf_range(0.42, 0.92),
		SENSOR_EXUDATE,
		p_rng.randf_range(0.04, 0.22),
		1,
		_new_innovation(p_rng)
	)
	_add_module(
		MODULE_QUORUM_SIGNAL,
		p_rng.randf_range(0.18, 0.55),
		SENSOR_ALWAYS,
		0.5,
		1,
		_new_innovation(p_rng)
	)

	# Founders receive one strong and sometimes one weak ecological specialty.
	var specialty: int = p_rng.randi_range(
		MODULE_DETRITUS_SCAVENGE,
		MODULE_MATRIX
	)
	_add_specialty(specialty, p_rng, 0.82, 1.36)
	if p_rng.randf() < 0.32 and modules.size() < MAX_MODULES:
		var secondary: int = p_rng.randi_range(
			MODULE_DETRITUS_SCAVENGE,
			MODULE_MATRIX
		)
		_add_specialty(secondary, p_rng, 0.28, 0.72)

	# Rare founder regulatory duplication is enough to make seeds diverge
	# without hard-coding named species.
	if p_rng.randf() < 0.20 and modules.size() < MAX_MODULES:
		var source: Dictionary = modules[p_rng.randi_range(0, modules.size() - 1)]
		var duplicate: Dictionary = source.duplicate(true)
		duplicate["innovation"] = _new_innovation(p_rng)
		duplicate["strength"] = clampf(
			float(duplicate["strength"]) * p_rng.randf_range(0.45, 0.82),
			0.05,
			2.20
		)
		duplicate["sensor"] = p_rng.randi_range(0, SENSOR_COUNT - 1)
		duplicate["threshold"] = p_rng.randf_range(0.10, 0.82)
		modules.append(duplicate)


func inherit_and_mutate(
	parent: Variant,
	p_rng: RandomNumberGenerator,
	mutation_rate: float
) -> void:
	modules.clear()
	for parent_module in parent.modules:
		modules.append((parent_module as Dictionary).duplicate(true))

	last_structural_changes = 0
	last_event = "copy"
	var rate: float = clampf(mutation_rate, 0.01, 0.25)

	for module in modules:
		if p_rng.randf() < rate * 0.72:
			module["strength"] = clampf(
				float(module["strength"]) + p_rng.randfn(0.0, 0.10),
				0.04,
				2.30
			)
		if p_rng.randf() < rate * 0.34:
			module["threshold"] = clampf(
				float(module["threshold"]) + p_rng.randfn(0.0, 0.08),
				0.02,
				0.96
			)
		if p_rng.randf() < rate * 0.12:
			module["sensor"] = p_rng.randi_range(0, SENSOR_COUNT - 1)
			last_event = "regulatory rewire"
		if p_rng.randf() < rate * 0.05:
			module["polarity"] = -int(module["polarity"])
			last_event = "regulatory flip"
		if p_rng.randf() < rate * 0.035:
			module["kind"] = p_rng.randi_range(0, MODULE_COUNT - 1)
			last_event = "functional rewire"

	var duplication_probability: float = clampf(0.018 + rate * 0.42, 0.018, 0.12)
	if modules.size() < MAX_MODULES and p_rng.randf() < duplication_probability:
		var source_index: int = p_rng.randi_range(0, modules.size() - 1)
		var duplicated: Dictionary = (modules[source_index] as Dictionary).duplicate(true)
		duplicated["innovation"] = _new_innovation(p_rng)
		duplicated["strength"] = clampf(
			float(duplicated["strength"]) * p_rng.randf_range(0.72, 1.08),
			0.04,
			2.30
		)
		if p_rng.randf() < 0.58:
			duplicated["sensor"] = p_rng.randi_range(0, SENSOR_COUNT - 1)
			duplicated["threshold"] = p_rng.randf_range(0.05, 0.90)
		modules.append(duplicated)
		last_structural_changes += 1
		last_event = "module duplication"

	var deletion_probability: float = clampf(0.010 + rate * 0.22, 0.010, 0.065)
	if modules.size() > MIN_MODULES and p_rng.randf() < deletion_probability:
		modules.remove_at(p_rng.randi_range(0, modules.size() - 1))
		last_structural_changes += 1
		last_event = "module deletion"

	var insertion_probability: float = clampf(0.008 + rate * 0.18, 0.008, 0.050)
	if modules.size() < MAX_MODULES and p_rng.randf() < insertion_probability:
		_add_module(
			p_rng.randi_range(0, MODULE_COUNT - 1),
			p_rng.randf_range(0.12, 0.72),
			p_rng.randi_range(0, SENSOR_COUNT - 1),
			p_rng.randf_range(0.08, 0.90),
			1 if p_rng.randf() < 0.84 else -1,
			_new_innovation(p_rng)
		)
		last_structural_changes += 1
		last_event = "module insertion"


func expression(kind: int, signals: Array) -> float:
	var total: float = 0.0
	for module in modules:
		if int(module["kind"]) != kind:
			continue
		var sensor_index: int = int(module["sensor"])
		var sensor_value: float = 1.0
		if sensor_index != SENSOR_ALWAYS:
			sensor_value = (
				float(signals[sensor_index])
				if sensor_index >= 0 and sensor_index < signals.size()
				else 0.0
			)
		var gate: float = smoothstep(
			float(module["threshold"]) - 0.18,
			float(module["threshold"]) + 0.18,
			sensor_value
		)
		if int(module["polarity"]) < 0:
			gate = 1.0 - gate
		total += float(module["strength"]) * gate
	return clampf(total, 0.0, 3.0)


func complexity_cost(signals: Array) -> float:
	var active: float = 0.0
	for kind in range(MODULE_COUNT):
		active += expression(kind, signals)
	return (
		0.00055 * float(modules.size())
		+ 0.00040 * active
	)


func dominant_guild(signals: Array) -> int:
	# Keep the existing four morphology classes as a presentation vocabulary,
	# but derive the class from the currently expressed program.
	var detritus_score: float = expression(MODULE_DETRITUS_SCAVENGE, signals)
	var photo_score: float = expression(MODULE_PHOTOTROPHY, signals)
	var matrix_score: float = expression(MODULE_MATRIX, signals)
	var baseline_score: float = (
		expression(MODULE_NUTRIENT_UPTAKE, signals)
		+ expression(MODULE_EXUDATE_UPTAKE, signals) * 0.55
	)

	if photo_score > maxf(detritus_score, matrix_score) and photo_score > baseline_score * 0.42:
		return 3
	if matrix_score > maxf(detritus_score, photo_score) and matrix_score > baseline_score * 0.36:
		return 2
	if detritus_score > 0.34:
		return 1
	return 0


func phenotype_label(signals: Array) -> String:
	var labels := PackedStringArray()
	var scores: Array = [
		["nutrient", expression(MODULE_NUTRIENT_UPTAKE, signals)],
		["crossfeed", expression(MODULE_EXUDATE_UPTAKE, signals)],
		["scavenge", expression(MODULE_DETRITUS_SCAVENGE, signals)],
		["photo", expression(MODULE_PHOTOTROPHY, signals)],
		["matrix", expression(MODULE_MATRIX, signals)],
	]
	scores.sort_custom(_score_descending)
	if not scores.is_empty():
		labels.append(String(scores[0][0]))
	if scores.size() > 1 and float(scores[1][1]) >= float(scores[0][1]) * 0.58:
		labels.append(String(scores[1][0]))
	return "+".join(labels)


func ecotype_hash() -> int:
	var hash_value: int = 216613
	for module in modules:
		var packed: int = (
			int(module["kind"]) * 73856093
			+ int(module["sensor"]) * 19349663
			+ int(round(float(module["strength"]) * 10.0)) * 83492791
			+ int(round(float(module["threshold"]) * 10.0)) * 265443576
			+ (1 if int(module["polarity"]) > 0 else 2) * 97531
		)
		hash_value = (
			(hash_value * 16777619) ^ packed
		) & 0x7fffffff
	return hash_value


func compact_signature() -> String:
	var parts := PackedStringArray()
	for module in modules:
		parts.append(
			"%d.%d.%d.%d.%d"
			% [
				int(module["kind"]),
				int(module["sensor"]),
				int(round(float(module["strength"]) * 100.0)),
				int(round(float(module["threshold"]) * 100.0)),
				int(module["polarity"]),
			]
		)
	return ",".join(parts)


func module_for_transfer(index: int) -> Dictionary:
	if modules.is_empty():
		return {}
	return (modules[posmod(index, modules.size())] as Dictionary).duplicate(true)


func integrate_module(
	donor_module: Dictionary,
	p_rng: RandomNumberGenerator
) -> bool:
	if donor_module.is_empty():
		return false

	var donor_innovation: int = int(donor_module.get("innovation", -1))
	for module in modules:
		if int(module.get("innovation", -2)) != donor_innovation:
			continue
		module["strength"] = clampf(
			lerpf(
				float(module["strength"]),
				float(donor_module.get("strength", module["strength"])),
				0.55
			),
			0.04,
			2.30
		)
		if p_rng.randf() < 0.45:
			module["sensor"] = int(donor_module.get("sensor", module["sensor"]))
			module["threshold"] = float(
				donor_module.get("threshold", module["threshold"])
			)
			module["polarity"] = int(
				donor_module.get("polarity", module["polarity"])
			)
		last_event = "allelic recombination"
		return true

	var incoming: Dictionary = donor_module.duplicate(true)
	if modules.size() < MAX_MODULES:
		modules.append(incoming)
	else:
		# At capacity, replace the weakest same-function module when possible,
		# otherwise the globally weakest module. This makes HGT compositional
		# without allowing unbounded per-cell memory growth.
		var replace_index: int = 0
		var weakest: float = INF
		var donor_kind: int = int(incoming.get("kind", 0))
		for i in range(modules.size()):
			var candidate: Dictionary = modules[i]
			var priority: float = float(candidate["strength"])
			if int(candidate["kind"]) != donor_kind:
				priority += 10.0
			if priority < weakest:
				weakest = priority
				replace_index = i
		modules[replace_index] = incoming

	last_structural_changes += 1
	last_event = "horizontal module merge"
	return true


func baseline_guild() -> int:
	var baseline: Array = [
		1.0, 0.35, 0.20, 0.68, 0.18, 0.0, 0.0, 0.20, 0.50
	]
	return dominant_guild(baseline)


func _add_specialty(
	kind: int,
	p_rng: RandomNumberGenerator,
	min_strength: float,
	max_strength: float
) -> void:
	var preferred_sensor: int = SENSOR_ALWAYS
	match kind:
		MODULE_DETRITUS_SCAVENGE:
			preferred_sensor = SENSOR_DETRITUS
		MODULE_PHOTOTROPHY:
			preferred_sensor = SENSOR_LIGHT
		MODULE_MATRIX:
			preferred_sensor = (
				SENSOR_QUORUM if p_rng.randf() < 0.72 else SENSOR_DAMAGE
			)
	_add_module(
		kind,
		p_rng.randf_range(min_strength, max_strength),
		preferred_sensor,
		p_rng.randf_range(0.08, 0.54),
		1,
		_new_innovation(p_rng)
	)


func _add_module(
	kind: int,
	strength: float,
	sensor: int,
	threshold: float,
	polarity: int,
	innovation: int
) -> void:
	modules.append({
		"kind": clampi(kind, 0, MODULE_COUNT - 1),
		"strength": clampf(strength, 0.04, 2.30),
		"sensor": clampi(sensor, 0, SENSOR_COUNT - 1),
		"threshold": clampf(threshold, 0.02, 0.96),
		"polarity": 1 if polarity >= 0 else -1,
		"innovation": innovation,
	})


func _new_innovation(p_rng: RandomNumberGenerator) -> int:
	return absi(p_rng.randi()) & 0x7fffffff


func _score_descending(a: Array, b: Array) -> bool:
	return float(a[1]) > float(b[1])
