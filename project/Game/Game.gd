class_name Game
extends Node2D

enum EndState {
	LEFT_WIN, RIGHT_WIN, DRAW
}

const SUPPLY_SIZE = 3

export(Array, Resource) var _initial_stack_tile_types := []
export var _held_tile_z_index := 21
var _original_tile_z_index := 0
var _pressed_tile : Node2D
var _hovered_node : Node2D
var _original_tile_position := Vector2(0, 0)
var _is_left_player_turn := true
var _left_stack := []
var _right_stack := []
var _is_game_over := false
var _left_score := 0
var _right_score := 0

onready var _music_manager := find_node("AudioManager")
onready var _tiles := find_node("Tiles")
onready var _board := find_node("Board")
onready var _no_drop_sound := find_node("NoDropSound")
onready var _drop_sound := find_node("DropSound")
onready var _turn_sting := find_node("PlayerTurnSound")
onready var _pick_up_sound := find_node("PickUpSound")
onready var _gui := find_node("GUI")
onready var _left_supply := find_node("LeftSupply")
onready var _right_supply := find_node("RightSupply")
onready var _left_stack_position := find_node("LeftStackPosition")
onready var _right_stack_position := find_node("RightStackPosition")
onready var _space_indicator := find_node("SpaceIndicator")



func _ready() -> void:
	_music_manager.play_main_theme()
	_create_stacks()
	_shuffle_stacks()
	_display_supply()
	_display_stack_top()
	_update_turn_in_gui()


func _physics_process(_delta) -> void:
	if not _is_game_over:
		var current_mouse_position = get_global_mouse_position()
		var found_hover = false

		if _pressed_tile != null:
			_pressed_tile.global_position = current_mouse_position


		if Input.is_action_just_pressed("debug_fill_board"):
			_debug_fill_board()

		# empty_space for loop needs to be first 
		for space in _board.get_spaces():
			if space.contains(current_mouse_position):
				_space_indicator.neighbors = _board.get_neighbors(space)
				_hovered_node = space
				found_hover = true

				if _pressed_tile != null:
					_space_indicator.move(_hovered_node.global_position)
				if _hovered_node is Tile:
					_space_indicator.hide()

		for tile in _tiles.get_children():
			if tile != _pressed_tile and tile.contains(current_mouse_position):
				_hovered_node = tile
				found_hover = true

		if not found_hover:
			_hovered_node = null
			_space_indicator.hide()


func _on_Tile_pressed(tile: Tile) -> void:
	if _pressed_tile == null:
		_pressed_tile = tile
		_original_tile_position = tile.global_position

		_original_tile_z_index = tile.z_index
		tile.z_index = _held_tile_z_index
		_pick_up_sound.play(0.11)

		# warning-ignore:return_value_discarded
		tile.connect("released", self, "_on_Tile_released", [tile])


func _on_Tile_released(tile: Tile) -> void:
	tile.disconnect("released", self, "_on_Tile_released")
	_pressed_tile = null
	tile.z_index = _original_tile_z_index

	_space_indicator.hide()

	if _hovered_node is Tile:
		_no_drop_sound.play()
		tile.global_position = _original_tile_position

	elif _hovered_node is EmptySpace:
		_place_tile_on_board(tile)

	else:
		tile.global_position = _original_tile_position


func _update_turn_in_gui() -> void:
	_gui.set_is_left_player_turn(_is_left_player_turn)


func _swap_turn() -> void:
	_is_left_player_turn = !_is_left_player_turn

	if _is_left_player_turn:
		_turn_sting.play()
	else:
		_turn_sting.play()

	_update_turn_in_gui()


# This creates a tile in the original tile position
func _make_new_tile(tile_type) -> Node2D:
	var tile : Node2D = preload("res://Tile/Tile.tscn").instance()

	# Tile need to be added to scene tree before initialization of the type.
	_tiles.add_child(tile)
	tile.initialize_type(tile_type)

	# warning-ignore:return_value_discarded
	tile.connect("pressed", self, "_on_Tile_pressed", [tile])
	return tile


func _shuffle_stacks() -> void:
	_left_stack.shuffle()
	_right_stack.shuffle()


func _create_stacks() -> void:
	for type in _initial_stack_tile_types:
		var left_tile := _make_new_tile(type)
		var right_tile := _make_new_tile(type)
		left_tile.visible = false
		right_tile.visible = false
		left_tile.global_position = _left_stack_position.global_position
		right_tile.global_position = _right_stack_position.global_position
		_left_stack.append(left_tile)
		_right_stack.append(right_tile)


func _display_supply() -> void:
	for i in SUPPLY_SIZE:
		_move_tile_to_supply(_left_stack.pop_front(), _left_supply.get_children()[i].global_position)
		_move_tile_to_supply(_right_stack.pop_front(), _right_supply.get_children()[i].global_position)


func _display_stack_top() -> void:
	if not _left_stack.empty():
		_left_stack[0].visible = true
		_left_stack[0].modulate = Color("#666")

	if not _right_stack.empty():
		_right_stack[0].visible = true
		_right_stack[0].modulate = Color("#666")


func _place_tile_on_board(tile: Tile) -> void:
	_drop_sound.play()
	tile.global_position = _hovered_node.global_position
	tile.set_interactable(false)


	#Add new tile to supply
	if _is_left_player_turn and _left_stack.size() > 0:
		_move_tile_to_supply(_left_stack.pop_front(), _original_tile_position)
	elif not _is_left_player_turn and _right_stack.size() > 0:
		_move_tile_to_supply(_right_stack.pop_front(), _original_tile_position)
	#Make placed tile small
	tile.set_state(1)
	_display_stack_top()

	var index_of_hovered_node = _board.get_spaces().find(_hovered_node)
	var score_modifier = _board.get_points(tile, index_of_hovered_node)

	if _is_left_player_turn:
		_left_score += score_modifier
	else:
		_right_score += score_modifier
	_gui.update_score(_left_score, _right_score)
	
	if _board.get_number_of_empty_spaces() == 0:
		_on_board_filled()
	else:
		_swap_turn()



func _move_tile_to_supply(tile: Tile, position: Vector2) -> void:
	var tween = get_tree().create_tween()
	tile.modulate = Color.white

	tile.visible = true
	tile.z_index = 2
	tween.tween_property(tile, "global_position", position, 1)\
	  .set_trans(Tween.TRANS_BOUNCE)\
	  .set_ease(Tween.EASE_OUT)\
	  .connect("finished", self, "_tween_end", [tile])
 

func _on_board_filled() -> void:
	_is_game_over = true

	for tile in _tiles.get_children():
		tile.set_interactable(false)

	var end_state = EndState.DRAW

	if _left_score > _right_score:
		end_state = EndState.LEFT_WIN
		_music_manager.play_gameover_win()
	elif _left_score < _right_score:
		end_state = EndState.RIGHT_WIN
		_music_manager.play_gameover_win()
	else:
		_music_manager.play_gameover_tie()
	
	_gui.display_gameover(end_state)


func _tween_end(tile: Tile) -> void:
	tile.z_index = 0
	tile.set_interactable(true)


func _debug_fill_board() -> void:

	_on_board_filled()
