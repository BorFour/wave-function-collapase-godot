extends Node3D

@onready var number_cells = []

@onready var select_mutex = Mutex.new();
@onready var can_click = true;
const tween_animation_step_time: float = 0.5;
const n_shakes_incorrect_play: int = 3;

@onready var sudoku_board = $"..";
@onready var cell_number_prefab = preload("res://prefabs/mini_sudoku_cell_number.tscn")
@onready var background_cell_number_prefab = preload("res://prefabs/background_cell_number.tscn")
var n_rows: int;
var n_columns: int;


func _ready():
	# TODO: generate dynamically the sudoku number
	n_rows = sudoku_board.n_rows;
	n_columns = sudoku_board.n_columns;
	_spawn_number_nodes()
	_spawn_background()
	$Border.scale = Vector3(n_columns, n_rows, 1)
	$Border.position = Vector3(n_columns / 2.0 - 1, - (n_rows / 2.0 - 1) , $Border.position.z)


func __cell_number_position(column_number: int, row_number: int) -> Vector3:
	return Vector3(column_number * 2 - n_columns / 2.0, -(row_number * 2 - n_rows / 2.0) , 0);


func _spawn_number_nodes():
	# TODO: creates the nodes for each of the numbers and attaches them as children to the Sudoku Cell
	# From left to right from button up, add to the dictionary using numbers from 1 to 6.
	# FIXME: why not use an array instead? Seems a bit inconsistent with the way the board
	# stores the reference to its cell children	
	for r in range(n_rows):
		for c in range(n_columns):
			var child = cell_number_prefab.instantiate();
			child.spawn(
				__cell_number_position(c, r),
				r * n_columns + c + 1
			);
			add_child(child)
			# Add the cell number to the data structure
			number_cells.append(child)


func _spawn_background():
	"""Spawn the canvas behind the numbers"""
	for r in range(n_rows):
		for c in range(n_columns):
			var child = background_cell_number_prefab.instantiate();
			child.position = __cell_number_position(c, r)
			add_child(child)


func spawn(spawn_position: Vector3):
	"""This method is called when the prefab is spawned dynamically."""
	position = spawn_position


func can_be_clicked() -> bool:
	return can_click and not sudoku_board.is_algorithm_running;
	

func _set_can_click_to_true():
	can_click = true;


func _is_number_selected() -> bool:
	return get_meta("SelectedNumber") >= 1
	

func _deselect_all_cells():
	for cell in number_cells:
		cell.get_deselected()


func __center_of_cell() -> Vector3:
	return Vector3(n_columns / 2.0 - 1, -(n_rows / 2.0 - 1), 0.01)


func _select_number_cell_by_number(num: int):
	var cell_to_select = number_cells[num - 1];
	var tween = get_tree().create_tween().bind_node(self)
	_deselect_all_cells()

	cell_to_select.get_selected()

	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.set_parallel(true)
	tween.tween_property(cell_to_select, "position", __center_of_cell(), tween_animation_step_time)
	tween.tween_property(cell_to_select, "scale", Vector3(n_columns, 1, n_rows), tween_animation_step_time)

	tween.set_parallel(false)
	tween.tween_callback(_set_can_click_to_true)

	set_meta("SelectedNumber", num);


func _delect_selected_number():
	var cell_to_select = number_cells[get_meta("SelectedNumber") - 1];
	var tween = get_tree().create_tween().bind_node(self)
	
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.set_parallel(true)
	tween.tween_property(cell_to_select, "scale", Vector3(1, 1, 1), tween_animation_step_time)
	tween.tween_property(cell_to_select, "position", cell_to_select.original_position, tween_animation_step_time)
	
	tween.set_parallel(false)
	tween.tween_callback(cell_to_select.get_deselected)
	tween.tween_callback(_set_can_click_to_true)

	set_meta("SelectedNumber", -1);


func safe_reset():
	select_mutex.lock()
	can_click = false;
	
	if _is_number_selected():
		_delect_selected_number()
	else:
		can_click = true;
		select_mutex.unlock()
	
	for number_cell in number_cells:
		number_cell.visible = true;


func safe_select_number(num: int):
	select_mutex.lock()
	can_click = false;
	
	if not _is_number_selected():
		_select_number_cell_by_number(num)
	else:
		can_click = true;
		select_mutex.unlock()


func hide_unplayable_numbers(playable_numbers: Array):
	if _is_number_selected():
		return
	
	for num in range(1, number_cells.size() + 1):
		if not playable_numbers.has(num):
			number_cells[num - 1].visible = false


func click_number_cell_by_number(num: int):
	if not can_click:
		return

	select_mutex.lock()
	can_click = false;
	
	var selected_number = get_meta("SelectedNumber");
	if _is_number_selected():
		if selected_number != num:
			print("Oopsie")
			can_click = true;
			select_mutex.unlock()
			return

		_delect_selected_number()
	else:
		_select_number_cell_by_number(num)
	select_mutex.unlock()
	
func shake_incorrect_play():
	"""Shakes when the player tries to play an incorrect number in this cell."""
	
	if not can_click:
		return

	select_mutex.lock()
	can_click = false;

	var original_position = position;
	var tween = get_tree().create_tween().bind_node(self)
	
	tween.set_trans(Tween.TRANS_SINE)
	for i in range(n_shakes_incorrect_play):
		tween.tween_property(self, "position", Vector3(original_position.x + 0.075, original_position.y, original_position.z + 0.1), 0.1)
		tween.tween_property(self, "position", Vector3(original_position.x - 0.075, original_position.y, original_position.z + 0.1), 0.1)
	tween.tween_property(self, "position", original_position, 0.1)
	
	tween.tween_callback(_set_can_click_to_true)
	select_mutex.unlock();
	
