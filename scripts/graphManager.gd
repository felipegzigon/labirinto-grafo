extends Node
class_name GraphManager

@onready var graph: Graph = Graph.new()
@onready var waypoints_parent = $"../Waypoints"
#@onready var graph_manager = $graphManager

func _ready():
	_build_graph()
	
	#DFS
	var dfs = preload("res://scripts/dfs.gd").new()
	var steps = dfs.find_path_with_steps(graph, "Marker0", "Marker7")
	print("Passos do DFS:")
	for s in steps:
		print(s)

func _build_graph():
	graph.add_node("Marker0")
	graph.add_node("Marker1")
	graph.add_node("Marker2")
	graph.add_node("Marker3")
	graph.add_node("Marker4")
	graph.add_node("Marker5")
	graph.add_node("Marker6")
	graph.add_node("Marker7")

	graph.add_edge("Marker0", "Marker1")
	graph.add_edge("Marker1", "Marker2")
	graph.add_edge("Marker2", "Marker3")

	graph.add_edge("Marker1", "Marker4")
	graph.add_edge("Marker4", "Marker5")
	graph.add_edge("Marker5", "Marker6")
	graph.add_edge("Marker6", "Marker7")

	print("Adjacência final: ", graph.adjacency_list)
