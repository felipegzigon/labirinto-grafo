extends CharacterBody2D

# Velocidade do jogador (pixels por segundo) - aumentada em 30%
@export var movement_speed := 260.0

# Referências
var graph_manager: GraphManager
var marker_nodes: Dictionary = {}
var waypoints_parent: Node2D
var enemy: CharacterBody2D = null  # Referência ao inimigo
# Sistema de névoa removido

# Sistema de posição atual
var current_marker: String = ""  # Marcador atual onde o jogador está
var is_moving: bool = false  # Flag para impedir interrupção do movimento
var movement_tween: Tween = null

# Sistema de vida
@export var max_health := 2  # Vida máxima (2 colisões = game over)
var current_health: int = 2  # Vida atual
var can_take_damage: bool = true  # Flag para evitar múltiplas colisões no mesmo frame
var damage_cooldown: float = 0.0  # Cooldown entre danos (em segundos)

# Direções
enum Direction {UP, DOWN, LEFT, RIGHT}

func _enter_tree():
	# Garantir que a posição seja resetada quando entrar na árvore
	# Isso evita que a posição do game.tscn seja usada
	pass

func _ready():
	# Aguardar próximo frame para garantir que toda a árvore está pronta
	await get_tree().process_frame
	
	# Buscar referências
	graph_manager = get_node("../GraphManager")
	if graph_manager:
		waypoints_parent = graph_manager.waypoints_parent
		_load_marker_positions()
	
	# Buscar referência ao inimigo
	enemy = get_node("../Enemy")
	
	# Posicionar no marcador inicial - IMPORTANTE: fazer isso após carregar as posições
	_position_at_marker0()
	
	# Inicializar vida
	current_health = max_health
	can_take_damage = true
	damage_cooldown = 0.0
	print("Vida inicial: ", current_health)

func _position_at_marker0():
	"""Posiciona o jogador no Marker0"""
	if not marker_nodes.has("Marker0"):
		print("ERRO: Marker0 não encontrado!")
		return
	
	current_marker = "Marker0"
	var marker0_pos = marker_nodes["Marker0"]
	
	# Definir a posição global diretamente
	global_position = marker0_pos
	
	# Usar call_deferred para garantir que sobrescreva qualquer posição inicial
	call_deferred("set", "global_position", marker0_pos)
	
	# Garantir novamente após mais um frame (caso algo sobrescreva)
	await get_tree().process_frame
	global_position = marker0_pos
	
	print("=== JOGADOR INICIADO ===")
	print("Posição inicial: ", current_marker)
	print("Posição global do Marker0: ", marker0_pos)
	print("Posição global do Player após ajuste: ", global_position)
	
	# Verificar se está na posição correta
	var distance = global_position.distance_to(marker0_pos)
	if distance > 1.0:
		print("AVISO: Jogador não está exatamente no Marker0! Distância: ", distance)
		# Forçar posição novamente
		global_position = marker0_pos
	
	_print_available_neighbors()

func _load_marker_positions():
	"""Carrega as posições de todos os marcadores"""
	if waypoints_parent:
		for marker in waypoints_parent.get_children():
			if marker is Marker2D:
				# Usar global_position para considerar o offset do parent Waypoints
				marker_nodes[marker.name] = marker.global_position
				print("Carregado marcador: ", marker.name, " em ", marker.global_position)

func _input(event):
	# Só processar input se não estiver se movendo
	if is_moving:
		return
	
	# Verificar teclas de direção
	if Input.is_action_just_pressed("ui_right"):
		_try_move_in_direction(Direction.RIGHT)
	elif Input.is_action_just_pressed("ui_left"):
		_try_move_in_direction(Direction.LEFT)
	elif Input.is_action_just_pressed("ui_up"):
		_try_move_in_direction(Direction.UP)
	elif Input.is_action_just_pressed("ui_down"):
		_try_move_in_direction(Direction.DOWN)

func _try_move_in_direction(direction: Direction):
	"""Tenta mover o jogador na direção especificada se houver uma aresta"""
	if current_marker == "" or not graph_manager or not graph_manager.graph:
		return
	
	# Obter vizinhos do marcador atual
	var neighbors = graph_manager.graph.get_neighbors(current_marker)
	if neighbors.is_empty():
		print("Nenhum vizinho disponível em ", current_marker)
		return
	
	# Encontrar o marcador vizinho que está na direção solicitada
	var target_marker = _find_marker_in_direction(current_marker, neighbors, direction)
	
	if target_marker != "":
		# Verificar se este marcador é intermediário (5a ou 6a) e se há um destino final
		var final_marker = _get_final_destination(current_marker, target_marker)
		
		if final_marker != "":
			# Mover direto para o destino final passando pelo intermediário
			print("→ Movendo de ", current_marker, " direto para ", final_marker, " passando por ", target_marker, " (direção: ", _direction_to_string(direction), ")")
			_move_through_intermediate(current_marker, target_marker, final_marker)
		else:
			# Movimento normal para um marcador que não é intermediário
			print("→ Movendo de ", current_marker, " para ", target_marker, " (direção: ", _direction_to_string(direction), ")")
			_move_to_marker(target_marker)
	else:
		print("✗ Não há aresta na direção ", _direction_to_string(direction), " a partir de ", current_marker)
		print("  (Marcador atual: ", current_marker, " tem vizinhos: ", neighbors, ")")

func _direction_to_string(direction: Direction) -> String:
	"""Converte uma direção para string"""
	match direction:
		Direction.UP:
			return "UP"
		Direction.DOWN:
			return "DOWN"
		Direction.LEFT:
			return "LEFT"
		Direction.RIGHT:
			return "RIGHT"
		_:
			return "UNKNOWN"

func _find_marker_in_direction(from_marker: String, neighbors: Array, direction: Direction) -> String:
	"""Encontra qual marcador vizinho está na direção especificada"""
	if not marker_nodes.has(from_marker):
		return ""
	
	var current_pos = marker_nodes[from_marker]
	var best_marker = ""
	var best_angle_diff = INF
	
	# Calcular ângulo da direção desejada (em radianos)
	var desired_angle: float
	match direction:
		Direction.RIGHT:
			desired_angle = 0.0  # 0 graus (leste)
		Direction.LEFT:
			desired_angle = PI  # 180 graus (oeste)
		Direction.UP:
			desired_angle = -PI / 2.0  # -90 graus (norte)
		Direction.DOWN:
			desired_angle = PI / 2.0  # 90 graus (sul)
	
	# Verificar cada vizinho e encontrar o que está mais próximo da direção desejada
	for neighbor_name in neighbors:
		if not marker_nodes.has(neighbor_name):
			continue
		
		var neighbor_pos = marker_nodes[neighbor_name]
		var direction_vector = (neighbor_pos - current_pos).normalized()
		var neighbor_angle = atan2(direction_vector.y, direction_vector.x)
		
		# Calcular diferença de ângulo (considerando wraparound -360 a 360)
		var angle_diff = abs(neighbor_angle - desired_angle)
		# Normalizar para o intervalo [0, PI]
		while angle_diff > PI:
			angle_diff = 2 * PI - angle_diff
		
		# Se este vizinho está mais próximo da direção desejada
		if angle_diff < best_angle_diff:
			# Verificar se está realmente naquela direção (tolerância de ~60 graus para curvas)
			# Aumentada para capturar melhor os marcadores intermediários em curvas
			if angle_diff <= PI / 3.0:  # ~60 graus
				best_angle_diff = angle_diff
				best_marker = neighbor_name
	
	return best_marker

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

func _is_intermediate_marker(marker_name: String) -> bool:
	"""Verifica se um marcador é intermediário (termina com 'a' ou 'b')"""
	return marker_name.ends_with("a") or marker_name.ends_with("b")

func _move_through_intermediate(from_marker: String, intermediate_marker: String, final_marker: String):
	"""Move o jogador direto para o destino final passando pelo marcador intermediário"""
	if not marker_nodes.has(intermediate_marker) or not marker_nodes.has(final_marker):
		print("Erro: Marcadores intermediário ou final não encontrados")
		return
	
	if is_moving:
		print("Já está se movendo, ignorando movimento")
		return
	
	is_moving = true
	var start_pos = global_position
	var intermediate_pos = marker_nodes[intermediate_marker]
	var final_pos = marker_nodes[final_marker]
	
	# Calcular distâncias
	var dist_to_intermediate = start_pos.distance_to(intermediate_pos)
	var dist_from_intermediate_to_final = intermediate_pos.distance_to(final_pos)
	var total_distance = dist_to_intermediate + dist_from_intermediate_to_final
	
	# Duração total baseada na distância total
	var duration = clamp(total_distance / movement_speed, 0.2, 3.5)
	
	# Cancelar qualquer tween anterior
	if movement_tween:
		movement_tween.kill()
		movement_tween = null
	
	# Criar tween que passa pelos dois pontos em sequência
	movement_tween = create_tween()
	movement_tween.set_parallel(false)
	
	# Primeiro movimento: do início até o intermediário (metade da duração ou proporcional)
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
	movement_tween.tween_property(self, "global_position", intermediate_pos, duration_first)
	movement_tween.set_trans(Tween.TRANS_CUBIC)
	movement_tween.set_ease(Tween.EASE_IN_OUT)
	
	# Segundo movimento do intermediário até o final
	movement_tween.tween_property(self, "global_position", final_pos, duration_second)
	movement_tween.set_trans(Tween.TRANS_CUBIC)
	movement_tween.set_ease(Tween.EASE_IN_OUT)
	
	# Callback quando completar
	movement_tween.finished.connect(func(): _on_movement_complete(final_marker))
	
	print("  Movimento através de ", intermediate_marker, " até ", final_marker)
	print("  Distância total: ", total_distance, " | Duração: ", duration, "s")

func _move_to_marker(marker_name: String):
	"""Move o jogador para o marcador especificado com animação suave"""
	if not marker_nodes.has(marker_name):
		print("Marcador não encontrado: ", marker_name)
		return
	
	if is_moving:
		print("Já está se movendo, ignorando movimento para ", marker_name)
		return
	
	is_moving = true
	var target_pos = marker_nodes[marker_name]
	
	# IMPORTANTE: Sempre usar a posição atual real do jogador como ponto de partida
	# Isso garante movimento suave contínuo, mesmo em curvas
	var start_pos = global_position
	
	# Se não estivermos em um marcador válido ou estivermos muito longe, 
	# ajustar para garantir movimento fluido
	if current_marker == "" or not marker_nodes.has(current_marker):
		# Se não temos marcador atual válido, usar a posição atual
		pass
	else:
		# Verificar se há uma grande discrepância (> 5 pixels)
		var expected_pos = marker_nodes[current_marker]
		var distance_from_marker = start_pos.distance_to(expected_pos)
		if distance_from_marker > 5.0:
			# Se estamos longe do marcador atual, mas vamos nos mover,
			# continuar da posição atual para evitar pulo
			print("AVISO: Jogador em ", start_pos, " mas marcador atual esperado em ", expected_pos)
	
	var distance = start_pos.distance_to(target_pos)
	
	# Garantir duração mínima para movimentos muito curtos (evita movimentos instantâneos)
	# E máxima para movimentos muito longos (evita movimentos muito lentos)
	var duration = clamp(distance / movement_speed, 0.15, 3.0)
	
	# Cancelar qualquer tween anterior para evitar conflitos
	if movement_tween:
		movement_tween.kill()
		movement_tween = null
	
	# Criar novo tween para animação suave e contínua
	movement_tween = create_tween()
	
	# Configurar o tween para seguir a propriedade global_position suavemente
	# TRANS_CUBIC cria uma curva suave que é ideal para movimentos em trajetórias curvas
	movement_tween.set_parallel(false)  # Garantir que seja sequencial
	movement_tween.tween_property(self, "global_position", target_pos, duration)
	movement_tween.set_trans(Tween.TRANS_CUBIC)  # Curva mais suave para trajetórias curvas
	movement_tween.set_ease(Tween.EASE_IN_OUT)   # Acelera no início e desacelera no fim
	
	# Atualização de névoa removida
	
	# Conectar callback quando o movimento completar
	movement_tween.finished.connect(func(): _on_movement_complete(marker_name))
	
	print("  Distância: ", distance, " | Duração: ", duration, "s | De ", start_pos, " para ", target_pos)

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
				print("→ Continuando de ", marker_name, " para ", neighbor, " (marcador intermediário)")
				_move_to_marker(neighbor)
				return
		
		# Se não encontrou destino numérico, procurar através de outros intermediários
		for neighbor in neighbors:
			if _is_intermediate_marker(neighbor) and neighbor != current_marker:
				var final = _get_final_destination(marker_name, neighbor)
				if final != "":
					_move_through_intermediate(marker_name, neighbor, final)
					return
	
	# Se chegou em um marcador numérico, parar aqui
	current_marker = marker_name
	is_moving = false
	movement_tween = null
	
	# Garantir que está exatamente na posição do marcador
	if marker_nodes.has(marker_name):
		var final_pos = marker_nodes[marker_name]
		global_position = final_pos
		print("✓ Chegou em: ", current_marker, " (posição: ", final_pos, ")")
	else:
		print("✓ Chegou em: ", current_marker)
	
	# Verificar se chegou no Marker28 (vitória)
	if marker_name == "Marker28":
		_show_win_screen()
		return
	
	_print_available_neighbors()

# Funções de névoa removidas

func _print_available_neighbors():
	"""Imprime os vizinhos disponíveis do marcador atual"""
	if current_marker == "" or not graph_manager or not graph_manager.graph:
		return
	
	var neighbors = graph_manager.graph.get_neighbors(current_marker)
	if neighbors.is_empty():
		print("  → Nenhum vizinho disponível (fim do caminho)")
	else:
		print("  → Vizinhos disponíveis: ", neighbors)

func _take_damage():
	"""Reduz a vida do player quando colidir com o inimigo"""
	if current_health <= 0:
		return  # Já está morto
	
	if not can_take_damage:
		return  # Ainda está em cooldown
	
	# Ativar cooldown para evitar múltiplas colisões
	can_take_damage = false
	damage_cooldown = 1.0  # 1 segundo de cooldown entre danos
	
	# Reduzir vida
	current_health -= 1
	print("⚠️ COLISÃO COM INIMIGO! Vida restante: ", current_health, "/", max_health)
	
	# Respawnar o inimigo
	_respawn_enemy_at_start()
	
	# Verificar se o player morreu
	if current_health <= 0:
		_game_over()

func _respawn_enemy_at_start():
	"""Respawna o inimigo em um marcador aleatório (exceto Marker0) quando colidir com o player"""
	if not enemy:
		return
	
	# Resetar o estado do inimigo (reiniciar o caminho) - isso já escolhe um marcador aleatório
	if enemy.has_method("reset_to_start"):
		enemy.reset_to_start()

func _game_over():
	"""Exibe tela de game over, pausa o jogo e reinicia após 2 segundos"""
	print("💀 GAME OVER! Vida esgotada. Pausando jogo...")
	
	# Pausar o jogo
	get_tree().paused = true
	
	# Criar tela de game over simples
	_show_game_over_screen()
	
	# Aguardar 2 segundos (usar timer que funciona mesmo com jogo pausado)
	var timer = Timer.new()
	timer.wait_time = 2.0
	timer.one_shot = true
	timer.process_mode = Node.PROCESS_MODE_ALWAYS  # Processar mesmo com jogo pausado
	get_tree().root.add_child(timer)
	timer.timeout.connect(_restart_game)
	timer.start()
	
	print("Jogo pausado. Reiniciando em 2 segundos...")

func _restart_game():
	"""Remove o overlay de game over, despausa o jogo e reinicia a cena"""
	print("Reiniciando jogo...")
	
	# Remover o overlay de game over
	_remove_game_over_screen()
	
	# Despausar o jogo antes de reiniciar
	get_tree().paused = false
	
	# Reiniciar a cena atual
	get_tree().reload_current_scene()

func _remove_game_over_screen():
	"""Remove a tela de game over do jogo"""
	var game_over_layer = get_tree().root.get_node_or_null("GameOverLayer")
	if game_over_layer:
		game_over_layer.queue_free()
		print("Overlay de game over removido")

func _show_win_screen():
	"""Exibe tela de vitória e pausa o jogo"""
	print("🎉 VITÓRIA! Chegou no Marker28!")
	
	# Pausar o jogo
	get_tree().paused = true
	
	# Criar CanvasLayer para a tela de vitória
	var win_layer = CanvasLayer.new()
	win_layer.name = "WinLayer"
	get_tree().root.add_child(win_layer)
	
	# Criar fundo escuro
	var background = ColorRect.new()
	background.color = Color(0, 0, 0, 0.8)  # Preto semi-transparente
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.set_offsets_preset(Control.PRESET_FULL_RECT)
	win_layer.add_child(background)
	
	# Criar container central para organizar elementos
	var container = VBoxContainer.new()
	container.set_anchors_preset(Control.PRESET_CENTER)
	container.add_theme_constant_override("separation", 30)
	win_layer.add_child(container)
	
	# Criar label de Vitória
	var label = Label.new()
	label.text = "VITÓRIA!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 72)
	label.add_theme_color_override("font_color", Color(0, 1, 0))  # Verde
	container.add_child(label)
	
	# Criar label de mensagem
	var message_label = Label.new()
	message_label.text = "Você fugiu do esqueleto molestador!"
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 32)
	message_label.add_theme_color_override("font_color", Color(1, 1, 1))  # Branco
	container.add_child(message_label)
	
	# Criar botão de recomeçar
	var restart_button = Button.new()
	restart_button.text = "Recomeçar"
	restart_button.add_theme_font_size_override("font_size", 36)
	restart_button.custom_minimum_size = Vector2(200, 60)
	restart_button.pressed.connect(_restart_from_win)
	container.add_child(restart_button)

func _restart_from_win():
	"""Remove a tela de vitória, despausa e reinicia o jogo"""
	print("Reiniciando jogo após vitória...")
	
	# Remover tela de vitória
	var win_layer = get_tree().root.get_node_or_null("WinLayer")
	if win_layer:
		win_layer.queue_free()
	
	# Despausar o jogo antes de reiniciar
	get_tree().paused = false
	
	# Reiniciar a cena atual
	get_tree().reload_current_scene()

func _show_game_over_screen():
	"""Cria e exibe uma tela de game over simples"""
	# Criar CanvasLayer para a tela de game over
	var game_over_layer = CanvasLayer.new()
	game_over_layer.name = "GameOverLayer"
	get_tree().root.add_child(game_over_layer)
	
	# Criar fundo escuro
	var background = ColorRect.new()
	background.color = Color(0, 0, 0, 0.8)  # Preto semi-transparente
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.set_offsets_preset(Control.PRESET_FULL_RECT)
	game_over_layer.add_child(background)
	
	# Criar label de Game Over
	var label = Label.new()
	label.text = "GAME OVER"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 72)
	label.add_theme_color_override("font_color", Color(1, 0, 0))  # Vermelho
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.set_offsets_preset(Control.PRESET_FULL_RECT)
	game_over_layer.add_child(label)
	
	# Criar label de "Reiniciando..."
	var restart_label = Label.new()
	restart_label.text = "Reiniciando em 2 segundos..."
	restart_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	restart_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	restart_label.add_theme_font_size_override("font_size", 24)
	restart_label.add_theme_color_override("font_color", Color(1, 1, 1))  # Branco
	restart_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	restart_label.position.y += 100  # Deslocar para baixo
	game_over_layer.add_child(restart_label)

func _physics_process(delta):
	# Garantir que o movimento do tween seja processado suavemente
	# O tween já atualiza global_position automaticamente, mas podemos
	# garantir que nenhum movimento físico interfira no movimento via tween
	if is_moving:
		# Quando está se movendo via tween, garantir que não haja velocidade física
		# que possa causar conflito ou pulos
		velocity = Vector2.ZERO
	else:
		# Quando não está se movendo, também garantir que não há velocidade residual
		velocity = Vector2.ZERO
	
	# Atualizar cooldown de dano
	if damage_cooldown > 0.0:
		damage_cooldown -= delta
		if damage_cooldown <= 0.0:
			can_take_damage = true
	
	# Verificar colisão com o inimigo
	_check_enemy_collision()

func _check_enemy_collision():
	"""Verifica se o player colidiu com o inimigo e respawna se necessário"""
	if not enemy:
		return
	
	# Se não pode tomar dano (cooldown ativo), ignorar
	if not can_take_damage:
		return
	
	# Calcular distância entre player e inimigo
	var distance = global_position.distance_to(enemy.global_position)
	
	# Distância de colisão (ajustar conforme necessário, baseado no tamanho dos sprites)
	var collision_distance = 30.0  # pixels
	
	if distance < collision_distance:
		# Colisão detectada! Reduzir vida e respawnar inimigo
		_take_damage()
	
# Atualização de névoa removida
