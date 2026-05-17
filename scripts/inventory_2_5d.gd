extends Node
class_name Inventory25D

signal root_fragments_changed(count: int)

var root_fragments := 0


func add_root_fragments(amount: int) -> int:
	root_fragments += max(amount, 0)
	root_fragments_changed.emit(root_fragments)
	return root_fragments
