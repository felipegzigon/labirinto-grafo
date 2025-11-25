extends CharacterBody2D

var graph_manager
var marker_nodes = {}
var current_tween: Tween = null  # Referência ao tween atual
var current_marker: String = ""  # Marcador atual onde o inimigo está
var visited_markers: Array = []  # Marcadores já visitados (para DFS)
var speed: float = 0.0  # Velocidade atual
var base_speed: float = 0.0  # Velocidade base (30% mais rápido que o player)
var player: CharacterBody2D = null  # Referência ao player
var is_chasing: bool = false  # Flag para modo perseguição

func _ready():
	graph_manager = get_node("../GraphManager")
	
	#Posicao dos markers
	for marker in graph_manager.waypoints_parent.get_children():
		marker_nodes[marker.name] = marker.global_position

	# Obter referência ao player
	player = get_node_or_null("../Player")
	
	# Calcular velocidade baseada no player (30% mais rápido)
	if player:
		# Tentar acessar a propriedade movement_speed do player
		if "movement_speed" in player:
			base_speed = player.movement_speed * 1.3  # 30% mais rápido
			speed = base_speed
			print("Velocidade base do inimigo: ", base_speed, " (Player: ", player.movement_speed, ")")
		else:
			# Fallback se a propriedade não existir
			base_speed = 260.0 * 1.3  # 30% mais que a velocidade padrão do player
			speed = base_speed
			print("Velocidade base do inimigo (fallback - propriedade não encontrada): ", base_speed)
	else:
		# Fallback se não conseguir acessar o player
		base_speed = 260.0 * 1.3  # 30% mais que a velocidade padrão do player
		speed = base_speed
		print("Velocidade base do inimigo (fallback - player não encontrado): ", base_speed)

	# Escolher um marcador aleatório para spawn (exceto Marker0 onde o player nasce)
	var spawn_marker = _get_random_spawn_marker()
	
	# Inicializar posição e marcador atual
	if marker_nodes.has(spawn_marker):
		global_position = marker_nodes[spawn_marker]
		current_marker = spawn_marker
		visited_markers = [spawn_marker]  # Marcar como visitado
		print("Inimigo spawnado em: ", spawn_marker)
	else:
		# Fallback para Marker1 se o marcador aleatório não existir
		var fallback = marker_nodes.get("Marker1", marker_nodes["Marker0"])
		global_position = fallback
		current_marker = "Marker1" if marker_nodes.has("Marker1") else "Marker0"
		visited_markers = [current_marker]
	
	# Começar movimento aleatório usando DFS
	_move_to_random_neighbor()
	
	print("Enemy start:", global_position)
	print("Marcador inicial: ", current_marker)

func _move_to_random_neighbor():
	"""Move o inimigo para um vizinho aleatório usando DFS"""
	if current_marker == "" or not graph_manager or not graph_manager.graph:
		return
	
	# Obter vizinhos do marcador atual
	var neighbors = graph_manager.graph.get_neighbors(current_marker)
	if neighbors.is_empty():
		# Se não há vizinhos, tentar voltar para um marcador visitado anteriormente
		_backtrack_to_visited()
		return
	
	# Filtrar vizinhos não visitados (prioridade para novos marcadores)
	var unvisited_neighbors = []
	for neighbor in neighbors:
		if neighbor not in visited_markers:
			unvisited_neighbors.append(neighbor)
	
	var target_marker: String = ""
	
	# Se há vizinhos não visitados, escolher um aleatório
	if unvisited_neighbors.size() > 0:
		var random_index = randi() % unvisited_neighbors.size()
		target_marker = unvisited_neighbors[random_index]
		visited_markers.append(target_marker)  # Marcar como visitado
		print("Inimigo: Movendo para novo marcador ", target_marker, " (DFS - exploração)")
	else:
		# Se todos os vizinhos foram visitados, escolher um aleatório para voltar
		var random_index = randi() % neighbors.size()
		target_marker = neighbors[random_index]
		print("Inimigo: Movendo para marcador visitado ", target_marker, " (DFS - backtrack)")
	
	# Mover para o marcador escolhido
	if marker_nodes.has(target_marker):
		var target_pos = marker_nodes[target_marker]
		# Cancelar tween anterior se existir
		if current_tween and current_tween.is_valid():
			current_tween.kill()
		
		current_tween = create_tween()
		var distance = global_position.distance_to(target_pos)
		var duration = clamp(distance / speed, 0.3, 2.0)  # Duração baseada na distância
		
		current_tween.tween_property(self, "global_position", target_pos, duration)
		current_tween.set_trans(Tween.TRANS_SINE)
		current_tween.set_ease(Tween.EASE_IN_OUT)
		current_tween.finished.connect(func(): _on_movement_complete(target_marker))

func _backtrack_to_visited():
	"""Volta para um marcador visitado anteriormente quando não há vizinhos novos"""
	if visited_markers.size() <= 1:
		return  # Não há para onde voltar
	
	# Escolher um marcador visitado aleatório (exceto o atual)
	var available_markers = []
	for marker in visited_markers:
		if marker != current_marker:
			available_markers.append(marker)
	
	if available_markers.is_empty():
		return
	
	var random_index = randi() % available_markers.size()
	var target_marker = available_markers[random_index]
	
	if marker_nodes.has(target_marker):
		var target_pos = marker_nodes[target_marker]
		if current_tween and current_tween.is_valid():
			current_tween.kill()
		
		current_tween = create_tween()
		var distance = global_position.distance_to(target_pos)
		var duration = clamp(distance / speed, 0.3, 2.0)
		
		current_tween.tween_property(self, "global_position", target_pos, duration)
		current_tween.set_trans(Tween.TRANS_SINE)
		current_tween.set_ease(Tween.EASE_IN_OUT)
		current_tween.finished.connect(func(): _on_movement_complete(target_marker))
		
		print("Inimigo: Voltando para marcador visitado ", target_marker)

func _physics_process(delta):
	"""Verifica continuamente a proximidade do player"""
	_check_player_proximity()

func _on_movement_complete(marker_name: String):
	"""Callback quando o movimento é completado"""
	# Se chegou em um marcador intermediário, continuar até o destino final
	if _is_intermediate_marker(marker_name):
		# Obter vizinhos do marcador intermediário
		var neighbors = graph_manager.graph.get_neighbors(marker_name)
		# Encontrar o próximo marcador numérico (não intermediário)
		for neighbor in neighbors:
			if not _is_intermediate_marker(neighbor) and neighbor != current_marker:
				# Continuar movimento até o marcador numérico
				_move_to_marker(neighbor)
				return
		
		# Se não encontrou destino numérico, procurar através de outros intermediários
		for neighbor in neighbors:
			if _is_intermediate_marker(neighbor) and neighbor != current_marker:
				var final = _get_final_destination(marker_name, neighbor)
				if final != "":
					_move_through_intermediate(marker_name, neighbor, final)
					return
	
	# Se chegou em um marcador numérico, atualizar posição
	current_marker = marker_name
	
	# Se está perseguindo, continuar perseguindo até chegar no player
	if is_chasing:
		_chase_player()
	else:
		# Se não está perseguindo, continuar com DFS aleatório
		_move_to_random_neighbor()

func _check_player_proximity():
	"""Verifica se o player está a até 2 marcadores de distância e ativa modo perseguição"""
	if not player or not graph_manager or not graph_manager.graph:
		is_chasing = false
		return
	
	# Obter marcador atual do player
	var player_marker = ""
	if "current_marker" in player:
		player_marker = player.current_marker
	
	if player_marker == "":
		is_chasing = false
		return
	
	# Verificar se o player está a até 2 marcadores de distância
	var player_is_nearby = _is_player_within_range(player_marker, 2)
	
	if player_is_nearby and not is_chasing:
		# Ativar modo perseguição
		is_chasing = true
		speed = base_speed * 0.5  # Reduzir velocidade em 50% durante perseguição
		print("🔍 MODO PERSEGUIÇÃO ATIVADO! Player detectado em ", player_marker, " (alcance: 2 marcadores)")
		print("   Velocidade reduzida para: ", speed, " (50% da velocidade base)")
		_chase_player()
	elif not player_is_nearby and is_chasing:
		# Desativar modo perseguição
		is_chasing = false
		speed = base_speed  # Restaurar velocidade original
		print("🔍 MODO PERSEGUIÇÃO DESATIVADO. Voltando para DFS")
		print("   Velocidade restaurada para: ", speed)
	elif is_chasing:
		# Continuar perseguindo
		_chase_player()

func _is_player_within_range(player_marker: String, max_distance: int) -> bool:
	"""Verifica se o player está dentro do alcance especificado (em número de marcadores)"""
	if player_marker == current_marker:
		return true  # Mesmo marcador
	
	if max_distance <= 0:
		return false
	
	# Usar BFS para verificar distância
	var distance = _get_marker_distance(current_marker, player_marker)
	return distance <= max_distance

func _get_marker_distance(start: String, goal: String) -> int:
	"""Retorna a distância (em número de marcadores) entre dois marcadores usando BFS"""
	if start == goal:
		return 0
	
	var queue = [[start]]  # Fila de caminhos
	var visited = {start: true}  # Marcadores visitados
	
	while not queue.is_empty():
		var current_path = queue.pop_front()
		var current_node = current_path[current_path.size() - 1]
		var current_distance = current_path.size() - 1  # Distância atual
		
		# Obter vizinhos do nó atual
		var neighbors = graph_manager.graph.get_neighbors(current_node)
		
		for neighbor in neighbors:
			if neighbor == goal:
				# Encontrou o destino! Retornar distância
				return current_distance + 1
			
			# Se não foi visitado, adicionar à fila
			if not visited.has(neighbor):
				visited[neighbor] = true
				var new_path = current_path.duplicate()
				new_path.append(neighbor)
				queue.append(new_path)
	
	# Não encontrou caminho (retornar distância muito grande)
	return 999

func _chase_player():
	"""Usa BFS para encontrar e seguir o caminho mais curto até o player"""
	if not player or not graph_manager or not graph_manager.graph:
		return
	
	# Se já está se movendo, não iniciar novo movimento
	if current_tween and current_tween.is_valid():
		return
	
	# Obter marcador atual do player
	var player_marker = ""
	if "current_marker" in player:
		player_marker = player.current_marker
	
	if player_marker == "":
		return  # Player não está em um marcador válido
	
	# Se já está no mesmo marcador do player, não precisa mover
	# O dano será causado pela verificação de colisão no player
	if player_marker == current_marker:
		return
	
	# Usar BFS para encontrar o caminho mais curto
	var path = _bfs_find_path(current_marker, player_marker)
	
	if path.is_empty():
		# Se não encontrou caminho, voltar para DFS
		is_chasing = false
		_move_to_random_neighbor()
		return
	
	# Mover para o próximo marcador no caminho (primeiro após o atual)
	if path.size() > 1:
		var next_marker = path[1]  # Próximo marcador no caminho
		
		# Verificar se o próximo marcador é intermediário e precisa passar por ele
		var final_marker = _get_final_destination(current_marker, next_marker)
		if final_marker != "":
			# Há um marcador intermediário, mover através dele
			_move_through_intermediate(current_marker, next_marker, final_marker)
		else:
			# Movimento direto
			_move_to_marker(next_marker)
	else:
		# Já está no destino
		is_chasing = false

func _bfs_find_path(start: String, goal: String) -> Array:
	"""Implementa BFS (Busca em Largura) para encontrar o caminho mais curto"""
	if start == goal:
		return [start]
	
	var queue = [[start]]  # Fila de caminhos
	var visited = {start: true}  # Marcadores visitados
	
	while not queue.is_empty():
		var current_path = queue.pop_front()
		var current_node = current_path[current_path.size() - 1]
		
		# Obter vizinhos do nó atual
		var neighbors = graph_manager.graph.get_neighbors(current_node)
		
		for neighbor in neighbors:
			if neighbor == goal:
				# Encontrou o destino! Retornar caminho completo
				var final_path = current_path.duplicate()
				final_path.append(neighbor)
				return final_path
			
			# Se não foi visitado, adicionar à fila
			if not visited.has(neighbor):
				visited[neighbor] = true
				var new_path = current_path.duplicate()
				new_path.append(neighbor)
				queue.append(new_path)
	
	# Não encontrou caminho
	return []

func _move_to_marker(marker_name: String):
	"""Move o inimigo para um marcador específico"""
	if not marker_nodes.has(marker_name):
		return
	
	var target_pos = marker_nodes[marker_name]
	
	# Cancelar tween anterior se existir
	if current_tween and current_tween.is_valid():
		current_tween.kill()
	
	current_tween = create_tween()
	var distance = global_position.distance_to(target_pos)
	var duration = clamp(distance / speed, 0.3, 2.0)
	
	current_tween.tween_property(self, "global_position", target_pos, duration)
	current_tween.set_trans(Tween.TRANS_SINE)
	current_tween.set_ease(Tween.EASE_IN_OUT)
	current_tween.finished.connect(func(): _on_movement_complete(marker_name))
	
	if is_chasing:
		print("Inimigo: Perseguindo para ", marker_name)

func _is_intermediate_marker(marker_name: String) -> bool:
	"""Verifica se um marcador é intermediário (termina com 'a' ou 'b')"""
	return marker_name.ends_with("a") or marker_name.ends_with("b")

func _get_final_destination(from_marker: String, intermediate_marker: String) -> String:
	"""Retorna o destino final se o marcador intermediário for um ponto de passagem"""
	# Verificar se o marcador é intermediário (termina com "a" ou "b")
	if not _is_intermediate_marker(intermediate_marker):
		return ""
	
	# Obter todos os vizinhos do marcador intermediário
	var neighbors = graph_manager.graph.get_neighbors(intermediate_marker)
	if neighbors.is_empty():
		return ""
	
	# Encontrar o vizinho que NÃO é o marcador de origem (será o destino final)
	for neighbor in neighbors:
		if neighbor != from_marker and not _is_intermediate_marker(neighbor):
			# Encontrou um marcador numérico que não é o de origem
			return neighbor
	
	# Se não encontrou um marcador numérico, verificar se há outro intermediário
	# e continuar procurando o destino final
	for neighbor in neighbors:
		if neighbor != from_marker and _is_intermediate_marker(neighbor):
			# Recursivamente procurar o destino final através de múltiplos intermediários
			var final = _get_final_destination(intermediate_marker, neighbor)
			if final != "":
				return final
	
	return ""

func _move_through_intermediate(from_marker: String, intermediate_marker: String, final_marker: String):
	"""Move o inimigo direto para o destino final passando pelo marcador intermediário"""
	if not marker_nodes.has(intermediate_marker) or not marker_nodes.has(final_marker):
		print("Erro: Marcadores intermediário ou final não encontrados")
		return
	
	# Cancelar qualquer movimento em andamento
	if current_tween and current_tween.is_valid():
		current_tween.kill()
	
	var start_pos = global_position
	var intermediate_pos = marker_nodes[intermediate_marker]
	var final_pos = marker_nodes[final_marker]
	
	# Calcular distâncias
	var dist_to_intermediate = start_pos.distance_to(intermediate_pos)
	var dist_from_intermediate_to_final = intermediate_pos.distance_to(final_pos)
	var total_distance = dist_to_intermediate + dist_from_intermediate_to_final
	
	# Duração total baseada na distância total
	var duration = clamp(total_distance / speed, 0.2, 3.5)
	
	# Criar tween que passa pelos dois pontos em sequência
	current_tween = create_tween()
	current_tween.set_parallel(false)
	
	# Primeiro movimento: do início até o intermediário (proporcional)
	var duration_first = (dist_to_intermediate / total_distance) * duration
	# Segundo movimento: do intermediário até o final (resto da duração)
	var duration_second = duration - duration_first
	
	# Ajustar durações mínimas
	if duration_first < 0.1:
		duration_first = 0.1
		duration_second = duration - duration_first
	if duration_second < 0.1:
		duration_second = 0.1
		duration_first = duration - duration_second
	
	# Primeiro movimento até o intermediário
	current_tween.tween_property(self, "global_position", intermediate_pos, duration_first)
	current_tween.set_trans(Tween.TRANS_CUBIC)
	current_tween.set_ease(Tween.EASE_IN_OUT)
	
	# Segundo movimento do intermediário até o final
	current_tween.tween_property(self, "global_position", final_pos, duration_second)
	current_tween.set_trans(Tween.TRANS_CUBIC)
	current_tween.set_ease(Tween.EASE_IN_OUT)
	
	# Callback quando completar
	current_tween.finished.connect(func(): _on_movement_complete(final_marker))
	
	if is_chasing:
		print("Inimigo: Perseguindo através de ", intermediate_marker, " até ", final_marker)

func reset_to_start():
	"""Reseta o inimigo para um marcador aleatório (exceto Marker0)"""
	# Cancelar qualquer movimento em andamento
	if current_tween and current_tween.is_valid():
		current_tween.kill()
		current_tween = null
	
	# Resetar modo perseguição e velocidade
	is_chasing = false
	speed = base_speed  # Restaurar velocidade base
	
	# Escolher um marcador aleatório para respawn (exceto Marker0)
	var spawn_marker = _get_random_spawn_marker()
	if marker_nodes.has(spawn_marker):
		global_position = marker_nodes[spawn_marker]
		current_marker = spawn_marker
		visited_markers = [spawn_marker]  # Resetar lista de visitados
		print("Inimigo respawnado em: ", spawn_marker)
	else:
		# Fallback para Marker1 se o marcador aleatório não existir
		var fallback = marker_nodes.get("Marker1", marker_nodes["Marker0"])
		global_position = fallback
		current_marker = "Marker1" if marker_nodes.has("Marker1") else "Marker0"
		visited_markers = [current_marker]
	
	# Reiniciar movimento aleatório
	_move_to_random_neighbor()

func _get_random_spawn_marker() -> String:
	"""Retorna um marcador baseado em probabilidades específicas"""
	# Definir probabilidades de spawn para cada marcador
	var spawn_chances = {
		"Marker17": 0.50,  # 50%
		"Marker45": 0.10,  # 10%
		"Marker3": 0.05,   # 5%
		"Marker37": 0.50,  # 50%
		"Marker13": 0.40,  # 40%
		"Marker21": 0.60,  # 60%
		"Marker25": 0.60,  # 60%
		"Marker24": 0.70   # 70%
	}
	
	# Verificar quais marcadores existem no mapa
	var valid_markers = []
	var valid_chances = []
	
	for marker_name in spawn_chances.keys():
		if marker_nodes.has(marker_name):
			valid_markers.append(marker_name)
			valid_chances.append(spawn_chances[marker_name])
	
	# Se não houver marcadores válidos, usar fallback
	if valid_markers.is_empty():
		return "Marker1"
	
	# Calcular probabilidade total (pode ser maior que 1.0 devido a múltiplas chances)
	var total_chance = 0.0
	for chance in valid_chances:
		total_chance += chance
	
	# Gerar número aleatório entre 0 e total_chance
	var random_value = randf() * total_chance
	
	# Escolher marcador baseado na probabilidade acumulada
	var accumulated = 0.0
	for i in range(valid_markers.size()):
		accumulated += valid_chances[i]
		if random_value <= accumulated:
			return valid_markers[i]
	
	# Fallback: retornar o último marcador se algo der errado
	return valid_markers[valid_markers.size() - 1]
