class_name Hud
extends CanvasLayer
## HUD : portraits des opérateurs, barre d'actions de la sélection, alerte.

const PORTRAIT_SCENE: PackedScene = preload("res://scenes/ui/unit_portrait.tscn")

@onready var _portraits: VBoxContainer = %Portraits
@onready var _action_bar: Control = %ActionBar
@onready var _crouch: Button = %Crouch
@onready var _prone: Button = %Prone
@onready var _knife: Button = %Knife
@onready var _knockout: Button = %Knockout
@onready var _throw: Button = %Throw
@onready var _fire_at: Button = %FireAt
@onready var _carry: Button = %Carry
@onready var _crate: Button = %Crate
@onready var _sling: Button = %Sling
@onready var _reload: Button = %Reload
@onready var _stop: Button = %Stop
@onready var _grenade: Button = %Grenade
@onready var _smoke: Button = %Smoke
@onready var _stun: Button = %Stun
@onready var _launcher: Button = %Launcher
@onready var _taser: Button = %Taser
@onready var _launcher_smoke: Button = %LauncherSmoke
@onready var _launcher_gas: Button = %LauncherGas
@onready var _grapple: Button = %Grapple
@onready var _plant: Button = %Plant
@onready var _detonate: Button = %Detonate
@onready var _medkit: Button = %Medkit
@onready var _weapon: Button = %Weapon
@onready var _shield: Button = %Shield
@onready var _menu: Button = %Menu
@onready var _controller: PlayerController = $PlayerController
## Confirmations avant de quitter et de revenir au menu.
var quit_dialog: ConfirmDialog
var menu_dialog: ConfirmDialog
## Page d'aide (touche H), ouverte par le contrôleur.
var help: HelpOverlay
## Menu pause (Échap).
var pause_menu: PauseMenu
## Écran de fin de mission.
var end_screen: EndScreen
## Objectifs de la mission, leur journal (F2), la minicarte (F3) et les
## options (menu pause).
var objectives: Objectives
var objectives_panel: ObjectivesPanel
var minimap: Minimap
var options: OptionsPanel
## Date et heure de l'opération, et chronomètre (en haut à droite, avant
## l'alerte).
var operation_label: Label


func _ready() -> void:
	# Pendant la pause tactique, l'interface reste active : on donne des ordres.
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	_fire_at.pressed.connect(_controller.toggle_pending_action.bind(PlayerController.ACTION_FIRE_AT))
	_carry.pressed.connect(_controller.press_carry)
	_crate.pressed.connect(_controller.toggle_pending_action.bind(PlayerController.ACTION_CRATE))
	_controller.pending_action_changed.connect(func(_action: StringName) -> void: _refresh_actions())
	_sling.pressed.connect(SelectionManager.toggle_sling)
	_reload.pressed.connect(SelectionManager.reload)
	_stop.pressed.connect(SelectionManager.stop)
	_grenade.pressed.connect(_controller.toggle_pending_action.bind(PlayerController.ACTION_GRENADE))
	_smoke.pressed.connect(_controller.toggle_pending_action.bind(PlayerController.ACTION_SMOKE))
	_stun.pressed.connect(_controller.toggle_pending_action.bind(PlayerController.ACTION_STUN))
	_taser.pressed.connect(_controller.toggle_pending_action.bind(PlayerController.ACTION_TASER))
	_launcher.pressed.connect(_controller.toggle_pending_action.bind(PlayerController.ACTION_LAUNCHER))
	_launcher_smoke.pressed.connect(_controller.toggle_pending_action.bind(PlayerController.ACTION_LAUNCHER_SMOKE))
	_launcher_gas.pressed.connect(_controller.toggle_pending_action.bind(PlayerController.ACTION_LAUNCHER_GAS))
	_grapple.pressed.connect(_controller.toggle_pending_action.bind(PlayerController.ACTION_GRAPPLE))
	_plant.pressed.connect(func() -> void: _controller._feedback(SelectionManager.plant_explosive(Input.is_action_pressed(&"action_variant"))))
	_plant.tooltip_text = "Poser une charge (Maj : à retardement, %d s)" % int(ExplosiveCharge.TIMED_FUSE)
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
	SelectionManager.selection_changed.connect(func(_units: Array[Commando]) -> void: _refresh_actions())
	_label_keys()
	# Touches réglées dans les options : libellés à jour.
	Settings.changed.connect(_label_keys)
	_build_mission_panels()
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	pause_menu.restart_requested.connect(restart_mission)
	pause_menu.menu_requested.connect(menu_dialog.ask)
	pause_menu.quit_requested.connect(quit_dialog.ask)
	menu_dialog.canceled.connect(_back_to_pause_menu)
	quit_dialog.canceled.connect(_back_to_pause_menu)
	end_screen = EndScreen.new()
	add_child(end_screen)
	end_screen.restart_requested.connect(restart_mission)
	end_screen.menu_requested.connect(func() -> void:
		get_tree().change_scene_to_file(LevelCatalog.MENU_SCENE))
	# Ajoutée après le menu : elle reçoit Échap la première.
	help = HelpOverlay.new()
	add_child(help)
	pause_menu.help_requested.connect(help.open)
	help.closed.connect(_back_to_pause_menu)
	options = OptionsPanel.new()
	add_child(options)
	pause_menu.options_requested.connect(options.open)
	options.closed.connect(_back_to_pause_menu)
	_refresh_actions()


## Objectifs (d'après le catalogue des niveaux), leur journal en haut à
## droite, et la minicarte en haut à gauche.
func _build_mission_panels() -> void:
	_build_operation_clock()
	var level := get_parent() as Node3D
	var key := ""
	if level is LevelRoot:
		key = (level as LevelRoot).level_key()
	objectives = Objectives.new()
	add_child(objectives)
	objectives.setup(LevelCatalog.objectives_of(LevelCatalog.find(key)))
	objectives_panel = ObjectivesPanel.new()
	_controller.add_child(objectives_panel)
	objectives_panel.setup(objectives)
	# En haut à droite, sous l'alerte, à sa taille minimale.
	objectives_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	objectives_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	objectives_panel.offset_top = 60.0
	minimap = Minimap.new()
	_controller.add_child(minimap)
	if level:
		minimap.setup(level, key)
	minimap.position = Vector2(16, 44)


func _build_operation_clock() -> void:
	var panel := PanelContainer.new()
	panel.name = "OperationPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.tooltip_text = "Date et heure du lancement de l'opération, et sa durée (le chronomètre s'arrête pendant les pauses)."
	operation_label = Label.new()
	operation_label.name = "OperationLabel"
	operation_label.add_theme_font_size_override(&"font_size", 13)
	operation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel.add_child(operation_label)
	var top_right := _controller.get_node_or_null(^"TopRight")
	if top_right:
		top_right.add_child(panel)
		top_right.move_child(panel, 0)
	_update_operation_clock()


## Texte de l'horloge : « Opération du 22/11/2026 à 14:32 » et la durée.
func _update_operation_clock() -> void:
	var clock := OperationClock.of(get_tree())
	if operation_label == null:
		return
	operation_label.get_parent().visible = clock != null
	if clock:
		operation_label.text = "Opération du %s\nDurée  %s" % [clock.date_text(), clock.duration_text()]


func _process(_delta: float) -> void:
	_update_operation_clock()


## Recommence la mission : la scène du niveau est rechargée.
func restart_mission() -> void:
	pause_menu.abandon()
	get_tree().paused = false
	get_tree().reload_current_scene()


## Libellés des boutons, avec leur touche lue dans l'InputMap (réglable :
## `KeyBindings`).
func _label_keys() -> void:
	if not is_inside_tree():
		return
	(_controller.get_node(^"Help") as Label).text = "%s : aide (toutes les commandes)" % KeyNames.label(&"toggle_help")
	# Une touche par famille : chaque appui passe au type suivant.
	var throw_key := KeyNames.label(&"action_grenade")
	var launcher_key := KeyNames.label(&"action_launcher")
	var labels := [
		[_grenade, "Grenade", throw_key], [_smoke, "Fumigène", throw_key], [_stun, "Assourdissante", throw_key],
		[_launcher, "M320", launcher_key], [_launcher_smoke, "Obus fumigène", launcher_key], [_launcher_gas, "Lacrymogène", launcher_key],
		[_weapon, "Arme secondaire", KeyNames.label(&"switch_weapon")], [_fire_at, "Tir libre", KeyNames.label(&"action_fire_at")],
		[_carry, "Porter", KeyNames.label(&"action_carry")], [_plant, "Charge", KeyNames.label(&"action_plant")],
		[_detonate, "Mise à feu", KeyNames.label(&"action_detonate")],
		# Équipement rare : emplacements 7 à 0.
		[_medkit, "Soigner", KeyNames.label(&"action_medkit")], [_grapple, "Grappin", KeyNames.label(&"action_grapple")],
		[_taser, "Taser", KeyNames.label(&"action_taser")], [_shield, "Bouclier", KeyNames.label(&"action_shield")],
		[_crouch, "Accroupi", KeyNames.label(&"posture_crouch")], [_prone, "Rampé", KeyNames.label(&"posture_prone")],
		[_knife, "Couteau", KeyNames.label(&"action_knife")], [_knockout, "Assommer", KeyNames.label(&"action_knockout")],
		[_throw, "Lancer", KeyNames.label(&"action_throw")], [_crate, "Caisse", KeyNames.label(&"action_crate")],
		[_sling, "Bretelle", KeyNames.label(&"action_sling")], [_reload, "Recharger", KeyNames.label(&"reload")],
		[_stop, "Stop", KeyNames.label(&"stop")],
	]
	for entry: Array in labels:
		(entry[0] as Button).text = "%s  [%s]" % [entry[1], entry[2]]


## Une page ouverte depuis le menu pause (aide, confirmation annulée) se
## referme : le menu revient.
func _back_to_pause_menu() -> void:
	if pause_menu.is_suspended():
		pause_menu.open()


## Active la barre d'actions selon la sélection et reflète la posture commune.
func _refresh_actions() -> void:
	# Changement de scène : les unités quittent la sélection alors que le
	# HUD est déjà hors de l'arbre (plus de `get_tree()`).
	if not is_inside_tree():
		return
	var selected := SelectionManager.selected
	var empty := selected.is_empty()
	for button: Button in [_crouch, _prone, _knife, _knockout, _throw, _fire_at, _carry, _crate, _sling, _reload, _stop]:
		button.disabled = empty
	_action_bar.modulate.a = 0.5 if empty else 1.0
	# Équipement : grisé si aucune unité sélectionnée n'en a.
	_grenade.disabled = not selected.any(func(unit: Commando) -> bool: return unit.grenades > 0)
	_smoke.disabled = not selected.any(func(unit: Commando) -> bool: return unit.smoke_grenades > 0)
	_stun.disabled = not selected.any(func(unit: Commando) -> bool: return unit.stun_grenades > 0)
	_taser.disabled = not selected.any(func(unit: Commando) -> bool: return unit.tasers > 0)
	_taser.visible = selected.any(func(unit: Commando) -> bool: return unit.stats.tasers > 0 or unit.tasers > 0)
	_taser.set_pressed_no_signal(_controller.pending_action == PlayerController.ACTION_TASER)
	# Lance-grenades : un bouton par type d'obus, affiché si un opérateur
	# sélectionné en emporte.
	for entry: Array in [[_launcher, Commando.SHELL_EXPLOSIVE], [_launcher_smoke, Commando.SHELL_SMOKE], [_launcher_gas, Commando.SHELL_GAS]]:
		var button: Button = entry[0]
		var shell: StringName = entry[1]
		button.disabled = not selected.any(func(unit: Commando) -> bool: return unit.launcher_rounds(shell) > 0)
		button.visible = selected.any(func(unit: Commando) -> bool: return int(unit.stats.get(shell)) > 0 or unit.launcher_rounds(shell) > 0)
		button.set_pressed_no_signal(PlayerController.LAUNCHER_SHELLS.get(_controller.pending_action, &"") == shell)
	_grapple.disabled = not selected.any(func(unit: Commando) -> bool: return unit.grapnels > 0)
	_plant.disabled = not selected.any(func(unit: Commando) -> bool: return unit.explosives > 0)
	_detonate.disabled = not selected.any(func(unit: Commando) -> bool: return not ExplosiveCharge.planted_by(get_tree(), unit).is_empty())
	_medkit.disabled = not selected.any(func(unit: Commando) -> bool: return unit.medkits > 0)
	_weapon.disabled = not selected.any(func(unit: Commando) -> bool: return unit.has_secondary())
	var carriers := selected.filter(func(unit: Commando) -> bool: return unit.shields > 0)
	_shield.disabled = carriers.is_empty()
	_shield.set_pressed_no_signal(not carriers.is_empty() and carriers.all(func(unit: Commando) -> bool: return unit.shield_raised))
	_grenade.set_pressed_no_signal(_controller.pending_action == PlayerController.ACTION_GRENADE)
	_smoke.set_pressed_no_signal(_controller.pending_action == PlayerController.ACTION_SMOKE)
	_stun.set_pressed_no_signal(_controller.pending_action == PlayerController.ACTION_STUN)
	_grapple.set_pressed_no_signal(_controller.pending_action == PlayerController.ACTION_GRAPPLE)
	_weapon.set_pressed_no_signal(not empty and selected.all(func(unit: Commando) -> bool: return unit.using_secondary))
	_crouch.set_pressed_no_signal(not empty and selected.all(func(unit: Commando) -> bool: return unit.posture == SoldierModel.Posture.CROUCHED))
	_prone.set_pressed_no_signal(not empty and selected.all(func(unit: Commando) -> bool: return unit.posture == SoldierModel.Posture.PRONE))
	_knife.set_pressed_no_signal(_controller.pending_action == PlayerController.ACTION_KNIFE)
	_knockout.set_pressed_no_signal(_controller.pending_action == PlayerController.ACTION_KNOCKOUT)
	_throw.set_pressed_no_signal(_controller.pending_action == PlayerController.ACTION_THROW)
	_fire_at.set_pressed_no_signal(_controller.pending_action == PlayerController.ACTION_FIRE_AT)
	_carry.set_pressed_no_signal(_controller.pending_action == PlayerController.ACTION_CARRY or (not empty and selected.any(func(unit: Commando) -> bool: return unit.carried_body != null)))
	_crate.set_pressed_no_signal(_controller.pending_action == PlayerController.ACTION_CRATE)
	_sling.set_pressed_no_signal(not empty and selected.all(func(unit: Commando) -> bool: return unit.weapon_slung))
