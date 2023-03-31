class_name Tile
extends Node2D


signal pressed
signal released
signal animation_finished


enum State{
	BIG, SMALL
}


export var size := Vector2(175, 175)
var _interactable = false
var _pressed = false
var type: TileType

var state = State.BIG setget set_state

onready var _supply_sprite := find_node("SupplyTexture")
onready var _supply_tile := find_node("SupplyTile")
onready var _board_sprite := get_node("BoardSprite")
onready var _name_label := get_node("AnimalName")


func contains(mouse_position:Vector2) -> bool:
	var center := global_position - size / 2
	var rect = Rect2(center, size)
	return rect.has_point(mouse_position)


func _on_Area2D_input_event(_viewport, _event, _shape_idx):
	if _interactable and Input.is_action_just_pressed("hold_tile") and not _pressed:
			_pressed = true
			emit_signal("pressed")


func _process(_delta):
	if _interactable and Input.is_action_just_released("hold_tile") and _pressed:
			_pressed = false
			emit_signal("released")


func set_interactable(interactable):
	_interactable = interactable


func initialize_type(init_type: TileType):
	assert(type == null)

	type = init_type

	_supply_sprite.texture = type.in_supply_texture
	_board_sprite.texture = type.on_board_texture
	_name_label.text = type.name
	
	find_node("PositivePoints").text = "+%s" % type.positive_score_modifier
	find_node("NegativePoints").text = "-%s" % abs(type.negative_score_modifier)

	find_node("PositiveCreatures").text = ", ".join(type.positive_neighbor_names)
	find_node("NegativeCreatures").text = ", ".join(type.negative_neighbor_names)


func get_type():
	return type


func set_state(value) -> void:
	state = value
	if state == State.BIG:
		_enter_big_state()
	else:
		_enter_small_state()


func _enter_big_state() -> void:
	_supply_tile.visible = true
	_board_sprite.visible = false
	_name_label.visible = true


func _enter_small_state() -> void:
	_supply_tile.visible = false
	_board_sprite.visible = true
	_name_label.visible = false


func calculate_points(neighbors: Array) -> int:
	var points := 0
	var delay_time = 0
	var delay_increment = .30

	for neighbor in neighbors:
		var score_indicator = preload("res://Tile/ScoreIndicator/ScoreIndicator.tscn").instance()
		var _score_modifier := 0

		add_child(score_indicator)
		score_indicator.global_position = neighbor.global_position

		if "Empty Field" in type.positive_neighbor_names and neighbor is EmptySpace:
			_score_modifier = type.positive_score_modifier

		elif "Empty Field" in type.negative_neighbor_names and neighbor is EmptySpace:
			_score_modifier = type.negative_score_modifier

		elif neighbor.type.name in type.positive_neighbor_names:
			_score_modifier = type.positive_score_modifier

		elif neighbor.type.name in type.negative_neighbor_names:
			_score_modifier = type.negative_score_modifier

		points += _score_modifier
		score_indicator.show_score_modified(_score_modifier)
		if neighbors.find(neighbor)==neighbors.size()-1:
			delay_indicator_animation(score_indicator,delay_time,true)
		else:
			delay_indicator_animation(score_indicator,delay_time,false)
		delay_time += delay_increment

	return points


func delay_indicator_animation(score_indicator,delay_time,is_last_neighbor):
	yield(get_tree().create_timer(delay_time), "timeout")
	score_indicator.play_indicate_score()
	if is_last_neighbor: 
		yield(get_tree().create_timer(0.2), "timeout")
		emit_signal("animation_finished")
