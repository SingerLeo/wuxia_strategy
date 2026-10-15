class_name PlaceholderPage
extends Page
## 尚未实装的功能页占位。


func _init(title: String, hint: String) -> void:
	super._init()
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var heading := Page.make_label(title, &"Heading")
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)
	var sub := Page.make_label(hint, &"Muted")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	add_child(box)
