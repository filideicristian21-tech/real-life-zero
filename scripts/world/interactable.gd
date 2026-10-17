class_name Interactable
extends Node3D
## Punto di interazione. Il player cerca il più vicino nel gruppo "interactable".

@export var radius: float = 1.8
var prompt_fn: Callable      # () -> String  ("" = non disponibile)
var action_fn: Callable      # () -> void
var id: String = ""

func _ready() -> void:
	add_to_group("interactable")

func get_prompt() -> String:
	return prompt_fn.call() if prompt_fn.is_valid() else ""

func interact() -> void:
	if action_fn.is_valid():
		action_fn.call()

static func make(parent: Node, pos: Vector3, iid: String, prompt: Callable, action: Callable, r: float = 1.8) -> Interactable:
	var it := Interactable.new()
	it.id = iid
	it.position = pos
	it.prompt_fn = prompt
	it.action_fn = action
	it.radius = r
	it.name = "I_" + iid
	parent.add_child(it)
	return it
