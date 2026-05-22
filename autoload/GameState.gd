extends Node

# ============================================================
# シグナル
# ============================================================
signal game_started
signal turn_started(player_idx: int)
signal tile_drawn(player_idx: int)
signal tile_discarded(player_idx: int, tile: Dictionary)
signal tsumo_declared(player_idx: int, result: Dictionary)
signal ron_opportunity(winner_idx: int, loser_idx: int, tile: Dictionary)
signal pon_opportunity(player_idx: int, from_idx: int, tile: Dictionary)
signal riichi_declared(player_idx: int)
signal kita_removed(player_idx: int)
signal ankan_done(player_idx: int)
signal minkan_done(player_idx: int)
signal kakan_done(player_idx: int)
signal naki_done(player_idx: int)
signal game_ended(result: Dictionary)    # 局終了（和了 / 流局）
signal match_ended(session: Dictionary)  # 試合終了 → 精算画面へ
signal wall_count_changed(count: int)
signal npc_thinking(player_idx: int)

# ============================================================
# フェーズ
# ============================================================
enum Phase {
	IDLE,
	PLAYER_TURN,
	NPC_TURN,
	ACTION_WAIT,
	AFTER_PON,
	GAME_OVER,
}

# ============================================================
# 定数
# ============================================================
const INITIAL_SCORE := 35000
const SETTLEMENT_BASE := 40000  # 精算の基準点（開始点数35000とは別）
const NPC_THINK_SEC := 0.8

# ============================================================
# マッチレベル状態
# ============================================================
var player_chips: Array = [0, 0, 0]  # チップ収支（現試合）
var session_result: Dictionary = {}   # 精算結果（Result画面用）
var _pending_match_end: bool = false
var match_kyoku_count: int = 0
var match_player_agari: int = 0
var match_player_houjuu: int = 0
var match_player_agari_jun: int = 0
var match_player_agari_han: int = 0
var match_player_agari_chip: int = 0
var action_minkan_possible: bool = false  # 大明槓の選択肢があるか
var _pending_kakan_player: int = -1       # チャンカン待ちの加槓プレイヤー
var _kakan_tile: Dictionary = {}          # チャンカン判定用の加槓牌
var _pending_ankan_player: int = -1
var _ankan_tile: Dictionary = {}
var _pending_kita_player: int = -1
var _kita_tile: Dictionary = {}
var _drew_from_rinshan: bool = false      # 嶺上ツモかどうか（役・点数計算用）
var _is_chankan_ron: bool = false         # 槍槓ロン中かどうか（_finalize_ronでis_chankan=trueにするため）
var _suukantsu_pending: int = -1         # 四槓子成立待ち（4つ目槓後の捨て牌でロンなければ成立）
var _pending_npc_ron_after_skip: int = -1 # プレイヤーがロンを見逃した場合の次順位NPCロン候補

# ============================================================
# 局レベル状態
# ============================================================
var players: Array = []
var wall: Array = []
var rinshan: Array = []
var dora_indicators: Array = []
var ura_dora_indicators: Array = []

var current_player: int = 0
var dealer: int = 0
var round_wind: int = 0
var kyoku: int = 1
var honba: int = 0
var kyotaku: int = 0

var phase: int = Phase.IDLE
var last_discarded_tile: Dictionary = {}
var last_discard_player: int = -1
var junme: int = 0
var kyoku_has_meld: bool = false   # 局開始後に誰かがポン/カンしたか（地和判定用）
var action_winner_idx: int = -1
var action_is_ron: bool = false
var action_pon_from: int = -1

# ============================================================
# プレイヤーデータ生成
# ============================================================
func _make_player(p_name: String, is_npc: bool, wind: int) -> Dictionary:
	return {
		"name": p_name, "is_npc": is_npc, "wind": wind,
		"score": INITIAL_SCORE,
		"hand": [], "discards": [], "naki": [], "nukita": [],
		"is_riichi": false, "is_daburi": false, "is_ippatsu": false,
		"is_menzen": true,
		"riichi_discard_idx": -1,
		"riichi_waiting_ids": [],
		"pon_forbidden_id": -1,
		"is_riichi_furiten": false,
		"is_doujun_furiten": false,
	}

# ============================================================
# マッチ開始 / 局開始
# ============================================================
func start_match() -> void:
	player_chips = [0, 0, 0]
	match_kyoku_count = 0
	match_player_agari = 0
	match_player_houjuu = 0
	match_player_agari_jun = 0
	match_player_agari_han = 0
	match_player_agari_chip = 0
	_pending_match_end = false
	session_result = {}
	kyotaku = 0
	# プレイヤー初期化
	players = []
	round_wind = MahjongLogic.EAST
	kyoku = 1
	honba = 0
	dealer = 0
	# SaveDataのプレイヤー名とNPC選択を使う
	var npc_ids: Array = SaveData.selected_npc
	players.append(_make_player(SaveData.player_name, false, MahjongLogic.EAST))
	players.append(_make_player(npc_ids[0].to_upper().replace("_", ""), true, MahjongLogic.SOUTH))
	players.append(_make_player(npc_ids[1].to_upper().replace("_", ""), true, MahjongLogic.WEST))
	_start_kyoku()

# 後方互換エイリアス
func start_game() -> void:
	start_match()

func _start_kyoku() -> void:
	for p: Dictionary in players:
		p.hand = []
		p.discards = []
		p.naki = []
		p.nukita = []
		p.is_riichi = false
		p.is_daburi = false
		p.is_ippatsu = false
		p.is_menzen = true
		p.riichi_discard_idx = -1
		p.riichi_waiting_ids = []
		p.pon_forbidden_id = -1
		p.is_riichi_furiten = false
		p.is_doujun_furiten = false
	_setup_wall()
	_deal_hands()
	phase = Phase.IDLE
	junme = 0
	kyoku_has_meld = false
	last_discarded_tile = {}
	last_discard_player = -1
	action_winner_idx = -1
	action_is_ron = false
	action_pon_from = -1
	action_minkan_possible = false
	_pending_kakan_player = -1
	_pending_ankan_player = -1
	_pending_kita_player = -1
	_kakan_tile = {}
	_ankan_tile = {}
	_kita_tile = {}
	_drew_from_rinshan = false
	_is_chankan_ron = false
	_suukantsu_pending = -1
	_pending_npc_ron_after_skip = -1
	emit_signal("game_started")
	_start_turn(dealer)

# 局結果確認後に呼び出し（ゲーム.gd から）
func advance_game() -> void:
	if _pending_match_end:
		_compute_session_result()
		emit_signal("match_ended", session_result)
	else:
		_start_kyoku()

# ============================================================
# 壁・配牌
# ============================================================
func _setup_wall() -> void:
	var deck: Array = MahjongLogic.create_deck()
	deck.shuffle()
	rinshan             = deck.slice(deck.size() - 8)
	deck                = deck.slice(0, deck.size() - 8)
	dora_indicators     = [deck[0]]
	ura_dora_indicators = [deck[1]]
	wall                = deck.slice(2)

func _deal_hands() -> void:
	for p: Dictionary in players:
		p.hand = []
		for _i in range(13):
			p.hand.append(wall.pop_front())

# ============================================================
# ターン管理
# ============================================================
func _start_turn(player_idx: int) -> void:
	current_player = player_idx
	if wall.is_empty():
		_end_round_draw()
		return

	var drawn: Dictionary = wall.pop_front()
	players[player_idx].hand.append(drawn)
	players[player_idx].is_doujun_furiten = false
	_drew_from_rinshan = false  # 通常ツモなので嶺上フラグをリセット

	emit_signal("tile_drawn", player_idx)
	emit_signal("wall_count_changed", wall.size())

	# 白ポッチ強制和了（リーチ中のプレイヤーがツモった時のみ発動）
	if drawn.get("is_haku_pochi", false) and players[player_idx].is_riichi:
		_process_haku_pochi_tsumo(player_idx)
		return

	if players[player_idx].is_npc:
		phase = Phase.NPC_TURN
		emit_signal("npc_thinking", player_idx)
		emit_signal("turn_started", player_idx)
		get_tree().create_timer(NPC_THINK_SEC).timeout.connect(
			func(): _npc_turn(player_idx), CONNECT_ONE_SHOT)
	else:
		junme += 1
		phase = Phase.PLAYER_TURN
		emit_signal("turn_started", player_idx)

# ============================================================
# NPC AI
# ============================================================
func _npc_turn(player_idx: int) -> void:
	if current_player != player_idx: return
	var p: Dictionary = players[player_idx]
	var hand_ids: Array = MahjongLogic.get_ids(p.hand)

	# ツモ和了チェック
	if MahjongLogic.is_complete_hand(hand_ids):
		var winning_id: int = p.hand[p.hand.size() - 1].id
		var context: Dictionary = _build_context(player_idx, true, winning_id)
		var yaku: Array = MahjongLogic.check_yaku(hand_ids, context)
		if not yaku.is_empty():
			var result: Dictionary = _build_win_result(player_idx, true, -1, yaku)
			_apply_score(result)
			emit_signal("tsumo_declared", player_idx, result)
			_process_kyoku_end(result)
			return

	# 北抜き（門前でなくても可能）
	if _has_kita(p):
		_do_kita(player_idx)
		if phase == Phase.ACTION_WAIT:
			return
		# 嶺上ツモ後の和了チェック
		var kita_hand_ids: Array = MahjongLogic.get_ids(p.hand)
		if MahjongLogic.is_complete_hand(kita_hand_ids):
			var kita_win_id: int = p.hand[p.hand.size() - 1].id
			var kita_ctx: Dictionary = _build_context(player_idx, true, kita_win_id)
			var kita_yaku: Array = MahjongLogic.check_yaku(kita_hand_ids, kita_ctx)
			if not kita_yaku.is_empty():
				var kita_result: Dictionary = _build_win_result(player_idx, true, -1, kita_yaku)
				_apply_score(kita_result)
				emit_signal("tsumo_declared", player_idx, kita_result)
				_process_kyoku_end(kita_result)
				return
		get_tree().create_timer(NPC_THINK_SEC).timeout.connect(
			func(): _npc_turn(player_idx), CONNECT_ONE_SHOT)
		return

	# 暗槓チェック（ツモった牌で4枚揃ったら槓）
	if _npc_can_ankan(player_idx):
		_do_ankan(player_idx)
		return

	# 加槓チェック（ツモった牌が既存のポンに追加できるなら槓）
	if _npc_can_kakan(player_idx):
		_do_kakan(player_idx)
		return

	# リーチ判定（点数1000点以上のとき）
	if p.is_menzen and not p.is_riichi and p.score >= 1000:
		var riichi_idx: Array = MahjongLogic.get_riichi_discards(p.hand)
		if not riichi_idx.is_empty():
			var discard_i: int = riichi_idx[0]
			_do_riichi_discard(player_idx, discard_i)
			return

	_do_discard_internal(player_idx, p.hand.size() - 1)

func _has_kita(p: Dictionary) -> bool:
	var hand: Array = p.hand
	for t: Dictionary in hand:
		if t.id == MahjongLogic.NORTH: return true
	return false

# ============================================================
# プレイヤーアクション
# ============================================================
func player_discard(hand_idx: int) -> void:
	if phase != Phase.PLAYER_TURN and phase != Phase.AFTER_PON: return
	if hand_idx < 0 or hand_idx >= players[0].hand.size(): return
	if players[0].hand[hand_idx].id == MahjongLogic.NORTH: return
	# 食い変え禁止チェック（ポン直後に同種の牌は切れない）
	if players[0].pon_forbidden_id >= 0 and \
			players[0].hand[hand_idx].id == players[0].pon_forbidden_id: return
	_do_discard_internal(0, hand_idx)

func player_tsumo() -> void:
	if phase != Phase.PLAYER_TURN: return
	var hand_ids: Array = MahjongLogic.get_ids(players[0].hand)
	if not MahjongLogic.is_complete_hand(hand_ids): return
	var winning_id: int = players[0].hand[players[0].hand.size() - 1].id
	var context: Dictionary = _build_context(0, true, winning_id)
	var yaku: Array = MahjongLogic.check_yaku(hand_ids, context)
	if yaku.is_empty(): return
	var result: Dictionary = _build_win_result(0, true, -1, yaku)
	_apply_score(result)
	emit_signal("tsumo_declared", 0, result)
	_process_kyoku_end(result)

func player_riichi(hand_idx: int) -> void:
	if phase != Phase.PLAYER_TURN: return
	if not players[0].is_menzen: return
	if players[0].score < 1000: return
	# 北（花牌）はリーチ宣言牌にできない
	if hand_idx >= 0 and hand_idx < players[0].hand.size() and \
			players[0].hand[hand_idx].id == MahjongLogic.NORTH: return
	_do_riichi_discard(0, hand_idx)

func player_ron() -> void:
	if phase != Phase.ACTION_WAIT or not action_is_ron: return
	_finalize_ron(0, last_discard_player)

func player_pon(selected_hand_idx: int = -1) -> void:
	if phase != Phase.ACTION_WAIT or action_pon_from < 0: return
	_do_pon(0, action_pon_from, last_discarded_tile, selected_hand_idx)

func player_kita() -> void:
	if phase != Phase.PLAYER_TURN and phase != Phase.AFTER_PON: return
	_do_kita(0)

func player_ankan(kan_id_override: int = -1) -> void:
	if phase != Phase.PLAYER_TURN: return
	_do_ankan(0, kan_id_override)

func player_minkan(selected_hand_idx: int = -1) -> void:
	# 大明槓：他家の捨て牌を取って槓子を作る
	if phase != Phase.ACTION_WAIT or not action_minkan_possible: return
	if action_pon_from < 0: return
	_do_minkan(0, action_pon_from, last_discarded_tile, selected_hand_idx)

func player_kakan(kan_id_override: int = -1) -> void:
	# 加槓：手牌の牌を既存ポンに加えて槓子にする
	if phase != Phase.PLAYER_TURN: return
	_do_kakan(0, kan_id_override)

func player_skip() -> void:
	if phase != Phase.ACTION_WAIT: return
	# ロン機会を見逃した → 同順フリテン。リーチ中なら永続フリテンも確定
	if action_is_ron:
		players[0].is_doujun_furiten = true
		if players[0].is_riichi:
			players[0].is_riichi_furiten = true
		if _pending_npc_ron_after_skip >= 0:
			var npc_winner: int = _pending_npc_ron_after_skip
			_pending_npc_ron_after_skip = -1
			_finalize_ron(npc_winner, last_discard_player)
			return
	# チャンカン見逃し → 加槓を継続する
	if _pending_kakan_player >= 0:
		var kakan_p: int = _pending_kakan_player
		_pending_kakan_player = -1
		_is_chankan_ron = false
		_finish_kakan(kakan_p)
		return
	if _pending_ankan_player >= 0:
		var ankan_p: int = _pending_ankan_player
		_pending_ankan_player = -1
		_is_chankan_ron = false
		_finish_ankan(ankan_p)
		return
	if _pending_kita_player >= 0:
		var kita_p: int = _pending_kita_player
		_pending_kita_player = -1
		_is_chankan_ron = false
		_finish_kita(kita_p, true)
		return
	action_minkan_possible = false
	_next_turn(last_discard_player)

# ============================================================
# 内部処理
# ============================================================
func _do_riichi_discard(player_idx: int, hand_idx: int) -> void:
	var p: Dictionary = players[player_idx]
	var is_daburi: bool = (junme <= 1 and p.hand.size() == 14)
	var riichi_hand_ids: Array = MahjongLogic.get_ids(p.hand)
	riichi_hand_ids.remove_at(hand_idx)
	p.riichi_waiting_ids = MahjongLogic.find_waiting_tiles(riichi_hand_ids)
	p.riichi_waiting_ids.sort()
	p.is_riichi  = true
	p.is_daburi  = is_daburi
	p.riichi_discard_idx = p.discards.size()
	p.score -= 1000
	kyotaku += 1
	p.hand[hand_idx]["is_riichi_tile"] = true
	emit_signal("riichi_declared", player_idx)
	_do_discard_internal(player_idx, hand_idx)
	# is_ippatsu は _do_discard_internal の後にセットする
	# （_do_discard_internal 内で is_ippatsu = false されるため、後に上書きが必要）
	players[player_idx].is_ippatsu = true
	players[player_idx].discards[players[player_idx].riichi_discard_idx]["is_riichi_tile"] = true

func _do_discard_internal(player_idx: int, hand_idx: int) -> void:
	var tile: Dictionary = players[player_idx].hand[hand_idx]
	players[player_idx].hand.remove_at(hand_idx)
	players[player_idx].discards.append(tile)
	players[player_idx].is_ippatsu = false
	players[player_idx].pon_forbidden_id = -1  # 捨て牌後に食い変え禁止をリセット
	last_discarded_tile = tile
	last_discard_player = player_idx
	emit_signal("tile_discarded", player_idx, tile)
	_check_actions_after_discard(player_idx, tile)

func _do_kita(player_idx: int) -> void:
	var p: Dictionary = players[player_idx]
	var removed_tile: Dictionary = {}
	for i in range(p.hand.size() - 1, -1, -1):
		var t: Dictionary = p.hand[i]
		if t.id == MahjongLogic.NORTH:
			removed_tile = t
			p.hand.remove_at(i)
			p.nukita.append(t)
			break
	if removed_tile.is_empty():
		return
	_kita_tile = removed_tile
	emit_signal("kita_removed", player_idx)
	if _check_kita_ron_opportunity(player_idx, removed_tile):
		return
	_finish_kita(player_idx)

func _finish_kita(player_idx: int, resume_npc: bool = false) -> void:
	var p: Dictionary = players[player_idx]
	if not rinshan.is_empty():
		var new_tile: Dictionary = rinshan.pop_back()
		p.hand.append(new_tile)
	_drew_from_rinshan = true
	emit_signal("tile_drawn", player_idx)
	if resume_npc and players[player_idx].is_npc:
		phase = Phase.NPC_TURN
		get_tree().create_timer(NPC_THINK_SEC).timeout.connect(
			func(): _npc_turn(player_idx), CONNECT_ONE_SHOT)

func _do_ankan(player_idx: int, kan_id_override: int = -1) -> void:
	# 暗槓も全員の一発を消滅させる・地和も無効化
	var p: Dictionary = players[player_idx]
	if p.hand.is_empty() or not _can_start_kan(): return
	# プレイヤーは手牌全体から4枚揃いを探す。NPCはツモ牌（末尾）で判定
	var kan_id: int
	if player_idx == 0:
		kan_id = kan_id_override if kan_id_override >= 0 else _find_player_ankan_id()
		if kan_id < 0: return
	else:
		kan_id = p.hand[p.hand.size() - 1].id
	if _count_tile_in_hand(p.hand, kan_id) < 4:
		return
	if not _can_riichi_ankan(player_idx, kan_id):
		return
	kyoku_has_meld = true
	for pp: Dictionary in players:
		pp.is_ippatsu = false
	var kan_tiles: Array = []
	for i in range(p.hand.size() - 1, -1, -1):
		if p.hand[i].id == kan_id:
			kan_tiles.append(p.hand[i])
			p.hand.remove_at(i)
	p.naki.append({"type": "ankan", "tile_ids": [kan_id, kan_id, kan_id, kan_id], "tiles": kan_tiles})
	_ankan_tile = MahjongLogic.make_tile(kan_id)
	if player_idx != 0:
		if _check_ankan_chankan_opportunity(player_idx, kan_id):
			return
	else:
		if _check_npc_ankan_chankan_opportunity(kan_id):
			return
	if wall.size() >= 2 and dora_indicators.size() < 5:
		dora_indicators.append(wall.pop_front())
		ura_dora_indicators.append(wall.pop_front())
		emit_signal("wall_count_changed", wall.size())
	if not rinshan.is_empty():
		p.hand.append(rinshan.pop_back())
	_drew_from_rinshan = true  # 嶺上ツモフラグ
	if MahjongLogic._count_kantsu(p.naki) >= 4:
		_suukantsu_pending = player_idx
	emit_signal("ankan_done", player_idx)
	emit_signal("tile_drawn", player_idx)
	# NPCは嶺上ツモ後に自動でターンを継続する
	if players[player_idx].is_npc:
		get_tree().create_timer(NPC_THINK_SEC).timeout.connect(
			func(): _npc_turn(player_idx), CONNECT_ONE_SHOT)

func _finish_ankan(player_idx: int) -> void:
	var p: Dictionary = players[player_idx]
	if wall.size() >= 2 and dora_indicators.size() < 5:
		dora_indicators.append(wall.pop_front())
		ura_dora_indicators.append(wall.pop_front())
		emit_signal("wall_count_changed", wall.size())
	if not rinshan.is_empty():
		p.hand.append(rinshan.pop_back())
	_drew_from_rinshan = true
	if MahjongLogic._count_kantsu(p.naki) >= 4:
		_suukantsu_pending = player_idx
	emit_signal("ankan_done", player_idx)
	emit_signal("tile_drawn", player_idx)
	if players[player_idx].is_npc:
		get_tree().create_timer(NPC_THINK_SEC).timeout.connect(
			func(): _npc_turn(player_idx), CONNECT_ONE_SHOT)

func _is_kokushi_chankan_win(winner_idx: int, tile_id: int) -> bool:
	var p: Dictionary = players[winner_idx]
	var hand_ids: Array = MahjongLogic.get_ids(p.hand)
	if tile_id not in MahjongLogic.find_waiting_tiles(hand_ids):
		return false
	var test_hand: Array = hand_ids.duplicate()
	test_hand.append(tile_id)
	test_hand.sort()
	return MahjongLogic._check_kokushi(test_hand)

func _check_ankan_chankan_opportunity(ankan_player_idx: int, tile_id: int) -> bool:
	if ankan_player_idx == 0:
		return false
	if _is_player_furiten(0):
		return false
	if not _is_kokushi_chankan_win(0, tile_id):
		return false
	last_discarded_tile = _ankan_tile
	last_discard_player = ankan_player_idx
	action_winner_idx = 0
	action_is_ron = true
	action_pon_from = -1
	action_minkan_possible = false
	_pending_ankan_player = ankan_player_idx
	_is_chankan_ron = true
	phase = Phase.ACTION_WAIT
	emit_signal("ron_opportunity", 0, ankan_player_idx, _ankan_tile)
	return true

func _check_npc_ankan_chankan_opportunity(tile_id: int) -> bool:
	for i in range(1, players.size()):
		var np: Dictionary = players[i]
		if MahjongLogic.is_furiten(MahjongLogic.get_ids(np.hand), MahjongLogic.get_ids(np.discards)):
			continue
		if not _is_kokushi_chankan_win(i, tile_id):
			continue
		np.hand.append(_ankan_tile)
		var ctx: Dictionary = _build_context(i, false, tile_id)
		ctx["is_chankan"] = true
		var yaku: Array = MahjongLogic.check_yaku(MahjongLogic.get_ids(np.hand), ctx)
		var result: Dictionary = _build_win_result(i, false, 0, yaku)
		np.hand.pop_back()
		_apply_score(result)
		_process_kyoku_end(result)
		return true
	return false

func _is_kita_ron_furiten(winner_idx: int) -> bool:
	return players[winner_idx].nukita.size() > 0

func _can_ron_on_kita(winner_idx: int, tile: Dictionary) -> bool:
	if tile.id != MahjongLogic.NORTH:
		return false
	if _is_kita_ron_furiten(winner_idx):
		return false
	if winner_idx == 0 and _is_player_furiten(0):
		return false
	if winner_idx != 0 and MahjongLogic.is_furiten(
			MahjongLogic.get_ids(players[winner_idx].hand),
			MahjongLogic.get_ids(players[winner_idx].discards)):
		return false
	var hand_ids: Array = MahjongLogic.get_ids(players[winner_idx].hand)
	if tile.id not in MahjongLogic.find_waiting_tiles(hand_ids):
		return false
	var test_hand: Array = hand_ids.duplicate()
	test_hand.append(tile.id)
	test_hand.sort()
	var open_melds: Array = players[winner_idx].naki
	return MahjongLogic._check_kokushi(test_hand) \
			or MahjongLogic._check_tsuiso(test_hand, open_melds) \
			or MahjongLogic._check_shousuushii(test_hand, open_melds) \
			or MahjongLogic._check_daisuushii(test_hand, open_melds)

func _check_kita_ron_opportunity(kita_player_idx: int, tile: Dictionary) -> bool:
	var ron_candidates: Array = []
	for step in range(1, players.size()):
		var candidate_idx: int = (kita_player_idx + step) % players.size()
		if candidate_idx == kita_player_idx:
			continue
		if _can_ron_on_kita(candidate_idx, tile):
			ron_candidates.append(candidate_idx)
	if ron_candidates.is_empty():
		return false

	last_discarded_tile = tile
	last_discard_player = kita_player_idx
	action_winner_idx = ron_candidates[0]
	action_is_ron = true
	action_pon_from = -1
	action_minkan_possible = false
	_pending_kita_player = kita_player_idx
	_is_chankan_ron = false
	phase = Phase.ACTION_WAIT

	if action_winner_idx == 0:
		_pending_npc_ron_after_skip = -1
		for idx: int in ron_candidates:
			if idx != 0:
				_pending_npc_ron_after_skip = idx
				break
		emit_signal("ron_opportunity", 0, kita_player_idx, tile)
	else:
		_pending_kita_player = -1
		_finalize_ron(action_winner_idx, kita_player_idx)
	return true

func _do_pon(player_idx: int, from_idx: int, tile: Dictionary, selected_hand_idx: int = -1) -> void:
	# ポン・カンは全員の一発を消滅させる・地和も無効化
	kyoku_has_meld = true
	for pp: Dictionary in players:
		pp.is_ippatsu = false
	var p: Dictionary = players[player_idx]
	# 手牌から実際の牌辞書を取り出す（金牌などの属性を保持するため）
	var removed_tiles: Array = []
	if selected_hand_idx >= 0 and selected_hand_idx < p.hand.size() and p.hand[selected_hand_idx].id == tile.id:
		removed_tiles.append(p.hand[selected_hand_idx])
		p.hand.remove_at(selected_hand_idx)
	for i in range(p.hand.size() - 1, -1, -1):
		if p.hand[i].id == tile.id and removed_tiles.size() < 2:
			removed_tiles.append(p.hand[i])
			p.hand.remove_at(i)
	if removed_tiles.size() < 2:
		return
	var meld_tiles: Array = [tile] + removed_tiles
	p.naki.append({"type": "pon", "tile_ids": [tile.id, tile.id, tile.id],
				   "tiles": meld_tiles, "from_player": from_idx})
	p.is_menzen = false
	p.pon_forbidden_id = tile.id  # 食い変え禁止: ポン直後に同種牌は切れない
	# ポンされた捨て牌にフラグを立てる（河に残るが黒マスクで覆う）
	if not players[from_idx].discards.is_empty():
		players[from_idx].discards[-1]["is_taken"] = true
	action_minkan_possible = false
	emit_signal("naki_done", player_idx)
	if player_idx == 0:
		phase = Phase.AFTER_PON
		emit_signal("turn_started", player_idx)
	else:
		get_tree().create_timer(NPC_THINK_SEC * 0.5).timeout.connect(
			func(): _npc_pon_discard(player_idx), CONNECT_ONE_SHOT)

func _npc_pon_discard(player_idx: int) -> void:
	var p: Dictionary = players[player_idx]
	if p.hand.is_empty(): return
	_do_discard_internal(player_idx, p.hand.size() - 1)

# ============================================================
# 捨て後のアクションチェック
# ============================================================
func _check_actions_after_discard(discarder_idx: int, tile: Dictionary) -> void:
	var player_can_ron: bool = false
	if discarder_idx != 0:
		var p: Dictionary = players[0]
		var hand_ids: Array = MahjongLogic.get_ids(p.hand)
		var waiting: Array = MahjongLogic.find_waiting_tiles(hand_ids)
		if tile.id in waiting:
			# フリテンでなければロン可否を判定
			if not _is_player_furiten(0) and (not p.is_riichi or _is_riichi_valid_win(0, tile)):
				var test_hand: Array = hand_ids.duplicate()
				test_hand.append(tile.id)
				test_hand.sort()
				var ctx: Dictionary = _build_context(0, false, tile.id)
				var yaku: Array = MahjongLogic.check_yaku(test_hand, ctx)
				if not yaku.is_empty():
					player_can_ron = true
			# 当たり牌が出たがロンできない（フリテン or 役なし）→ 同順フリテン
			if not player_can_ron:
				players[0].is_doujun_furiten = true

	var ron_candidates: Array = []
	for step in range(1, players.size()):
		var candidate_idx: int = (discarder_idx + step) % players.size()
		if candidate_idx == discarder_idx:
			continue
		if candidate_idx == 0:
			if player_can_ron:
				ron_candidates.append(candidate_idx)
		elif _npc_can_ron(candidate_idx, tile):
			ron_candidates.append(candidate_idx)
	if not ron_candidates.is_empty():
		var winner_idx: int = ron_candidates[0]  # 頭ハネ: 捨てた人から次順に近い和了者を優先
		if winner_idx == 0:
			_pending_npc_ron_after_skip = -1
			for idx: int in ron_candidates:
				if idx != 0:
					_pending_npc_ron_after_skip = idx
					break
			action_winner_idx = 0
			action_is_ron = true
			action_pon_from = -1
			action_minkan_possible = false
			phase = Phase.ACTION_WAIT
			emit_signal("ron_opportunity", 0, discarder_idx, tile)
		else:
			_finalize_ron(winner_idx, discarder_idx)
		return

	var player_can_pon: bool = false
	var player_can_minkan: bool = false
	if discarder_idx != 0 and not players[0].is_riichi:
		var cnt: int = 0
		for t: Dictionary in players[0].hand:
			if t.id == tile.id: cnt += 1
		if cnt >= 2: player_can_pon = true
		if cnt >= 3 and _can_start_kan(): player_can_minkan = true  # 3枚持ちなら大明槓も可

	for i in range(1, players.size()):
		if i == discarder_idx: continue
		var np: Dictionary = players[i]
		if np.is_riichi: continue
		# 大明槓（3枚持ちの役牌）はポンより優先
		if _npc_wants_kan(i, tile):
			get_tree().create_timer(NPC_THINK_SEC * 0.3).timeout.connect(
				func(): _do_minkan(i, discarder_idx, tile), CONNECT_ONE_SHOT)
			return
		if _npc_wants_pon(i, tile):
			get_tree().create_timer(NPC_THINK_SEC * 0.3).timeout.connect(
				func(): _do_pon(i, discarder_idx, tile), CONNECT_ONE_SHOT)
			return

	if player_can_pon or player_can_minkan:
		action_winner_idx = 0
		action_is_ron         = false
		action_pon_from       = discarder_idx
		action_minkan_possible = player_can_minkan
		phase = Phase.ACTION_WAIT
		emit_signal("pon_opportunity", 0, discarder_idx, tile)
		return

	_next_turn(discarder_idx)

func _npc_can_ron(npc_idx: int, tile: Dictionary) -> bool:
	var p: Dictionary = players[npc_idx]
	var hand_ids: Array = MahjongLogic.get_ids(p.hand)
	if tile.id not in MahjongLogic.find_waiting_tiles(hand_ids):
		return false
	if MahjongLogic.is_furiten(hand_ids, MahjongLogic.get_ids(p.discards)):
		return false
	var test_hand: Array = hand_ids.duplicate()
	test_hand.append(tile.id)
	test_hand.sort()
	var ctx: Dictionary = _build_context(npc_idx, false, tile.id)
	var yaku: Array = MahjongLogic.check_yaku(test_hand, ctx)
	return not yaku.is_empty()

func _npc_wants_pon(npc_idx: int, tile: Dictionary) -> bool:
	var p: Dictionary = players[npc_idx]
	var cnt: int = 0
	for t: Dictionary in p.hand:
		if t.id == tile.id: cnt += 1
	if cnt < 2: return false
	if not MahjongLogic.is_honor(tile.id): return false
	if tile.id in [MahjongLogic.HAKU, MahjongLogic.HATSU, MahjongLogic.CHUN]: return true
	if tile.id == round_wind: return true
	if tile.id == p.wind: return true
	return false

func _is_riichi_valid_win(_player_idx: int, _tile: Dictionary) -> bool:
	return true

# ============================================================
# 白ポッチ強制和了処理
# ============================================================
func _process_haku_pochi_tsumo(player_idx: int) -> void:
	var p: Dictionary = players[player_idx]
	# 末尾の白ポッチを除いた13枚の待ち牌を列挙
	var pochi_idx: int = p.hand.size() - 1
	var hand_ids_13: Array = MahjongLogic.get_ids(p.hand.slice(0, pochi_idx))
	var waiting: Array = MahjongLogic.find_waiting_tiles(hand_ids_13)
	if waiting.is_empty():
		return  # テンパイでない（リーチ後なので通常ありえない）
	# 高目どりで最良の待ち牌を選択
	var best_id: int = _find_best_waiting_tile(player_idx, hand_ids_13, waiting)
	# 白ポッチを best_id の牌に差し替えて役・点数計算
	p.hand[pochi_idx] = MahjongLogic.make_tile(best_id)
	var hand_ids_14: Array = MahjongLogic.get_ids(p.hand)
	hand_ids_14.sort()
	var ctx: Dictionary = _build_context(player_idx, true, best_id)
	var yaku: Array = MahjongLogic.check_yaku(hand_ids_14, ctx)
	var result: Dictionary = _build_win_result(player_idx, true, -1, yaku)
	result["haku_pochi_best_tile"] = best_id
	# 計算後は手牌表示用に白ポッチへ戻す
	p.hand[pochi_idx] = MahjongLogic.make_tile(45, false, false, true)
	_apply_score(result)
	emit_signal("tsumo_declared", player_idx, result)
	_process_kyoku_end(result)

func _find_best_waiting_tile(player_idx: int, hand_ids_13: Array, waiting_ids: Array) -> int:
	var best_id: int = waiting_ids[0]
	var best_han: int = -1
	var best_chips: int = -1
	var p: Dictionary = players[player_idx]
	for tid: int in waiting_ids:
		var test_hand: Array = hand_ids_13.duplicate()
		test_hand.append(tid)
		test_hand.sort()
		var ctx: Dictionary = _build_context(player_idx, true, tid)
		var yaku: Array = MahjongLogic.check_yaku(test_hand, ctx)
		var han: int = MahjongLogic.count_han(yaku)
		var is_yakuman: bool = han >= 13
		# 待ち牌自体がドラ・裏ドラかどうかを飜数に加算（比較用）
		for di: int in range(dora_indicators.size()):
			if tid == MahjongLogic.get_dora_from_indicator(dora_indicators[di].id):
				han += 1
		var ura: int = 0
		if p.is_riichi:
			for di: int in range(ura_dora_indicators.size()):
				if tid == MahjongLogic.get_dora_from_indicator(ura_dora_indicators[di].id):
					han += 1
					ura += 1
		# チップ比較（手牌固定分は全候補共通なので変動分のみ比較）
		var chips: int = ura + (1 if p.is_ippatsu else 0) + (5 if is_yakuman else 0)
		if best_han < 0 or _is_higher_tile(tid, han, chips, best_id, best_han, best_chips):
			best_id = tid
			best_han = han
			best_chips = chips
	return best_id

func _is_higher_tile(tid: int, han: int, chips: int, best_id: int, best_han: int, best_chips: int) -> bool:
	if han != best_han: return han > best_han
	if chips != best_chips: return chips > best_chips
	# 牌種優先（字牌=4 > 萬子=3 > 筒子=2 > 索子=1）
	var suit_tid: int = _tile_suit_priority(tid)
	var suit_best: int = _tile_suit_priority(best_id)
	if suit_tid != suit_best: return suit_tid > suit_best
	# 字牌同士: IDが小さい方が優先（東=41 > 南=42 > 西=43 > 北=44 > 白=45 > 發=46 > 中=47）
	if suit_tid == 4: return tid < best_id
	# 数牌同士: IDが大きい方が優先（9 > 8 > ... > 1）
	return tid > best_id

func _tile_suit_priority(id: int) -> int:
	if id >= 41: return 4  # 字牌
	if id == 11 or id == 19: return 3  # 萬子
	if id >= 21 and id <= 29: return 2  # 筒子
	return 1  # 索子

# ============================================================
# フリテン判定（①捨て牌 ②リーチ後見逃し ③同順 の3種を統合）
# ============================================================
func _is_player_furiten(player_idx: int) -> bool:
	var p: Dictionary = players[player_idx]
	# ② リーチ後見逃しフリテン（永続）
	if p.is_riichi_furiten: return true
	# ③ 同順フリテン（一時的）
	if p.is_doujun_furiten: return true
	# ① 捨て牌フリテン（自分の河に当たり牌が含まれる）
	var hand_ids: Array = MahjongLogic.get_ids(p.hand)
	return MahjongLogic.is_furiten(hand_ids, MahjongLogic.get_ids(p.discards))

func _finalize_ron(winner_idx: int, loser_idx: int) -> void:
	_pending_npc_ron_after_skip = -1
	_pending_ankan_player = -1
	_pending_kita_player = -1
	var winner: Dictionary = players[winner_idx]
	winner.hand.append(last_discarded_tile)
	var hand_ids: Array = MahjongLogic.get_ids(winner.hand)
	if not MahjongLogic.is_complete_hand(hand_ids):
		winner.hand.pop_back()
		_next_turn(loser_idx)
		return
	var context: Dictionary = _build_context(winner_idx, false, last_discarded_tile.id)
	if _is_chankan_ron:
		context["is_chankan"] = true
	_is_chankan_ron = false
	var yaku: Array = MahjongLogic.check_yaku(hand_ids, context)
	if yaku.is_empty():
		winner.hand.pop_back()
		_pending_kakan_player = -1
		_pending_ankan_player = -1
		_pending_kita_player = -1
		_next_turn(loser_idx)
		return
	var result: Dictionary = _build_win_result(winner_idx, false, loser_idx, yaku)
	winner.hand.pop_back()  # ロン牌を手牌に残さない
	_pending_kakan_player = -1
	_pending_ankan_player = -1
	_pending_kita_player = -1
	_apply_score(result)
	_process_kyoku_end(result)

func _next_turn(current_idx: int) -> void:
	# 四槓子: 4つ目カン後の捨て牌でロンがなかった場合に成立
	if _suukantsu_pending >= 0 and _suukantsu_pending == current_idx:
		_suukantsu_pending = -1
		var skz_result := _build_win_result(current_idx, true, -1, [{"name": "四槓子", "han": 13}])
		_apply_score(skz_result)
		emit_signal("tsumo_declared", current_idx, skz_result)
		_process_kyoku_end(skz_result)
		return
	_suukantsu_pending = -1
	var next_idx: int = (current_idx + 1) % players.size()
	_start_turn(next_idx)

# ============================================================
# 勝利コンテキスト
# ============================================================
func _build_context(player_idx: int, is_tsumo: bool, winning_tile_id: int = -1) -> Dictionary:
	var p: Dictionary = players[player_idx]
	return {
		"round_wind":      round_wind,
		"player_wind":     p.wind,
		"is_tsumo":        is_tsumo,
		"is_riichi":       p.is_riichi,
		"is_daburi":       p.is_daburi,
		"is_ippatsu":      p.is_ippatsu,
		"is_rinshan":      is_tsumo and _drew_from_rinshan,
		"is_chankan":      false,
		"is_haitei":       is_tsumo and wall.is_empty(),
		"is_houtei":       (not is_tsumo) and wall.is_empty(),
		"is_tenhou":       player_idx == dealer and junme == 1 and is_tsumo and p.naki.is_empty() and not p.is_riichi,
		"is_chiihou":      player_idx != dealer and junme == 1 and is_tsumo and not kyoku_has_meld,
		"is_renhou":       false,
		"is_nagashi":      false,
		"open_melds":      p.naki,
		"winning_tile_id": winning_tile_id,
	}

# ============================================================
# 点数計算
# ============================================================
func _build_win_result(winner_idx: int, is_tsumo: bool, loser_idx: int, yaku: Array) -> Dictionary:
	var winner: Dictionary = players[winner_idx]
	var is_parent: bool = (winner_idx == dealer)
	# 役満チェックはドラ加算前の役ハンで行う
	var is_yakuman: bool = MahjongLogic.count_han(yaku) >= 13
	var han: int = MahjongLogic.count_han(yaku)
	var ura_count: int = 0

	var hand: Array = winner.hand

	# 通常ドラ・裏ドラ（指示牌ベース）
	var regular_dora: int = 0
	for di: int in range(dora_indicators.size()):
		var dora_id: int = MahjongLogic.get_dora_from_indicator(dora_indicators[di].id)
		var ura_id: int = -1
		if winner.is_riichi and di < ura_dora_indicators.size():
			ura_id = MahjongLogic.get_dora_from_indicator(ura_dora_indicators[di].id)
		for t: Dictionary in hand:
			if t.id == dora_id:
				han += 1; regular_dora += 1
			if ura_id >= 0 and t.id == ura_id:
				han += 1; ura_count += 1
		for m: Dictionary in winner.naki:
			for tid: int in m.get("tile_ids", []):
				if tid == dora_id:
					han += 1; regular_dora += 1

	# 赤ドラ（常にドラ扱い）
	var red_count: int = 0
	for t: Dictionary in hand:
		if t.get("is_red", false): han += 1; red_count += 1
	for m: Dictionary in winner.naki:
		for t in m.get("tiles", []):
			if t is Dictionary and t.get("is_red", false): han += 1; red_count += 1

	# 金ドラ（常に1飜、チップ2枚）
	var gold_count: int = 0
	for t: Dictionary in hand:
		if t.get("is_gold", false): han += 1; gold_count += 1
	for m: Dictionary in winner.naki:
		for t in m.get("tiles", []):
			if t is Dictionary and t.get("is_gold", false): han += 1; gold_count += 1

	# 北抜き（1枚=1飜、赤北はチップ+1のみ）
	var kita_count: int = winner.nukita.size()
	var kita_red: int = 0
	for nt: Dictionary in winner.nukita:
		han += 1
		if nt.get("is_red", false): kita_red += 1

	# 役リストにドラ・赤・金・北を追加（表示用）
	if regular_dora > 0:
		yaku.append({"name": "ドラ", "han": regular_dora})
	if ura_count > 0:
		yaku.append({"name": "裏ドラ", "han": ura_count})
	if red_count > 0:
		yaku.append({"name": "赤ドラ", "han": red_count})
	if gold_count > 0:
		yaku.append({"name": "金ドラ", "han": gold_count})
	if kita_count > 0:
		yaku.append({"name": "北×" + str(kita_count), "han": kita_count})

	var chips_per: int = _calc_chips(winner, is_tsumo, winner.is_ippatsu, is_yakuman, ura_count)
	var score_data: Dictionary = MahjongLogic.calc_score(han, is_parent, is_tsumo)
	return {
		"winner_idx": winner_idx, "winner_name": winner.name,
		"is_tsumo": is_tsumo, "loser_idx": loser_idx,
		"han": han, "is_parent": is_parent,
		"yaku": yaku, "score_data": score_data,
		"honba": honba, "honba_bonus": honba * 2000,
		"draw": false,
		"chips_per_player": chips_per,
		"ura_count": ura_count,
		"is_yakuman": is_yakuman,
	}

func _apply_score(result: Dictionary) -> void:
	var winner_idx: int = result.winner_idx
	var is_tsumo: bool  = result.is_tsumo
	var sd: Dictionary  = result.score_data
	var honba_bonus: int = result.honba_bonus
	if is_tsumo:
		for i in range(players.size()):
			if i == winner_idx: continue
			var pay: int = sd.each
			if pay == 0: pay = sd.oya_pay if (i == dealer) else sd.ko_pay
			var hb: int = honba * 1000
			players[i].score         -= pay + hb
			players[winner_idx].score += pay + hb
	else:
		players[result.loser_idx].score  -= sd.total + honba_bonus
		players[winner_idx].score        += sd.total + honba_bonus
	players[winner_idx].score += kyotaku * 1000
	kyotaku = 0
	_apply_chips(result)

# ============================================================
# チップ計算
# ============================================================
func _calc_chips(winner: Dictionary, is_tsumo: bool, is_ippatsu: bool,
		is_yakuman: bool, ura_count: int) -> int:
	var c: int = 0
	for t: Dictionary in winner.hand:
		if t.get("is_red", false): c += 1
		if t.get("is_gold", false): c += 2
	for m: Dictionary in winner.naki:
		for t: Dictionary in m.get("tiles", []):
			if t.get("is_red", false): c += 1
			if t.get("is_gold", false): c += 2
	for nt: Dictionary in winner.nukita:
		if nt.get("is_red", false): c += 1
	c += ura_count
	if is_ippatsu: c += 1
	if is_yakuman:
		c += 5 if is_tsumo else 10
	return c

func _apply_chips(result: Dictionary) -> void:
	var winner_idx: int = result.winner_idx
	var is_tsumo: bool = result.is_tsumo
	var chips_per: int = result.get("chips_per_player", 0)
	if chips_per <= 0: return
	if is_tsumo:
		for i in range(players.size()):
			if i == winner_idx: continue
			player_chips[i] -= chips_per
			player_chips[winner_idx] += chips_per
	else:
		var loser_idx: int = result.loser_idx
		player_chips[loser_idx] -= chips_per
		player_chips[winner_idx] += chips_per

# ============================================================
# 局終了処理（全和了・流局の共通出口）
# ============================================================
func _process_kyoku_end(result: Dictionary) -> void:
	match_kyoku_count += 1
	_record_player_stats(result)

	# 流局テンパイ精算
	if result.get("draw", false):
		var tenpai_info: Dictionary = _apply_tenpai_payments()
		result["tenpai_info"] = tenpai_info

	# 飛び判定
	var bust_indices: Array = _check_bust()
	if not bust_indices.is_empty():
		_pending_match_end = true
		var bust_idx: int = bust_indices[0]
		result["bust_player_idx"] = bust_idx
		result["bust_player_indices"] = bust_indices
		# 飛び賞チップ（和了で飛ばした場合のみ）
		if not result.get("draw", false):
			var w_idx: int = result.get("winner_idx", -1)
			if w_idx >= 0:
				for bi: int in bust_indices:
					player_chips[w_idx] += 2
					player_chips[bi] -= 2

	if not _pending_match_end:
		var winner_idx: int = result.get("winner_idx", -1)
		var dealer_wins: bool = (not result.get("draw", false)) and (winner_idx == dealer)
		var draw_dealer_tenpai: bool = result.get("draw", false) and _is_player_tenpai(dealer)
		_advance_kyoku_state(dealer_wins or draw_dealer_tenpai, result.get("draw", false))

	result["match_will_end"] = _pending_match_end
	phase = Phase.GAME_OVER
	emit_signal("game_ended", result)

func _record_player_stats(result: Dictionary) -> void:
	if result.get("draw", false):
		return
	var winner_idx: int = result.get("winner_idx", -1)
	var loser_idx: int = result.get("loser_idx", -1)
	if winner_idx == 0:
		match_player_agari += 1
		match_player_agari_jun += junme
		match_player_agari_han += result.get("han", 0)
		var chips_per: int = result.get("chips_per_player", 0)
		match_player_agari_chip += chips_per * (2 if result.get("is_tsumo", false) else 1)
	elif loser_idx == 0:
		match_player_houjuu += 1

func _apply_tenpai_payments() -> Dictionary:
	var tenpai: Array = []
	var noten: Array = []
	for i in range(players.size()):
		var p: Dictionary = players[i]
		if p.is_riichi:
			tenpai.append(i)
		elif not MahjongLogic.find_waiting_tiles(MahjongLogic.get_ids(p.hand)).is_empty():
			tenpai.append(i)
		else:
			noten.append(i)

	if tenpai.is_empty() or noten.is_empty():
		return {"tenpai": tenpai, "noten": noten, "payment": 0}

	var payment: int = 0
	if tenpai.size() == 2 and noten.size() == 1:
		payment = 4000
		players[noten[0]].score -= 4000
		for t_idx: int in tenpai:
			players[t_idx].score += 2000
	elif tenpai.size() == 1 and noten.size() == 2:
		payment = 2000
		for n_idx: int in noten:
			players[n_idx].score -= 2000
		players[tenpai[0]].score += 4000
	return {"tenpai": tenpai, "noten": noten, "payment": payment}

func _check_bust() -> Array:
	var bust_indices: Array = []
	for i in range(players.size()):
		if players[i].score <= 0:
			bust_indices.append(i)
	return bust_indices

func _is_player_tenpai(idx: int) -> bool:
	var p: Dictionary = players[idx]
	if p.is_riichi: return true
	return not MahjongLogic.find_waiting_tiles(MahjongLogic.get_ids(p.hand)).is_empty()

# ============================================================
# 局進行（ディーラー回転・風更新）
# ============================================================
func _advance_kyoku_state(dealer_continues: bool, is_draw: bool) -> void:
	if dealer_continues:
		honba += 1
		return

	honba = (honba + 1) if is_draw else 0
	dealer = (dealer + 1) % players.size()
	kyoku += 1

	if kyoku > 3:
		if round_wind == MahjongLogic.EAST:
			round_wind = MahjongLogic.SOUTH
			kyoku = 1
		else:
			_pending_match_end = true
			kyoku = 3  # 表示用に留める
			return

	_update_player_winds()

func _update_player_winds() -> void:
	var wind_order := [MahjongLogic.EAST, MahjongLogic.SOUTH, MahjongLogic.WEST]
	for i in range(players.size()):
		var offset: int = (i - dealer + players.size()) % players.size()
		players[i].wind = wind_order[offset]

# ============================================================
# 精算
# ============================================================
func _compute_session_result() -> void:
	var sorted: Array = []
	for i in range(players.size()):
		sorted.append({"idx": i, "score": players[i].score})
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.score > b.score)

	# ウマ設定（1位+20000、3位-20000、2位なし）
	var uma: Array = [0, 0, 0]
	uma[sorted[0].idx] = 20000
	uma[sorted[2].idx] = -20000

	# 2位・3位の点棒増減を基準点40000で計算し、1位は逆算（3者合計がちょうど0になる）
	var raw_delta: Array = [0, 0, 0]
	for rank_j in range(1, sorted.size()):
		var p_idx: int = sorted[rank_j].idx
		raw_delta[p_idx] = players[p_idx].score - SETTLEMENT_BASE
	raw_delta[sorted[0].idx] = -(raw_delta[sorted[1].idx] + raw_delta[sorted[2].idx])

	var player_results: Array = []
	for i in range(players.size()):
		var rank: int = 1
		for j in range(sorted.size()):
			if sorted[j].idx == i:
				rank = j + 1
				break
		# ウマ込みの点棒増減（点数単位）→ P変換（1000点=100P）
		var score_delta: int = raw_delta[i] + uma[i]
		var score_p: int = score_delta / 10
		var chip_p: int = player_chips[i] * 500
		var total_p_val: int = score_p + chip_p
		player_results.append({
			"idx": i, "name": players[i].name,
			"final_score": players[i].score, "rank": rank,
			"uma": uma[i], "score_delta": score_delta,
			"chips": player_chips[i],
			"score_p": score_p, "chip_p": chip_p, "total_p": total_p_val,
		})

	session_result = {"player_results": player_results}

	var pr: Dictionary = player_results[0]
	var second_score: int = sorted[1].score if sorted.size() > 1 else 0
	var player_score_delta: int = players[0].score - INITIAL_SCORE
	SaveData.update_after_game(pr.rank, pr.total_p, player_chips[0],
							   match_kyoku_count, second_score, SaveData.selected_npc,
							   match_player_agari, match_player_houjuu,
							   match_player_agari_jun, match_player_agari_han,
							   match_player_agari_chip, player_score_delta)

# ============================================================
# 流局
# ============================================================
func _end_round_draw() -> void:
	var result: Dictionary = {"draw": true, "winner_idx": -1}
	_process_kyoku_end(result)

# ============================================================
# ユーティリティ
# ============================================================
func get_dora_id() -> int:
	if dora_indicators.is_empty(): return -1
	return MahjongLogic.get_dora_from_indicator(dora_indicators[0].id)

func get_wall_count() -> int:
	return wall.size()

func get_player(idx: int) -> Dictionary:
	if idx < 0 or idx >= players.size(): return {}
	return players[idx]

func _total_kan_count() -> int:
	var total := 0
	for p: Dictionary in players:
		total += MahjongLogic._count_kantsu(p.naki)
	return total

func _can_start_kan() -> bool:
	return wall.size() >= 2 and _total_kan_count() < 4 and dora_indicators.size() < 5

func _same_int_set(a: Array, b: Array) -> bool:
	var aa := a.duplicate()
	var bb := b.duplicate()
	aa.sort()
	bb.sort()
	return aa == bb

func _can_riichi_ankan(player_idx: int, kan_id: int) -> bool:
	var p: Dictionary = players[player_idx]
	if not p.is_riichi:
		return true
	if p.hand.is_empty():
		return false
	var drawn: Dictionary = p.hand[p.hand.size() - 1]
	if drawn.id != kan_id:
		return false
	var count := 0
	for t: Dictionary in p.hand:
		if t.id == kan_id:
			count += 1
	if count != 4:
		return false
	var after_ids: Array = []
	for t: Dictionary in p.hand:
		if t.id != kan_id:
			after_ids.append(t.id)
	var after_waits: Array = MahjongLogic.find_waiting_tiles(after_ids)
	return _same_int_set(after_waits, p.get("riichi_waiting_ids", []))

func _find_player_ankan_id() -> int:
	var p: Dictionary = players[0]
	if p.is_riichi:
		if p.hand.is_empty():
			return -1
		var drawn_id: int = p.hand[p.hand.size() - 1].id
		return drawn_id if _can_riichi_ankan(0, drawn_id) else -1
	var counts: Dictionary = {}
	for t: Dictionary in p.hand:
		counts[t.id] = counts.get(t.id, 0) + 1
	for tid: int in counts:
		if counts[tid] >= 4:
			return tid
	return -1

func can_player_riichi() -> bool:
	var p: Dictionary = players[0]
	if not p.is_menzen or p.is_riichi or p.score < 1000: return false
	return not get_riichi_selectable_indices().is_empty()

func can_player_kita() -> bool:
	var p: Dictionary = players[0]
	for t: Dictionary in p.hand:
		if t.id == MahjongLogic.NORTH: return true
	return false

func _count_tile_in_hand(hand: Array, tile_id: int) -> int:
	var count := 0
	for t: Dictionary in hand:
		if t.id == tile_id:
			count += 1
	return count

func _get_player_ankan_ids() -> Array:
	var p: Dictionary = players[0]
	var result: Array = []
	if phase == Phase.AFTER_PON or p.hand.is_empty() or not _can_start_kan():
		return result
	if p.is_riichi:
		var drawn_id: int = p.hand[p.hand.size() - 1].id
		if _can_riichi_ankan(0, drawn_id) and _count_tile_in_hand(p.hand, drawn_id) >= 4:
			result.append(drawn_id)
		return result
	var counts: Dictionary = {}
	for t: Dictionary in p.hand:
		counts[t.id] = counts.get(t.id, 0) + 1
	for tile_id in counts.keys():
		if counts[tile_id] >= 4:
			result.append(tile_id)
	result.sort()
	return result

func _get_player_kakan_ids() -> Array:
	var p: Dictionary = players[0]
	var result: Array = []
	if p.is_riichi or phase == Phase.AFTER_PON or p.hand.is_empty() or not _can_start_kan():
		return result
	for m: Dictionary in p.naki:
		if m.get("type") != "pon": continue
		var pon_id: int = m.tile_ids[0]
		if pon_id in result: continue
		for t: Dictionary in p.hand:
			if t.id == pon_id:
				result.append(pon_id)
				break
	result.sort()
	return result

func get_player_kan_selectable_indices() -> Array:
	var ids: Array = _get_player_ankan_ids()
	ids.append_array(_get_player_kakan_ids())
	var result: Array = []
	var p: Dictionary = players[0]
	for i in range(p.hand.size()):
		if p.hand[i].id in ids:
			result.append(i)
	return result

func can_player_ankan() -> bool:
	return not _get_player_ankan_ids().is_empty()

func can_player_kakan() -> bool:
	return not _get_player_kakan_ids().is_empty()

func get_riichi_selectable_indices() -> Array:
	var all_indices: Array = MahjongLogic.get_riichi_discards(players[0].hand)
	# 北（花牌）は捨てられないのでリーチ選択肢から除外する
	var result: Array = []
	for i in all_indices:
		if players[0].hand[i].id != MahjongLogic.NORTH:
			result.append(i)
	return result

# ============================================================
# NPC 槓判定ヘルパー
# ============================================================
func _npc_can_ankan(player_idx: int) -> bool:
	# ツモった牌（末尾）で4枚揃っているか
	var p: Dictionary = players[player_idx]
	if p.hand.is_empty() or not _can_start_kan(): return false
	var drawn_id: int = p.hand[p.hand.size() - 1].id
	if p.is_riichi:
		return _can_riichi_ankan(player_idx, drawn_id)
	var count: int = 0
	for t: Dictionary in p.hand:
		if t.id == drawn_id: count += 1
	return count >= 4

func _npc_can_kakan(player_idx: int) -> bool:
	# ツモった牌（末尾）が既存ポンに追加できるか
	var p: Dictionary = players[player_idx]
	if p.is_riichi or p.hand.is_empty() or not _can_start_kan(): return false
	var drawn_id: int = p.hand[p.hand.size() - 1].id
	for m: Dictionary in p.naki:
		if m.get("type") == "pon" and m.tile_ids[0] == drawn_id:
			return true
	return false

func _npc_wants_kan(npc_idx: int, tile: Dictionary) -> bool:
	# 役牌で3枚持ちなら大明槓する（ポンと同条件）
	var p: Dictionary = players[npc_idx]
	if not _can_start_kan():
		return false
	var cnt: int = 0
	for t: Dictionary in p.hand:
		if t.id == tile.id: cnt += 1
	if cnt < 3: return false
	if not MahjongLogic.is_honor(tile.id): return false
	if tile.id in [MahjongLogic.HAKU, MahjongLogic.HATSU, MahjongLogic.CHUN]: return true
	if tile.id == round_wind: return true
	if tile.id == p.wind: return true
	return false

# ============================================================
# 大明槓・加槓・加槓後処理・チャンカンチェック
# ============================================================
func _do_minkan(player_idx: int, from_idx: int, tile: Dictionary, selected_hand_idx: int = -1) -> void:
	if not _can_start_kan():
		return
	# 大明槓：他家捨て牌1枚＋手牌3枚で槓子を作り、嶺上ツモ
	kyoku_has_meld = true
	for pp: Dictionary in players:
		pp.is_ippatsu = false
	var p: Dictionary = players[player_idx]
	var removed: int = 0
	var removed_tiles: Array = []
	if selected_hand_idx >= 0 and selected_hand_idx < p.hand.size() and p.hand[selected_hand_idx].id == tile.id:
		removed_tiles.append(p.hand[selected_hand_idx])
		p.hand.remove_at(selected_hand_idx)
		removed += 1
	for i in range(p.hand.size() - 1, -1, -1):
		if p.hand[i].id == tile.id and removed < 3:
			removed_tiles.append(p.hand[i])
			p.hand.remove_at(i)
			removed += 1
	if removed_tiles.size() < 3:
		return
	var meld_tiles: Array = [tile] + removed_tiles
	p.naki.append({"type": "minkan", "tile_ids": [tile.id, tile.id, tile.id, tile.id],
				   "tiles": meld_tiles, "from_player": from_idx})
	p.is_menzen = false
	if not players[from_idx].discards.is_empty():
		players[from_idx].discards[-1]["is_taken"] = true
	action_minkan_possible = false
	# 新ドラ表示牌を公開
	if wall.size() >= 2 and dora_indicators.size() < 5:
		dora_indicators.append(wall.pop_front())
		ura_dora_indicators.append(wall.pop_front())
		emit_signal("wall_count_changed", wall.size())
	# 嶺上ツモ
	if not rinshan.is_empty():
		p.hand.append(rinshan.pop_back())
	_drew_from_rinshan = true
	if MahjongLogic._count_kantsu(p.naki) >= 4:
		_suukantsu_pending = player_idx
	emit_signal("naki_done", player_idx)
	emit_signal("tile_drawn", player_idx)
	if player_idx == 0:
		phase = Phase.PLAYER_TURN
		emit_signal("minkan_done", player_idx)
	else:
		emit_signal("minkan_done", player_idx)
		get_tree().create_timer(NPC_THINK_SEC).timeout.connect(
			func(): _npc_turn(player_idx), CONNECT_ONE_SHOT)

func _do_kakan(player_idx: int, kan_id_override: int = -1) -> void:
	if not _can_start_kan():
		return
	# 加槓：既存のポンに手牌から1枚加えて槓子にする
	# 一発クリアは _finish_kakan() で行う（槍槓成立時は槓不成立なので一発は消えない）
	kyoku_has_meld = true
	var p: Dictionary = players[player_idx]
	# ポンに対応する手牌の牌を探す
	var kakan_naki_idx: int = -1
	var kakan_tile_id: int = -1
	for ni in range(p.naki.size()):
		var m: Dictionary = p.naki[ni]
		if m.get("type") != "pon": continue
		var pon_id: int = m.tile_ids[0]
		if kan_id_override >= 0 and pon_id != kan_id_override:
			continue
		for t: Dictionary in p.hand:
			if t.id == pon_id:
				kakan_naki_idx = ni
				kakan_tile_id = pon_id
				break
		if kakan_naki_idx >= 0: break
	if kakan_naki_idx < 0: return
	# 手牌から加槓牌を1枚除去してポンをkakan型に更新
	for i in range(p.hand.size() - 1, -1, -1):
		if p.hand[i].id == kakan_tile_id:
			var added: Dictionary = p.hand[i]
			p.hand.remove_at(i)
			p.naki[kakan_naki_idx]["type"] = "kakan"
			p.naki[kakan_naki_idx]["tile_ids"].append(kakan_tile_id)
			p.naki[kakan_naki_idx]["tiles"].append(added)
			break
	_kakan_tile = MahjongLogic.make_tile(kakan_tile_id)
	# 加槓後チャンカン機会チェック
	if player_idx != 0:
		# NPC加槓時：プレイヤーにチャンカン機会があるか確認
		_check_chankan_opportunity(player_idx, kakan_tile_id)
	else:
		# プレイヤー加槓時：NPCにチャンカン機会があるか確認
		_check_npc_chankan_opportunity(kakan_tile_id)

func _check_chankan_opportunity(kakan_player_idx: int, tile_id: int) -> void:
	# プレイヤーが加槓牌でロン（チャンカン）できるか判定
	var p0: Dictionary = players[0]
	var hand_ids: Array = MahjongLogic.get_ids(p0.hand)
	var waiting: Array = MahjongLogic.find_waiting_tiles(hand_ids)
	if tile_id in waiting and not _is_player_furiten(0):
		var test_hand: Array = hand_ids.duplicate()
		test_hand.append(tile_id)
		test_hand.sort()
		var ctx: Dictionary = _build_context(0, false, tile_id)
		ctx["is_chankan"] = true
		var yaku: Array = MahjongLogic.check_yaku(test_hand, ctx)
		if not yaku.is_empty():
			last_discarded_tile = _kakan_tile
			last_discard_player = kakan_player_idx
			action_winner_idx = 0
			action_is_ron = true
			action_pon_from = -1
			_pending_kakan_player = kakan_player_idx
			_is_chankan_ron = true
			phase = Phase.ACTION_WAIT
			emit_signal("ron_opportunity", 0, kakan_player_idx, _kakan_tile)
			return
	_finish_kakan(kakan_player_idx)

func _check_npc_chankan_opportunity(kakan_tile_id: int) -> void:
	# プレイヤー加槓時：NPCにチャンカン機会があるか確認
	# ポン牌を切った本人（from_player）はフリテンなのでスキップ
	var kakan_from_player: int = -1
	for m: Dictionary in players[0].naki:
		if m.get("type") == "kakan":
			kakan_from_player = m.get("from_player", -1)
			break
	for i in range(1, players.size()):
		if i == kakan_from_player: continue
		var np: Dictionary = players[i]
		var hand_ids: Array = MahjongLogic.get_ids(np.hand)
		var waiting: Array = MahjongLogic.find_waiting_tiles(hand_ids)
		if kakan_tile_id in waiting:
			var test_hand: Array = hand_ids.duplicate()
			test_hand.append(kakan_tile_id)
			test_hand.sort()
			var ctx: Dictionary = _build_context(i, false, kakan_tile_id)
			ctx["is_chankan"] = true
			var yaku: Array = MahjongLogic.check_yaku(test_hand, ctx)
			if not yaku.is_empty():
				# NPC自動チャンカン宣言（NPCは自動でロンする）
				np.hand.append(_kakan_tile)
				var result: Dictionary = _build_win_result(i, false, 0, yaku)
				np.hand.pop_back()
				_apply_score(result)
				_process_kyoku_end(result)
				return
	_finish_kakan(0)

func _finish_kakan(player_idx: int) -> void:
	# 加槓完了：新ドラ公開・嶺上ツモ・ターン継続
	# チャンカン不成立（スキップ or 成立できない）確定 → ここで初めて一発を消す
	for pp: Dictionary in players:
		pp.is_ippatsu = false
	var p: Dictionary = players[player_idx]
	if wall.size() >= 2 and dora_indicators.size() < 5:
		dora_indicators.append(wall.pop_front())
		ura_dora_indicators.append(wall.pop_front())
		emit_signal("wall_count_changed", wall.size())
	if not rinshan.is_empty():
		p.hand.append(rinshan.pop_back())
	_drew_from_rinshan = true
	if MahjongLogic._count_kantsu(p.naki) >= 4:
		_suukantsu_pending = player_idx
	emit_signal("kakan_done", player_idx)
	emit_signal("tile_drawn", player_idx)
	if player_idx == 0:
		phase = Phase.PLAYER_TURN
	else:
		get_tree().create_timer(NPC_THINK_SEC).timeout.connect(
			func(): _npc_turn(player_idx), CONNECT_ONE_SHOT)

# ============================================================
# デバッグ用
# ============================================================
func debug_set_hand(hand_tiles_13: Array, draw_tile: Dictionary = {}, next_draw_tile: Dictionary = {}, target_player: int = 0) -> void:
	var p: Dictionary = players[target_player]
	p.hand.clear()
	for tile: Dictionary in hand_tiles_13:
		p.hand.append(MahjongLogic.make_tile(
			tile.get("id", 0),
			tile.get("is_red", false),
			tile.get("is_gold", false),
			tile.get("is_haku_pochi", false)
		))
	var draw_id: int = draw_tile.get("id", 0)
	if draw_id > 0:
		p.hand.append(MahjongLogic.make_tile(
			draw_id,
			draw_tile.get("is_red", false),
			draw_tile.get("is_gold", false),
			draw_tile.get("is_haku_pochi", false)
		))
	# 次順ツモのwall操作はプレイヤー0のみ
	if target_player == 0:
		var next_id: int = next_draw_tile.get("id", 0)
		if next_id > 0:
			# draw_id > 0 の場合：プレイヤーが捨てた後にNPC2人が引くので wall[2] が次順ツモ
			# draw_id == 0 の場合：次にプレイヤーが引く位置は wall[0]
			var wall_idx: int = 2 if draw_id > 0 else 0
			var next_tile := MahjongLogic.make_tile(
				next_id,
				next_draw_tile.get("is_red", false),
				next_draw_tile.get("is_gold", false),
				next_draw_tile.get("is_haku_pochi", false)
			)
			if wall_idx < wall.size():
				wall[wall_idx] = next_tile
			elif wall_idx == wall.size():
				wall.append(next_tile)

func debug_set_rinshan(tiles_1st_to_8th: Array) -> void:
	# tiles_1st_to_8th[0] = 1st draw, [7] = 8th draw
	# rinshan.pop_back() draws last element → reverse order to set correctly
	rinshan.clear()
	for i in range(tiles_1st_to_8th.size() - 1, -1, -1):
		var tile: Dictionary = tiles_1st_to_8th[i]
		if tile.get("id", 0) > 0:
			rinshan.append(MahjongLogic.make_tile(
				tile.id,
				tile.get("is_red", false),
				tile.get("is_gold", false),
				tile.get("is_haku_pochi", false)
			))
