class_name SessionTelemetry
extends RefCounted

const SCHEMA_VERSION := 1
const SAMPLE_INTERVAL := 2.0
const MAX_SAMPLES := 900

var report_path: String = ""
var session_id: String = ""
var build_sha: String = "unknown"
var seed: int = 0
var start_usec: int = 0
var sample_accumulator: float = 0.0
var frame_ms_sum: float = 0.0
var frame_ms_max: float = 0.0
var frame_count: int = 0
var sim_ms_sum: float = 0.0
var sim_sample_count: int = 0
var samples: Array = []
var counters := {
	"rotations": 0,
	"zooms": 0,
	"selection_attempts": 0,
	"selection_hits": 0,
	"menu_opens": 0,
	"seed_changes": 0,
}


func begin(seed_value: int) -> void:
	seed = seed_value
	report_path = OS.get_environment("MICROCORE_SESSION_REPORT")
	if report_path.is_empty():
		var local_dir := "user://telemetry"
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(local_dir)
		)
		report_path = local_dir + "/last-session.json"
	else:
		DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())

	build_sha = _safe_build_sha(
		OS.get_environment("MICROCORE_BUILD_SHA")
	)
	session_id = _new_session_id()
	start_usec = Time.get_ticks_usec()
	_write_report(false)


func set_seed(seed_value: int) -> void:
	seed = seed_value


func mark_event(name: String) -> void:
	if counters.has(name):
		counters[name] = int(counters[name]) + 1


func record_frame(
	delta: float,
	sim_step_ms: float,
	draw_ms: float,
	sim: Variant,
	terrain: Variant,
	camera_zoom: float,
	rotation_quarter: int,
	visible_tiles: int
) -> void:
	var frame_ms: float = maxf(0.0, delta * 1000.0)
	frame_ms_sum += frame_ms
	frame_ms_max = maxf(frame_ms_max, frame_ms)
	frame_count += 1
	if sim_step_ms > 0.0:
		sim_ms_sum += sim_step_ms
		sim_sample_count += 1

	sample_accumulator += delta
	if sample_accumulator < SAMPLE_INTERVAL:
		return
	sample_accumulator = fmod(sample_accumulator, SAMPLE_INTERVAL)

	var total_agents: int = (
		sim.bacteria.size()
		+ sim.protozoa.size()
		+ sim.ciliates.size()
		+ sim.flagellates.size()
		+ sim.microalgae.size()
		+ sim.decomposers.size()
		+ sim.hyphae.size()
	)
	var sample := {
		"t_s": int(round(_elapsed_seconds())),
		"fps": roundf(
			Performance.get_monitor(Performance.TIME_FPS) * 10.0
		) / 10.0,
		"frame_ms_avg": _round3(
			frame_ms_sum / float(maxi(1, frame_count))
		),
		"frame_ms_max": _round3(frame_ms_max),
		"process_ms": _round3(
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		),
		"sim_ms": _round3(
			sim_ms_sum / float(maxi(1, sim_sample_count))
		),
		"draw_ms": _round3(draw_ms),
		"draw_calls": int(
			Performance.get_monitor(
				Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME
			)
		),
		"agents": total_agents,
		"bacteria": sim.bacteria.size(),
		"protozoa": sim.protozoa.size(),
		"ciliates": sim.ciliates.size(),
		"flagellates": sim.flagellates.size(),
		"algae": sim.microalgae.size(),
		"decomposers": sim.decomposers.size(),
		"hyphae": sim.hyphae.size(),
		"visible_tiles": visible_tiles,
		"terrain_revision": int(terrain.revision),
		"soil_excavated": _round3(float(terrain.excavated_total)),
		"soil_deposited": _round3(float(terrain.deposited_total)),
		"capability_fragments": terrain.capability_fragments.size(),
		"zoom": _round3(camera_zoom),
		"rotation": posmod(rotation_quarter, 4),
		"seed": seed,
	}
	samples.append(sample)
	if samples.size() > MAX_SAMPLES:
		samples.pop_front()

	frame_ms_sum = 0.0
	frame_ms_max = 0.0
	frame_count = 0
	sim_ms_sum = 0.0
	sim_sample_count = 0
	_write_report(false)


func finalize() -> void:
	_write_report(true)


func _write_report(complete: bool) -> void:
	if report_path.is_empty():
		return
	var payload := {
		"schema": SCHEMA_VERSION,
		"session_id": session_id,
		"build_sha": build_sha,
		"godot": String(
			Engine.get_version_info().get("string", "unknown")
		),
		"os_family": _os_family(),
		"gpu_vendor": _gpu_vendor(),
		"renderer": _renderer_name(),
		"display_bucket": _display_bucket(),
		"duration_s": int(round(_elapsed_seconds())),
		"complete": complete,
		"counters": counters.duplicate(true),
		"samples": samples,
	}
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(payload))
	file.close()


func _elapsed_seconds() -> float:
	if start_usec <= 0:
		return 0.0
	return float(Time.get_ticks_usec() - start_usec) / 1000000.0


func _new_session_id() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return "%08x%08x" % [
		rng.randi() & 0xffffffff,
		rng.randi() & 0xffffffff,
	]


func _safe_build_sha(value: String) -> String:
	var cleaned := value.strip_edges().to_lower()
	if cleaned.length() < 7 or cleaned.length() > 40:
		return "unknown"
	for character in cleaned:
		if not character in "0123456789abcdef":
			return "unknown"
	return cleaned


func _os_family() -> String:
	match OS.get_name().to_lower():
		"windows":
			return "windows"
		"macos":
			return "macos"
		"linux", "freebsd", "netbsd", "openbsd", "bsd":
			return "linux"
		_:
			return "other"


func _gpu_vendor() -> String:
	var vendor: String = RenderingServer.get_video_adapter_vendor().to_lower()
	if "nvidia" in vendor:
		return "nvidia"
	if "amd" in vendor or "advanced micro" in vendor:
		return "amd"
	if "intel" in vendor:
		return "intel"
	if "apple" in vendor:
		return "apple"
	return "other"


func _renderer_name() -> String:
	var method: String = RenderingServer.get_current_rendering_method()
	if method in ["forward_plus", "mobile", "gl_compatibility"]:
		return method
	return "other"


func _display_bucket() -> String:
	if DisplayServer.get_name() == "headless":
		return "headless"
	var size: Vector2i = DisplayServer.screen_get_size()
	var height_px: int = mini(size.x, size.y)
	if height_px <= 800:
		return "720p"
	if height_px <= 1200:
		return "1080p"
	if height_px <= 1700:
		return "1440p"
	if height_px <= 2400:
		return "4k"
	return "other"


func _round3(value: float) -> float:
	return roundf(value * 1000.0) / 1000.0
