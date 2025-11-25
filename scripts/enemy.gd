extends CharacterBody2D

@export var speed := 100.0
var steps = []
var current_step = 0
var graph_manager
var marker_nodes = {}
var current_tween: Tween = null  # Referência ao tween atual

func _ready():
	graph_manager = get_node("../GraphManager")
	
	#Posicao dos markers
	for marker in graph_manager.waypoints_parent.get_children():
		marker_nodes[marker.name] = marker.global_position

	# passos dfs
	var dfs = preload("res://scripts/dfs.gd").new()
	steps = dfs.find_path_with_steps(graph_manager.graph, "Marker0", "Marker7")

	#node inicial
	global_position = marker_nodes["Marker0"]

	print("Passos do inimigo:", steps)
	# Começa o movimento
	_move_next_step()
	
	print("Enemy start:", global_position)
	for m in marker_nodes:
		print(m, " = ", marker_nodes[m])

func _move_next_step():
	if current_step >= steps.size():
		return
	
	var step = steps[current_step]
	var node_name = step["node"]

	match step["action"]:
		"visit", "move_to":
			if marker_nodes.has(node_name):
				var target_pos = marker_nodes[node_name]
				# Cancelar tween anterior se existir
				if current_tween and current_tween.is_valid():
					current_tween.kill()
				current_tween = create_tween()
				current_tween.tween_property(self, "global_position", target_pos, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				current_tween.finished.connect(func(): _next_step())
		"backtrack":
			var target_index = current_step - 1
			while target_index >= 0 and steps[target_index]["action"] == "backtrack":
				target_index -= 1

			if target_index >= 0:
				var prev_node = step["node"]
				if marker_nodes.has(prev_node):
					var target_pos = marker_nodes[prev_node]
					# Cancelar tween anterior se existir
					if current_tween and current_tween.is_valid():
						current_tween.kill()
					current_tween = create_tween()
					current_tween.tween_property(self, "global_position", target_pos, 0.8)
					current_tween.finished.connect(func(): _next_step())

func _next_step():
	current_step += 1
	_move_next_step()

func reset_to_start():
	"""Reseta o inimigo para o início do caminho"""
	current_step = 0
	
	# Cancelar qualquer movimento em andamento
	if current_tween and current_tween.is_valid():
		current_tween.kill()
		current_tween = null
	
	# Reposicionar no Marker0
	if marker_nodes.has("Marker0"):
		global_position = marker_nodes["Marker0"]
	
	# Reiniciar movimento
	_move_next_step()
