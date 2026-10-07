extends Button
## Color swatch that opens the shared palette inside the Harbor sign.
signal color_changed(value: Color)
signal palette_requested(button: Button)
const COLORS := [
	"f3e3c5", "d8c7a0", "d3bd83", "bb966d",
	"aa6344", "78332d", "a95f65", "c97858",
	"665477", "434568", "263d59", "3576a0",
	"87c4cb", "25585b", "39735b", "534235",
	"713e2e", "52736b", "273d48", "282f34"
]
var color := Color.WHITE:
	set(value):
		color = value
		if is_node_ready(): _refresh_style()
func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_refresh_style()
	pressed.connect(func(): palette_requested.emit(self))
func _refresh_style() -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var style := get_theme_stylebox(state, "Button").duplicate() as StyleBoxFlat
		style.bg_color = color
		style.border_color = Color("a4dfe3") if state != "normal" else color.darkened(0.25)
		add_theme_stylebox_override(state, style)
