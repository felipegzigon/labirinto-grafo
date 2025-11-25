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
	# Adicionar todos os nós (marcadores) existentes
	# Marcadores existentes
	graph.add_node("Marker0")
	graph.add_node("Marker1")
	graph.add_node("Marker2")
	graph.add_node("Marker3")
	graph.add_node("Marker4")
	graph.add_node("Marker5")
	graph.add_node("Marker5a")  # Marcador intermediário para curva entre Marker5 e Marker6
	graph.add_node("Marker6")
	graph.add_node("Marker6a")  # Marcador intermediário para curva entre Marker6 e Marker7
	graph.add_node("Marker7")
	
	# 38 Novos marcadores (Marker8 até Marker45)
	graph.add_node("Marker8")
	graph.add_node("Marker9")
	graph.add_node("Marker10")
	graph.add_node("Marker11")
	graph.add_node("Marker12")
	graph.add_node("Marker13")
	graph.add_node("Marker14")
	graph.add_node("Marker15")
	graph.add_node("Marker16")
	graph.add_node("Marker17")
	graph.add_node("Marker18")
	graph.add_node("Marker19")
	graph.add_node("Marker20")
	graph.add_node("Marker21")
	graph.add_node("Marker22")
	graph.add_node("Marker23")
	graph.add_node("Marker24")
	graph.add_node("Marker25")
	graph.add_node("Marker26")
	graph.add_node("Marker27")
	graph.add_node("Marker28")
	graph.add_node("Marker29")
	graph.add_node("Marker30")
	graph.add_node("Marker31")
	graph.add_node("Marker32")
	graph.add_node("Marker33")
	graph.add_node("Marker34")
	graph.add_node("Marker35")
	graph.add_node("Marker36")
	graph.add_node("Marker37")
	graph.add_node("Marker38")
	graph.add_node("Marker39")
	graph.add_node("Marker40")
	graph.add_node("Marker41")
	graph.add_node("Marker42")
	graph.add_node("Marker43")
	graph.add_node("Marker44")
	graph.add_node("Marker45")
	graph.add_node("Marker46")
	
	# Marcadores intermediários para transições (curvas suaves)
	graph.add_node("Marker8a")   # Transição Marker8 -> Marker9
	graph.add_node("Marker8b")   # Transição Marker8 -> Marker9 (alternativa)
	graph.add_node("Marker20a")  # Transição Marker20 -> Marker21
	graph.add_node("Marker27a")  # Transição Marker27 -> Marker28
	graph.add_node("Marker27b")  # Transição Marker27 -> Marker28 (continuação)
	graph.add_node("Marker26a")  # Transição Marker26 -> Marker29
	graph.add_node("Marker34a")  # Transição Marker34 -> Marker35
	graph.add_node("Marker39a")  # Transição Marker39 -> Marker40
	graph.add_node("Marker46a")
	graph.add_node("Marker47")

	# Adicionar arestas (conexões) entre os marcadores
	# Conexões existentes
	graph.add_edge("Marker0", "Marker1")
	graph.add_edge("Marker1", "Marker2")
	graph.add_edge("Marker2", "Marker3")

	graph.add_edge("Marker1", "Marker4")
	graph.add_edge("Marker4", "Marker5")
	
	# Caminho Marker5 -> Marker6 com marcador intermediário para curva suave
	graph.add_edge("Marker5", "Marker5a")
	graph.add_edge("Marker5a", "Marker6")
	
	# Caminho Marker6 -> Marker7 com marcador intermediário para curva suave
	graph.add_edge("Marker6", "Marker6a")
	graph.add_edge("Marker6a", "Marker7")
	graph.add_edge("Marker7", "Marker8")
	# Transição Marker8 -> Marker9 com marcador intermediário para curva suave
	graph.add_edge("Marker8", "Marker8a")
	graph.add_edge("Marker8", "Marker8b")
	graph.add_edge("Marker8b", "Marker9")
	graph.add_edge("Marker8a", "Marker9")
	graph.add_edge("Marker8", "Marker10")
	graph.add_edge("Marker10", "Marker11")
	graph.add_edge("Marker11", "Marker12")
	graph.add_edge("Marker11", "Marker14")
	graph.add_edge("Marker12", "Marker5")
	graph.add_edge("Marker12", "Marker13")
	graph.add_edge("Marker14", "Marker15")
	graph.add_edge("Marker15", "Marker16")
	graph.add_edge("Marker16", "Marker17")
	graph.add_edge("Marker15", "Marker18")
	graph.add_edge("Marker18", "Marker19")
	graph.add_edge("Marker19", "Marker20")
	graph.add_edge("Marker20", "Marker20a")
	graph.add_edge("Marker20a", "Marker21")
	graph.add_edge("Marker20", "Marker22")
	graph.add_edge("Marker22", "Marker23")
	graph.add_edge("Marker23", "Marker24")
	graph.add_edge("Marker23", "Marker25")
	graph.add_edge("Marker20", "Marker26")
	graph.add_edge("Marker26", "Marker27")
	graph.add_edge("Marker27", "Marker46")
	graph.add_edge("Marker46", "Marker46a")
	graph.add_edge("Marker46a", "Marker28")
	graph.add_edge("Marker26", "Marker26a")
	graph.add_edge("Marker26a", "Marker29")
	graph.add_edge("Marker29", "Marker30")
	graph.add_edge("Marker29", "Marker32")
	graph.add_edge("Marker32", "Marker33")
	graph.add_edge("Marker30", "Marker31")
	graph.add_edge("Marker33", "Marker31")
	graph.add_edge("Marker31", "Marker34")
	graph.add_edge("Marker34", "Marker34a")
	graph.add_edge("Marker34a", "Marker35")
	graph.add_edge("Marker35", "Marker36")
	graph.add_edge("Marker36", "Marker37")
	graph.add_edge("Marker36", "Marker38")
	graph.add_edge("Marker38", "Marker5")
	graph.add_edge("Marker33", "Marker39")
	graph.add_edge("Marker39", "Marker39a")
	graph.add_edge("Marker39a", "Marker40")
	graph.add_edge("Marker40", "Marker41")
	graph.add_edge("Marker41", "Marker42")
	graph.add_edge("Marker42", "Marker43")
	graph.add_edge("Marker4", "Marker44")
	graph.add_edge("Marker44", "Marker45")
	graph.add_edge("Marker41", "Marker43")
	graph.add_edge("Marker41", "Marker12")
	graph.add_edge("Marker47", "Marker25")


















	
	





	
	# ADICIONE AQUI AS CONEXÕES ENTRE OS NOVOS MARCADORES
	# Exemplo:
	# graph.add_edge("Marker7", "Marker8")   # Conecta Marker7 com Marker8
	# graph.add_edge("Marker8", "Marker9")   # Conecta Marker8 com Marker9
	# graph.add_edge("Marker3", "Marker10")  # Conecta Marker3 com Marker10
	# ... adicione todas as conexões conforme você mapeia o mapa

	print("Adjacência final: ", graph.adjacency_list)
