extends PanelContainer

const DEFAULT_API_URL := "http://127.0.0.1:3000"
const OFFLINE_TEXT := "World status: offline"
const UNAVAILABLE_TEXT := "World status: unavailable"

@onready var _readout: Label = $Readout
@onready var _request: HTTPRequest = $Request


func _ready() -> void:
	var base_url := OS.get_environment("WORLD_PULSE_API_URL").strip_edges()
	if base_url.is_empty():
		base_url = DEFAULT_API_URL

	_request.request_completed.connect(_on_request_completed)
	var endpoint := base_url.rstrip("/") + "/api/world/status"
	if _request.request(endpoint, ["Accept: application/json"]) != OK:
		_readout.text = OFFLINE_TEXT


func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_readout.text = OFFLINE_TEXT
		return

	if code < 200 or code >= 300:
		_readout.text = UNAVAILABLE_TEXT
		return

	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) == OK and json.data is Dictionary \
			and json.data.get("simulationStatus") == "not_started":
		_readout.text = "World status: simulation not started"
	else:
		_readout.text = UNAVAILABLE_TEXT
