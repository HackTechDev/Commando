class_name Hud
extends CanvasLayer
## HUD : portraits des opérateurs, barre d'actions de la sélection, alerte.

const PORTRAIT_SCENE: PackedScene = preload("res://scenes/ui/unit_portrait.tscn")

@onready var _portraits: HBoxContainer = %Portraits
@onready var _action_bar: Control = %ActionBar
@onready var _crouch: Button = %Crouch
@onready var _prone: Button = %Prone
@onready var _knife: Button = %Knife
@onready var _knockout: Button = %Knockout
@onready var _throw: Button = %Throw
@onready var _crate: Button = %Crate
@onready var _sling: Button = %Sling
@onready var _reload: Button = %Reload
@onready var _stop: Button = %Stop
@onready var _quit: Button = %Quit
@onready var _controller: PlayerController = $PlayerController


func _ready() -> void:
	var units: Array[Commando] = []
	for node in get_tree().get_nodes_in_group(&"commandos"):
		if node is Commando:
			units.append(node as Commando)
	units.sort_custom(func(a: Commando, b: Commando) -> bool: return a.unit_index < b.unit_index)
	for unit in units:
		var portrait := PORTRAIT_SCENE.instantiate() as UnitPortrait
		_portraits.add_child(portrait)
		portrait.setup(unit)
		unit.posture_changed.connect(func(_posture: SoldierModel.Posture) -> void: _refresh_actions())
		unit.sling_changed.connect(func(_slung: bool) -> void: _refresh_actions())

	_crouch.pressed.connect(func() -> void: SelectionManager.toggle_posture(SoldierModel.Posture.CROUCHED))
	_prone.pressed.connect(func() -> void: SelectionManager.toggle_posture(SoldierModel.Posture.PRONE))
	_knife.pressed.connect(_controller.toggle_pending_action.bind(PlayerController.ACTION_KNIFE))
	_knockout.pressed.connect(_controller.toggle_pending_action.bind(PlayerController.ACTION_KNOCKOUT))
	_throw.pressed.connect(_controller.toggle_pending_action.bind(PlayerController.ACTION_THROW))
	_crate.pressed.connect(_controller.toggle_pending_action.bind(PlayerController.ACTION_CRATE))
	_controller.pending_action_changed.connect(func(_action: StringName) -> void: _refresh_actions())
	_sling.pressed.connect(SelectionManager.toggle_sling)
	_reload.pressed.connect(SelectionManager.reload)
	_stop.pressed.connect(SelectionManager.stop)
	_quit.pressed.connect(func() -> void: get_tree().quit())
	SelectionManager.selection_changed.connect(func(_units: Array[Commando]) -> void: _refresh_actions())
	_refresh_actions()


## Active la barre d'actions selon la sélection et reflète la posture commune.
func _refresh_actions() -> void:
	var selected := SelectionManager.selected
	var empty := selected.is_empty()
	for button: Button in [_crouch, _prone, _knife, _knockout, _throw, _crate, _sling, _reload, _stop]:
		button.disabled = empty
	_action_bar.modulate.a = 0.5 if empty else 1.0
	_crouch.set_pressed_no_signal(not empty and selected.all(func(unit: Commando) -> bool: return unit.posture == SoldierModel.Posture.CROUCHED))
	_prone.set_pressed_no_signal(not empty and selected.all(func(unit: Commando) -> bool: return unit.posture == SoldierModel.Posture.PRONE))
	_knife.set_pressed_no_signal(_controller.pending_action == PlayerController.ACTION_KNIFE)
	_knockout.set_pressed_no_signal(_controller.pending_action == PlayerController.ACTION_KNOCKOUT)
	_throw.set_pressed_no_signal(_controller.pending_action == PlayerController.ACTION_THROW)
	_crate.set_pressed_no_signal(_controller.pending_action == PlayerController.ACTION_CRATE)
	_sling.set_pressed_no_signal(not empty and selected.all(func(unit: Commando) -> bool: return unit.weapon_slung))
