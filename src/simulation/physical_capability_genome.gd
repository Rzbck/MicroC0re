class_name PhysicalCapabilityGenome
extends RefCounted

const CAP_DIG := 0
const CAP_CARRY := 1
const CAP_DEPOSIT := 2
const CAP_BURROW := 3
const CAP_CLIMB := 4
const CAP_OVIPOSIT := 5
const CAP_ARMOR := 6
const CAP_COUNT := 7

const SENSOR_ALWAYS := 0
const SENSOR_SLOPE := 1
const SENSOR_CARRIED := 2
const SENSOR_ENERGY := 3
const SENSOR_DETRITUS := 4
const SENSOR_LIGHT := 5
const SENSOR_WATER := 6
const SENSOR_COUNT := 7

const PROFILE_MICROBE := 0
const PROFILE_PREDATOR := 1
const PROFILE_PRODUCER := 2
const PROFILE_DECOMPOSER := 3
const PROFILE_FILAMENTOUS := 4

const MIN_MODULES := 3
const MAX_MODULES := 18

var modules: Array = []
var last_event: String = "founder"
var structural_changes: int = 0


func configure_founder(
	p_rng: RandomNumberGenerator,
	profile: int = PROFILE_MICROBE
) -> void:
	modules.clear()
	structural_changes = 0
	last_event = "founder"

	_add_module(
		CAP_CARRY,
		p_rng.randf_range(0.18, 0.42),
		SENSOR_CARRIED,
		0.22,
		-1,
		_innovation(p_rng)
	)
	_add_module(
		CAP_CLIMB,
		p_rng.randf_range(0.18, 0.48),
		SENSOR_SLOPE,
		0.28,
		1,
		_innovation(p_rng)
	)
	_add_module(
		CAP_ARMOR,
		p_rng.randf_range(0.08, 0.30),
		SENSOR_ALWAYS,
		0.50,
		1,
		_innovation(p_rng)
	)

	var dig_bias: float = 0.16
	var deposit_bias: float = 0.14
	var burrow_bias: float = 0.06
	var egg_bias: float = 0.04
	match profile:
		PROFILE_PREDATOR:
			dig_bias = 0.34
			burrow_bias = 0.18
			egg_bias = 0.12
		PROFILE_PRODUCER:
			deposit_bias = 0.22
			egg_bias = 0.18
		PROFILE_DECOMPOSER:
			dig_bias = 0.42
			deposit_bias = 0.38
			burrow_bias = 0.22
		PROFILE_FILAMENTOUS:
			dig_bias = 0.48
			deposit_bias = 0.34
			burrow_bias = 0.30

	_add_module(
		CAP_DIG,
		p_rng.randf_range(dig_bias * 0.70, dig_bias * 1.35 + 0.06),
		SENSOR_SLOPE if p_rng.randf() < 0.52 else SENSOR_DETRITUS,
		p_rng.randf_range(0.16, 0.58),
		1,
		_innovation(p_rng)
	)
	_add_module(
		CAP_DEPOSIT,
		p_rng.randf_range(deposit_bias * 0.65, deposit_bias * 1.40 + 0.05),
		SENSOR_CARRIED,
		p_rng.randf_range(0.18, 0.52),
		1,
		_innovation(p_rng)
	)
	_add_module(
		CAP_BURROW,
		p_rng.randf_range(0.02, burrow_bias + 0.10),
		SENSOR_SLOPE,
		p_rng.randf_range(0.30, 0.74),
		1,
		_innovation(p_rng)
	)
	_add_module(
		CAP_OVIPOSIT,
		p_rng.randf_range(0.01, egg_bias + 0.08),
		SENSOR_ENERGY,
		p_rng.randf_range(0.52, 0.84),
		1,
		_innovation(p_rng)
	)

	if p_rng.randf() < 0.24 and modules.size() < MAX_MODULES:
		var source: Dictionary = (
			modules[p_rng.randi_range(0, modules.size() - 1)] as Dictionary
		).duplicate(true)
		source["innovation"] = _innovation(p_rng)
		source["strength"] = clampf(
			float(source["strength"]) * p_rng.randf_range(0.60, 1.20),
			0.02,
			2.60
		)
		source["sensor"] = p_rng.randi_range(0, SENSOR_COUNT - 1)
		source["threshold"] = p_rng.randf_range(0.08, 0.90)
		modules.append(source)


func inherit_and_mutate(
	parent: Variant,
	p_rng: RandomNumberGenerator,
	mutation_rate: float
) -> void:
	modules.clear()
	for module in parent.modules:
		modules.append((module as Dictionary).duplicate(true))

	structural_changes = 0
	last_event = "copy"
	var rate: float = clampf(mutation_rate, 0.01, 0.26)

	for module in modules:
		if p_rng.randf() < rate * 0.84:
			module["strength"] = clampf(
				float(module["strength"]) + p_rng.randfn(0.0, 0.12),
				0.02,
				2.60
			)
		if p_rng.randf() < rate * 0.42:
			module["threshold"] = clampf(
				float(module["threshold"]) + p_rng.randfn(0.0, 0.09),
				0.02,
				0.98
			)
		if p_rng.randf() < rate * 0.17:
			module["sensor"] = p_rng.randi_range(0, SENSOR_COUNT - 1)
			last_event = "physical sensor rewire"
		if p_rng.randf() < rate * 0.06:
			module["polarity"] = -int(module["polarity"])
			last_event = "physical regulation flip"
		if p_rng.randf() < rate * 0.045:
			module["kind"] = p_rng.randi_range(0, CAP_COUNT - 1)
			last_event = "capability transmutation"

	if modules.size() < MAX_MODULES and p_rng.randf() < 0.025 + rate * 0.52:
		var duplicated: Dictionary = (
			modules[p_rng.randi_range(0, modules.size() - 1)] as Dictionary
		).duplicate(true)
		duplicated["innovation"] = _innovation(p_rng)
		duplicated["strength"] = clampf(
			float(duplicated["strength"]) * p_rng.randf_range(0.62, 1.18),
			0.02,
			2.60
		)
		if p_rng.randf() < 0.62:
			duplicated["sensor"] = p_rng.randi_range(0, SENSOR_COUNT - 1)
			duplicated["threshold"] = p_rng.randf_range(0.05, 0.93)
		modules.append(duplicated)
		structural_changes += 1
		last_event = "capability duplication"

	if modules.size() > MIN_MODULES and p_rng.randf() < 0.012 + rate * 0.26:
		modules.remove_at(p_rng.randi_range(0, modules.size() - 1))
		structural_changes += 1
		last_event = "capability deletion"

	if modules.size() < MAX_MODULES and p_rng.randf() < 0.010 + rate * 0.23:
		_add_module(
			p_rng.randi_range(0, CAP_COUNT - 1),
			p_rng.randf_range(0.08, 0.78),
			p_rng.randi_range(0, SENSOR_COUNT - 1),
			p_rng.randf_range(0.05, 0.92),
			1 if p_rng.randf() < 0.84 else -1,
			_innovation(p_rng)
		)
		structural_changes += 1
		last_event = "new physical capability"


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
	return clampf(total, 0.0, 3.2)


func neutral_expression(kind: int) -> float:
	return expression(kind, [1.0, 0.42, 0.24, 0.72, 0.22, 0.62, 0.34])


func complexity_cost() -> float:
	var active: float = 0.0
	for kind in range(CAP_COUNT):
		active += neutral_expression(kind)
	return 0.00045 * float(modules.size()) + 0.00030 * active


func integrate_module(
	donor_module: Dictionary,
	p_rng: RandomNumberGenerator
) -> bool:
	if donor_module.is_empty():
		return false

	var innovation: int = int(donor_module.get("innovation", -1))
	for module in modules:
		if int(module.get("innovation", -2)) != innovation:
			continue
		module["strength"] = clampf(
			lerpf(
				float(module["strength"]),
				float(donor_module.get("strength", module["strength"])),
				0.55
			),
			0.02,
			2.60
		)
		if p_rng.randf() < 0.50:
			module["sensor"] = int(donor_module.get("sensor", module["sensor"]))
			module["threshold"] = float(
				donor_module.get("threshold", module["threshold"])
			)
			module["polarity"] = int(
				donor_module.get("polarity", module["polarity"])
			)
		last_event = "physical allelic recombination"
		return true

	var incoming: Dictionary = donor_module.duplicate(true)
	if modules.size() < MAX_MODULES:
		modules.append(incoming)
	else:
		var weakest_index: int = 0
		var weakest: float = INF
		for i in range(modules.size()):
			var strength: float = float((modules[i] as Dictionary)["strength"])
			if strength < weakest:
				weakest = strength
				weakest_index = i
		modules[weakest_index] = incoming
	structural_changes += 1
	last_event = "cross-lineage capability merge"
	return true


func module_for_transfer(index: int) -> Dictionary:
	if modules.is_empty():
		return {}
	return (modules[posmod(index, modules.size())] as Dictionary).duplicate(true)


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


func _add_module(
	kind: int,
	strength: float,
	sensor: int,
	threshold: float,
	polarity: int,
	innovation: int
) -> void:
	modules.append({
		"kind": clampi(kind, 0, CAP_COUNT - 1),
		"strength": clampf(strength, 0.02, 2.60),
		"sensor": clampi(sensor, 0, SENSOR_COUNT - 1),
		"threshold": clampf(threshold, 0.02, 0.98),
		"polarity": 1 if polarity >= 0 else -1,
		"innovation": innovation,
	})


func _innovation(p_rng: RandomNumberGenerator) -> int:
	return absi(p_rng.randi()) & 0x7fffffff
