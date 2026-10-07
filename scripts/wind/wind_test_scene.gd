extends Node3D

const NAMES = ["Calm", "Breeze", "Strong wind", "Gusts"]
const CREAM = Color("f6ecd7")
const MUTED = Color("a8c6ce")

@onready var ocean: Ocean = $Ocean
@onready var ship: Node3D = $Ship
@onready var camera: Camera3D = $Camera3D
@onready var wind: WindEffects = $WindEffects
var orbit := 0.0
var zoom := 47.0
var state_label: Label
var direction_label: Label
var status_label: Label
var pause_button: Button
var trail_button: Button
var preset_buttons: Array[Button] = []
var direction_slider: HSlider
var ui_layer: CanvasLayer


func _ready() -> void:
	# This scene owns the animation clock so pause freezes the ocean and wind together.
	ocean.set_process(false)
	wind.set_process(false)
	build_ui()
	set_preset(wind.preset)
	get_viewport().size_changed.connect(fit_ui)
	fit_ui()


func fit_ui() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var factor := minf(viewport_size.x / 1440.0, viewport_size.y / 900.0)
	ui_layer.scale = Vector2.ONE * factor
	ui_layer.offset = (viewport_size - Vector2(1440, 900) * factor) * 0.5


func label(text: String, ui_position: Vector2, size: int, color: Color, parent: Node) -> Label:
	var l := Label.new()
	l.text = text
	l.position = ui_position
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l

func button(text: String, ui_position: Vector2, width: float, callback: Callable, parent: Node) -> Button:
	var b := Button.new()
	b.text = text
	b.position = ui_position
	b.size = Vector2(width, 40)
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", CREAM)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("244b59") if state == "normal" else Color("3b7180")
		style.set_corner_radius_all(6)
		b.add_theme_stylebox_override(state, style)
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func panel(ui_position: Vector2, dimensions: Vector2, parent: Node) -> Panel:
	var p := Panel.new()
	p.position = ui_position
	p.size = dimensions
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.10, 0.14, 0.94)
	style.set_corner_radius_all(12)
	p.add_theme_stylebox_override("panel", style)
	parent.add_child(p)
	return p

func build_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(root)
	var top := panel(Vector2(26,24), Vector2(680,151),root)
	label("WIND / TEST SCENE", Vector2(22,14), 27, CREAM, top)
	label("Same ocean. Different air.", Vector2(23,52), 16, MUTED, top)
	for i in range(4):
		preset_buttons.append(button(str(i+1)+"  "+NAMES[i], Vector2(22+i*162,94), 152, func(): set_preset(i), top))
	var bottom := panel(Vector2(26,748),Vector2(1388,128),root)
	state_label = label("",Vector2(22,14),24,CREAM,bottom)
	direction_label = label("",Vector2(472,16),18,CREAM,bottom)
	direction_slider = HSlider.new()
	direction_slider.position = Vector2(472,53)
	direction_slider.size = Vector2(360,28)
	direction_slider.min_value = 0
	direction_slider.max_value = 360
	direction_slider.step = 1
	direction_slider.value = wind.heading
	direction_slider.value_changed.connect(func(v:float): wind.heading = v)
	bottom.add_child(direction_slider)
	status_label = label("",Vector2(22,52),15,MUTED,bottom)
	pause_button = button("Pause  [Space]",Vector2(864,22),190,toggle_pause,bottom)
	trail_button = button("Trails on  [V]",Vector2(1070,22),290,toggle_trails,bottom)
	label("Drag direction  ·  Right-drag to orbit  ·  Scroll to zoom  ·  1–4 presets  ·  R reset",Vector2(22,95),14,MUTED,bottom)
	label("WIND EFFECTS  /  Visual test",Vector2(1090,32),15,CREAM,root)

func set_preset(index: int) -> void:
	wind.preset = index as WindEffects.Preset
	for i in preset_buttons.size():
		preset_buttons[i].modulate = Color("ffdc91") if i == index else Color.WHITE
	print("Wind preset: ",NAMES[index])

func toggle_pause() -> void:
	wind.paused = not wind.paused
	pause_button.text = "Resume  [Space]" if wind.paused else "Pause  [Space]"

func toggle_trails() -> void:
	wind.show_trails = not wind.show_trails
	trail_button.text = "Trails on  [V]" if wind.show_trails else "Trails off  [V]"

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1, KEY_2, KEY_3, KEY_4: set_preset(event.keycode - KEY_1)
			KEY_SPACE: toggle_pause()
			KEY_V: toggle_trails()
			KEY_R:
				wind.heading = 90
				direction_slider.value = wind.heading
				orbit = 0
				zoom = 47
				wind.time = 0
				wind.travel = 0
				set_preset(1)

		if event.keycode in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_SPACE, KEY_V, KEY_R]:
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		orbit -= event.relative.x*0.005
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: zoom = maxf(26,zoom/1.1)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: zoom = minf(85,zoom*1.1)


func _process(delta: float) -> void:
	wind.advance(delta)
	RenderingServer.global_shader_parameter_set("ocean_time",wind.time)
	ocean.wave_time = wind.time
	var sampler := ocean.height_sampler
	var height := sampler.height_at(Vector2.ZERO)
	var sx := (sampler.height_at(Vector2(1.5,0))-sampler.height_at(Vector2(-1.5,0)))/3.0
	var sz := (sampler.height_at(Vector2(0,3))-sampler.height_at(Vector2(0,-3)))/6.0
	ship.position = Vector3(0,height-0.6,0)
	ship.basis = Basis(Quaternion(Vector3.UP,Vector3(-sx,1,-sz).normalized()))*Basis(Vector3.UP,0.3)
	var aim := Vector3(0,height+1.5,0)
	camera.position = aim + Vector3(sin(orbit)*0.7,0.72,cos(orbit)*0.7).normalized()*zoom
	camera.look_at(aim)
	ocean._track_camera()
	wind.refresh()
	var compass: String = ["N","NE","E","SE","S","SW","W","NW"][int(round(wind.heading/45.0))%8]
	direction_label.text = "Blowing toward %s   /   %03d°" % [compass,int(wind.heading)%360]
	state_label.text = NAMES[wind.preset] + "   /   %02d%%" % int(wind.strength*100)
	status_label.text = ["Air trails fade away; ocean swell continues.","Sparse, slow trails with a soft flutter.","Longer, faster trails; a taut pennant.","Passing pulses build, peak, and fall away."][wind.preset]
