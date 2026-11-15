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
@onready var _grenade: Button = %Grenade
@onready var _plant: Button = %Plant
@onready var _detonate: Button = %Detonate
@onready var _medkit: Button = %Medkit
@onready var _weapon: Button = %Weapon
@onready var _shield: Button = %Shield
@onready var _menu: Button = %Menu
@onready var _quit: Button = %Quit
@onready var _controller: PlayerController = $PlayerController
## Confirmations avant de quitter et de revenir au menu.
var quit_dialog: ConfirmDialog
var menu_dialog: ConfirmDialog


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
		unit.weapon_changed.connect(func(_secondary: bool) -> void: _refresh_actions())
		unit.shield_changed.connect(func(_raised: bool) -> void: _refresh_actions())

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
	_grenade.pressed.connect(_controller.toggle_pending_action.bind(PlayerController.ACTION_GRENADE))
	_plant.pressed.connect(func() -> void: _controller._feedback(SelectionManager.plant_explosive()))
	_detonate.pressed.connect(func() -> void: _controller._feedback(SelectionManager.detonate_explosives() > 0))
	_medkit.pressed.connect(func() -> void: _controller._feedback(SelectionManager.use_medkit()))
	_weapon.pressed.connect(SelectionManager.switch_weapons)
	_shield.pressed.connect(func() -> void: _controller._feedback(SelectionManager.toggle_shield()))
	EventBus.unit_ammo_changed.connect(func(_unit: Node3D) -> void: _refresh_actions())
	menu_dialog = ConfirmDialog.for_menu(self)
	add_child(menu_dialog)
	_menu.pressed.connect(menu_dialog.ask)
	quit_dialog = ConfirmDialog.for_quit(self)
	add_child(quit_dialog)
	_quit.pressed.connect(quit_dialog.ask)
	SelectionManager.selection_changed.connect(func(_units: Array[Commando]) -> void: _refresh_actions())
	_refresh_actions()


## Active la barre d'actions selon la sélection et reflète la posture commune.
func _refresh_actions() -> void:
	var selected := SelectionManager.selected
	var empty := selected.is_empty()
	for button: Button in [_crouch, _prone, _knife, _knockout, _throw, _crate, _sling, _reload, _stop]:
		button.disabled = empty
	_action_bar.modulate.a = 0.5 if empty else 1.0
	# Équipement : grisé si aucune unité sélectionnée n'en a.
	_grenade.disabled = not selected.any(func(unit: Commando) -> bool: return unit.grenades > 0)
	_plant.disabled = not selected.any(func(unit: Commando) -> bool: return unit.explosives > 0)
	_detonate.disabled = not selected.any(func(unit: Commando) -> bool: return not ExplosiveCharge.planted_by(get_tree(), unit).is_empty())
	_medkit.disabled = not selected.any(func(unit: Commando) -> bool: return unit.medkits > 0)
	_weapon.disabled = not selected.any(func(unit: Commando) -> bool: return unit.has_secondary())
	var carriers := selected.filter(func(unit: Commando) -> bool: return unit.shields > 0)
	_shield.disabled = carriers.is_empty()
	_shield.set_pressed_no_signal(not carriers.is_empty() and carriers.all(func(unit: Commando) -> bool: return unit.shield_raised))
	_grenade.set_pressed_no_signal(_controller.pending_action == PlayerController.ACTION_GRENADE)
	_weapon.set_pressed_no_signal(not empty and selected.all(func(unit: Commando) -> bool: return unit.using_secondary))
	_crouch.set_pressed_no_signal(not empty and selected.all(func(unit: Commando) -> bool: return unit.posture == SoldierModel.Posture.CROUCHED))
	_prone.set_pressed_no_signal(not empty and selected.all(func(unit: Commando) -> bool: return unit.posture == SoldierModel.Posture.PRONE))
	_knife.set_pressed_no_signal(_controller.pending_action == PlayerController.ACTION_KNIFE)
	_knockout.set_pressed_no_signal(_controller.pending_action == PlayerController.ACTION_KNOCKOUT)
	_throw.set_pressed_no_signal(_controller.pending_action == PlayerController.ACTION_THROW)
	_crate.set_pressed_no_signal(_controller.pending_action == PlayerController.ACTION_CRATE)
	_sling.set_pressed_no_signal(not empty and selected.all(func(unit: Commando) -> bool: return unit.weapon_slung))
