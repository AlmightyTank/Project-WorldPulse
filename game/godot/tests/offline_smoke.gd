extends SceneTree

var _offline_endpoint := TCPServer.new()
var _result := -1


func _initialize() -> void:
	await process_frame
	create_timer(8.0).timeout.connect(func() -> void: _fail("Smoke test timed out."))

	# Hold an ephemeral loopback port without replying so a running backend cannot mask an outage.
	if _offline_endpoint.listen(0, "127.0.0.1") != OK:
		_fail("Could not reserve the loopback test port.")
		return
	OS.set_environment("WORLD_PULSE_API_URL", "http://127.0.0.1:%d" % _offline_endpoint.get_local_port())

	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene", "")
	if main_scene.is_empty() or change_scene_to_file(main_scene) != OK:
		_fail("Could not boot the configured main scene.")
		return
	await scene_changed

	var camera := root.get_camera_3d()
	var ground := current_scene.get_node_or_null("Ground") as MeshInstance3D
	var sun := current_scene.get_node_or_null("Sun") as DirectionalLight3D
	var environment := current_scene.get_node_or_null("Environment") as WorldEnvironment
	if camera == null or camera.projection != Camera3D.PROJECTION_PERSPECTIVE \
			or ground == null or ground.mesh == null or sun == null \
			or environment == null or environment.environment == null:
		_fail("Main scene is missing its perspective camera, ground, sun or environment.")
		return

	var readout := current_scene.get_node_or_null("HUD/WorldStatus/Readout") as Label
	var request := current_scene.get_node_or_null("HUD/WorldStatus/Request") as HTTPRequest
	if readout == null or request == null or not readout.is_visible_in_tree() \
			or not readout.text.begins_with("World status: checking"):
		_fail("The HUD did not render its initial checking state while the request was pending.")
		return
	request.request_completed.connect(_record_result)

	while _result == -1:
		await process_frame
	if _result != HTTPRequest.RESULT_TIMEOUT or not _offline_endpoint.is_connection_available() \
			or readout.text != "World status: offline" or root.get_camera_3d() != camera:
		_fail("Expected the real loopback request to time out, the HUD to show offline and the camera to stay active.")
		return

	print("PASS: main scene booted and stayed active through a world status outage.")
	quit(0)


func _record_result(result: int, _code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_result = result


func _fail(message: String) -> void:
	push_error("FAIL: " + message)
	quit(1)
