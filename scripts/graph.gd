extends Node
class_name Graph

func _ready() -> void:
	pass

var adjacency_list: Dictionary = {}

func add_node(node_id):
	if not adjacency_list.has(node_id):
		adjacency_list[node_id] = []

func add_edge(node_a, node_b):
	add_node(node_a)
	add_node(node_b)
	if node_b not in adjacency_list[node_a]:
		adjacency_list[node_a].append(node_b)
	if node_a not in adjacency_list[node_b]:
		adjacency_list[node_b].append(node_a)

func get_neighbors(node_id) -> Array:
	if adjacency_list.has(node_id):
		#print("Vizinhos de ", node_id, ": ", adjacency_list[node_id])
		return adjacency_list[node_id]
	return []

#func _process(delta: float) -> void:
	#pass
