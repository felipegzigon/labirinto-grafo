extends Node
class_name DFS

func find_path_with_steps(graph: Graph, start, goal) -> Array:
	var visited = {}
	var path = []
	var steps = [] # <== Histórico completo (visitas e voltas)
	_dfs_recursive(graph, start, goal, visited, path, steps)
	return steps

func _dfs_recursive(graph: Graph, current, goal, visited: Dictionary, path: Array, steps: Array) -> bool:
	visited[current] = true
	steps.append({"action": "visit", "node": current})
	path.append(current)

	if current == goal:
		return true

	for n in graph.get_neighbors(current):
		if not visited.has(n):
			steps.append({"action": "move_to", "node": n})
			if _dfs_recursive(graph, n, goal, visited, path, steps):
				return true

	if path.size() > 1:
		var parent = path[path.size() - 2]
		steps.append({"action": "backtrack", "node": parent})

	path.pop_back()
	return false


#func _ready() -> void:
	#pass
#
#func _process(delta: float) -> void:
	#pass
