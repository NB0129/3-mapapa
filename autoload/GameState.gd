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
const NPC_THINK_SEC := 0.2

# ============================================================
# マッチレベル状態
# ============================================================
var player_chips: Array = [0, 0, 0]  # チップ収支（現試合）
var session_result: Dictionary = {}   # 精算結果（Result画面用）
var _pending_match_end: bool = false
var _pending_oorasu_player_choice: bool = false
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
var _recorder: GameLogRecorder = null
var _is_chankan_ron: bool = false         # 槍槓ロン中かどうか（_finalize_ronでis_chankan=trueにするため）
var _suukantsu_pending: int = -1         # 四槓子成立待ち（4つ目槓後の捨て牌でロンなければ成立）
var _pending_npc_ron_after_skip: int = -1 # プレイヤーがロンを見逃した場合の次順位NPCロン候補
var _pending_player_riichi_hand_idx: int = -1

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
var _kyoku_start_scores: Array = []

var phase: int = Phase.IDLE
var last_discarded_tile: Dictionary = {}
var last_discard_player: int = -1
var junme: int = 0
var kyoku_has_meld: bool = false   # 局開始後に誰かがポン/カンしたか（地和判定用）
var daburi_allowed: Array = []
var first_round_win_allowed: Array = []
var action_winner_idx: int = -1
var action_ron_candidates: Array = []
var action_is_ron: bool = false
var action_pon_from: int = -1

# ============================================================
# プレイヤーデータ生成
# ============================================================
func _make_player(p_name: String, is_npc: bool, wind: int, npc_id: String = "") -> Dictionary:
	return {
		"name": p_name, "is_npc": is_npc, "wind": wind,
		"npc_id": npc_id,
		"npc_mode": "",
		"score": INITIAL_SCORE,
		"hand": [], "discards": [], "naki": [], "nukita": [],
		"is_riichi": false, "is_daburi": false, "is_ippatsu": false,
		"is_open_riichi": false,
		"riichi_sticks": 0,
		"is_menzen": true,
		"riichi_discard_idx": -1,
		"riichi_waiting_ids": [],
		"pon_forbidden_id": -1,
		"is_riichi_furiten": false,
		"is_doujun_furiten": false,
		"pao_daisangen_from": -1,
		"pao_suukantsu_from": -1,
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
	_pending_oorasu_player_choice = false
	session_result = {}
	kyotaku = 0
	# プレイヤー初期化
	players = []
	round_wind = MahjongLogic.EAST
	kyoku = 1
	honba = 0
	dealer = 0
	# SaveDataのプレイヤー名とNPC選択を使う
	var seat_npcs: Dictionary = SaveData.selected_npc_seats
	var empty_seat: String = SaveData.selected_empty_seat
	var player_wind: int = MahjongLogic.EAST
	var seat_winds := {"bottom": MahjongLogic.SOUTH, "right": MahjongLogic.WEST, "top": MahjongLogic.NORTH}
	match empty_seat:
		"bottom":
			player_wind = MahjongLogic.WEST
			seat_winds = {"bottom": MahjongLogic.NORTH, "right": MahjongLogic.EAST, "top": MahjongLogic.SOUTH}
		"right":
			player_wind = MahjongLogic.SOUTH
			seat_winds = {"bottom": MahjongLogic.WEST, "right": MahjongLogic.NORTH, "top": MahjongLogic.EAST}
		_:
			player_wind = MahjongLogic.EAST
			seat_winds = {"bottom": MahjongLogic.SOUTH, "right": MahjongLogic.WEST, "top": MahjongLogic.NORTH}
	players.append(_make_player(SaveData.player_name, false, player_wind))
	for seat in ["bottom", "right", "top"]:
		var npc_id := str(seat_npcs.get(seat, ""))
		if npc_id == "":
			continue
		players.append(_make_player(SaveData.get_npc_name(npc_id), true, seat_winds[seat], npc_id))
	while players.size() < 3:
		var fallback_id := "kuma_def" if players.size() == 1 else "kuma_hiyake"
		players.append(_make_player(SaveData.get_npc_name(fallback_id), true, MahjongLogic.SOUTH if players.size() == 1 else MahjongLogic.WEST, fallback_id))
	dealer = _find_dealer_index()
	_recorder = GameLogRecorder.new()
	_recorder.start_game(players)
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
		p.is_open_riichi = false
		p.is_daburi = false
		p.is_ippatsu = false
		p.riichi_sticks = 0
		p.is_menzen = true
		p.riichi_discard_idx = -1
		p.riichi_waiting_ids = []
		p.pon_forbidden_id = -1
		p.is_riichi_furiten = false
		p.is_doujun_furiten = false
		p.pao_daisangen_from = -1
		p.pao_suukantsu_from = -1
		p.npc_mode = ""
	_setup_wall()
	_deal_hands()
	_init_npc_modes()
	_kyoku_start_scores = _snapshot_scores()
	phase = Phase.IDLE
	junme = 0
	kyoku_has_meld = false
	daburi_allowed = []
	first_round_win_allowed = []
	for _i in range(players.size()):
		daburi_allowed.append(true)
		first_round_win_allowed.append(true)
	last_discarded_tile = {}
	last_discard_player = -1
	action_winner_idx = -1
	action_ron_candidates = []
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
	_pending_player_riichi_hand_idx = -1
	emit_signal("game_started")
	if _recorder:
		_recorder.start_round(round_wind, kyoku, honba, dealer,
			players.map(func(p: Dictionary): return p.score))
	_start_turn(dealer)

# 局結果確認後に呼び出し（ゲーム.gd から）
func advance_game() -> void:
	if _pending_oorasu_player_choice:
		return
	if _pending_match_end:
		_compute_session_result()
		emit_signal("match_ended", session_result)
	else:
		_start_kyoku()

func resolve_oorasu_player_choice(continue_match: bool) -> void:
	if not _pending_oorasu_player_choice:
		return
	_pending_oorasu_player_choice = false
	if continue_match:
		honba += 1
		_start_kyoku()
	else:
		_pending_match_end = true
		_compute_session_result()
		emit_signal("match_ended", session_result)

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

func _snapshot_scores() -> Array:
	var scores: Array = []
	for p: Dictionary in players:
		scores.append(int(p.score))
	return scores

func _snapshot_player_winds() -> Array:
	var winds: Array = []
	for p: Dictionary in players:
		winds.append(int(p.wind))
	return winds

func _init_npc_modes() -> void:
	for i in range(players.size()):
		var p: Dictionary = players[i]
		if not p.get("is_npc", false):
			continue
		var npc_id := str(p.get("npc_id", ""))
		var kokushi_threshold := 10
		if npc_id == "kuma_hiyake":
			kokushi_threshold = 9
		if _is_black_family_npc(npc_id) and _count_yaochu_types(MahjongLogic.get_ids(p.hand)) >= kokushi_threshold:
			p.npc_mode = "kokushi"
		else:
			p.npc_mode = "normal"

# ============================================================
# ターン管理
# ============================================================
func _start_turn(player_idx: int) -> void:
	current_player = player_idx
	if wall.is_empty():
		_end_round_draw()
		return
	if players[player_idx].is_npc:
		phase = Phase.NPC_TURN
	else:
		phase = Phase.PLAYER_TURN

	var drawn: Dictionary = wall.pop_front()
	players[player_idx].hand.append(drawn)
	players[player_idx].is_doujun_furiten = false
	_drew_from_rinshan = false  # 通常ツモなので嶺上フラグをリセット
	if _recorder:
		_recorder.record_draw(player_idx, drawn,
			players[player_idx].hand.duplicate(true) if not players[player_idx].is_npc else [])

	emit_signal("tile_drawn", player_idx)
	emit_signal("wall_count_changed", wall.size())

	# 白ポッチ強制和了（リーチ中のプレイヤーがツモった時のみ発動）
	if drawn.get("is_haku_pochi", false) and players[player_idx].is_riichi:
		_process_haku_pochi_tsumo(player_idx)
		return

	if players[player_idx].is_npc:
		emit_signal("npc_thinking", player_idx)
		emit_signal("turn_started", player_idx)
		get_tree().create_timer(NPC_THINK_SEC).timeout.connect(
			func(): _npc_turn(player_idx), CONNECT_ONE_SHOT)
	else:
		junme += 1
		emit_signal("turn_started", player_idx)

# ============================================================
# NPC AI
# ============================================================
func _npc_turn(player_idx: int) -> void:
	if current_player != player_idx:
		return
	var p: Dictionary = players[player_idx]
	var hand_ids: Array = MahjongLogic.get_ids(p.hand)

	if MahjongLogic.is_complete_hand(hand_ids):
		var yaku: Array = _npc_tsumo_yaku(player_idx, hand_ids)
		if not yaku.is_empty():
			var result: Dictionary = _build_win_result(player_idx, true, -1, yaku)
			_apply_score(result)
			emit_signal("tsumo_declared", player_idx, result)
			_process_kyoku_end(result)
			return

	if _has_kita(p) and _npc_should_kita(player_idx):
		_do_kita(player_idx)
		if phase == Phase.ACTION_WAIT:
			return
		var kita_hand_ids: Array = MahjongLogic.get_ids(p.hand)
		if MahjongLogic.is_complete_hand(kita_hand_ids):
			var kita_yaku: Array = _npc_tsumo_yaku(player_idx, kita_hand_ids)
			if not kita_yaku.is_empty():
				var kita_result: Dictionary = _build_win_result(player_idx, true, -1, kita_yaku)
				_apply_score(kita_result)
				emit_signal("tsumo_declared", player_idx, kita_result)
				_process_kyoku_end(kita_result)
				return
		get_tree().create_timer(NPC_THINK_SEC).timeout.connect(
			func(): _npc_turn(player_idx), CONNECT_ONE_SHOT)
		return

	if _is_hokkyoku_npc(player_idx):
		if _npc_should_daburi(player_idx):
			var hokkyoku_riichi: Array = MahjongLogic.get_riichi_discards(p.hand)
			hokkyoku_riichi = _filter_north_indices(p.hand, hokkyoku_riichi)
			if not hokkyoku_riichi.is_empty():
				_do_riichi_discard(player_idx, _choose_best_riichi_discard(player_idx, hokkyoku_riichi))
				return
		if p.is_riichi:
			_do_discard_internal(player_idx, p.hand.size() - 1, true)
			return
		_do_discard_internal(player_idx, _choose_open_riichi_legal_discard_index(player_idx, _choose_tsumogiri_index(player_idx)))
		return

	if _npc_must_fold_before_actions(player_idx):
		_do_discard_internal(player_idx, _choose_open_riichi_legal_discard_index(player_idx, _choose_npc_fold_discard_index(player_idx)))
		return

	if _npc_can_ankan(player_idx):
		_do_ankan(player_idx)
		return

	if _npc_can_kakan(player_idx):
		_do_kakan(player_idx)
		return

	if _is_closed_for_riichi(p) and not p.is_riichi and p.score >= 1000:
		var riichi_idx: Array = MahjongLogic.get_riichi_discards(p.hand)
		riichi_idx = _filter_north_indices(p.hand, riichi_idx)
		if not riichi_idx.is_empty():
			var discard_i: int = _choose_npc_riichi_index(player_idx, riichi_idx)
			var legal_discard_i := _choose_open_riichi_legal_discard_index(player_idx, discard_i)
			if legal_discard_i != discard_i:
				_do_discard_internal(player_idx, legal_discard_i)
				return
			_do_riichi_discard(player_idx, discard_i)
			return

	if p.is_riichi:
		_do_discard_internal(player_idx, p.hand.size() - 1, true)
		return

	_do_discard_internal(player_idx, _choose_open_riichi_legal_discard_index(player_idx, _choose_npc_personality_discard_index(player_idx)))

func _npc_tsumo_yaku(player_idx: int, hand_ids: Array) -> Array:
	var p: Dictionary = players[player_idx]
	var winning_id: int = p.hand[p.hand.size() - 1].id
	var context: Dictionary = _build_context(player_idx, true, winning_id)
	var yaku: Array = MahjongLogic.check_yaku(hand_ids, context)
	if yaku.is_empty():
		return []
	if _is_hokkyoku_npc(player_idx) and not (p.is_riichi or context.get("is_tenhou", false) or context.get("is_chiihou", false)):
		return []
	return yaku

func _is_renhou_ron(player_idx: int) -> bool:
	var p: Dictionary = players[player_idx]
	return player_idx != dealer and _can_first_round_win(player_idx) and p.naki.is_empty() and not p.is_riichi

func _is_hokkyoku_npc(player_idx: int) -> bool:
	return str(players[player_idx].get("npc_id", "")) == "kuma_hokkyoku"

func _is_black_family_npc(npc_id: String) -> bool:
	return npc_id in ["kuma_black", "kuma_megane", "kuma_hiyake", "kuma_saibo"]

func _npc_should_kita(player_idx: int) -> bool:
	var p: Dictionary = players[player_idx]
	if _is_hokkyoku_npc(player_idx):
		return true
	if p.get("npc_mode", "") == "kokushi":
		return _count_tile_in_hand(p.hand, MahjongLogic.NORTH) > 1
	return true

func _npc_should_daburi(player_idx: int) -> bool:
	var p: Dictionary = players[player_idx]
	return _can_daburi(player_idx) and _is_closed_for_riichi(p) and not p.is_riichi and p.score >= 1000 and p.hand.size() == 14

func _can_daburi(player_idx: int) -> bool:
	return player_idx >= 0 and player_idx < daburi_allowed.size() and bool(daburi_allowed[player_idx]) and not kyoku_has_meld

func _cancel_all_daburi_rights() -> void:
	for i in range(daburi_allowed.size()):
		daburi_allowed[i] = false

func _can_first_round_win(player_idx: int) -> bool:
	return player_idx >= 0 and player_idx < first_round_win_allowed.size() and bool(first_round_win_allowed[player_idx]) and not kyoku_has_meld

func _cancel_all_first_round_win_rights() -> void:
	for i in range(first_round_win_allowed.size()):
		first_round_win_allowed[i] = false

func _npc_must_fold_before_actions(player_idx: int) -> bool:
	var p: Dictionary = players[player_idx]
	if p.get("is_riichi", false):
		return false
	return str(p.get("npc_id", "")) == "kuma_megane" and _riichi_opponents(player_idx).size() > 0

func _choose_tsumogiri_index(player_idx: int) -> int:
	var p: Dictionary = players[player_idx]
	for i in range(p.hand.size() - 1, -1, -1):
		if p.hand[i].id != MahjongLogic.NORTH:
			return i
	return p.hand.size() - 1

func _filter_north_indices(hand: Array, indices: Array) -> Array:
	var result: Array = []
	for i in indices:
		if hand[int(i)].id != MahjongLogic.NORTH:
			result.append(int(i))
	return result

func _choose_npc_riichi_index(player_idx: int, riichi_indices: Array) -> int:
	if str(players[player_idx].get("npc_id", "")) in ["kuma_black", "kuma_megane", "kuma_hiyake", "kuma_saibo", "kuma_hokkyoku"]:
		return _choose_best_riichi_discard(player_idx, riichi_indices)
	return int(riichi_indices[0])

func _choose_best_riichi_discard(player_idx: int, riichi_indices: Array) -> int:
	var best_idx: int = int(riichi_indices[0])
	var best_score: Array = []
	for raw_idx in riichi_indices:
		var i: int = int(raw_idx)
		var score: Array = _score_riichi_discard(player_idx, i)
		if best_score.is_empty() or _is_riichi_score_better(score, best_score):
			best_score = score
			best_idx = i
	return best_idx

func _score_riichi_discard(player_idx: int, hand_idx: int) -> Array:
	var p: Dictionary = players[player_idx]
	var hand_ids: Array = MahjongLogic.get_ids(p.hand)
	var test: Array = hand_ids.duplicate()
	test.remove_at(hand_idx)
	var waits: Array = MahjongLogic.find_waiting_tiles(test)
	var wait_count: int = 0
	for tid: int in waits:
		wait_count += _remaining_tile_count_for_npc(player_idx, tid)
	var best_han: int = 0
	for tid: int in waits:
		var win_hand: Array = test.duplicate()
		win_hand.append(tid)
		win_hand.sort()
		var ctx: Dictionary = _build_context(player_idx, false, tid)
		ctx["is_riichi"] = true
		ctx["is_daburi"] = _can_daburi(player_idx) and p.hand.size() == 14
		var yaku: Array = MahjongLogic.check_yaku(win_hand, ctx)
		best_han = max(best_han, MahjongLogic.count_han(yaku))
	var safety: int = _discard_safety_score_for_all_opponents(player_idx, p.hand[hand_idx])
	return [wait_count, best_han, waits.size(), -_discard_bonus_penalty(p.hand[hand_idx]), safety]

func _is_riichi_score_better(a: Array, b: Array) -> bool:
	for i in range(min(a.size(), b.size())):
		if int(a[i]) != int(b[i]):
			return int(a[i]) > int(b[i])
	return false

func _remaining_tile_count_for_npc(player_idx: int, tile_id: int) -> int:
	var visible: int = 0
	for i in range(players.size()):
		var p: Dictionary = players[i]
		for t: Dictionary in p.discards:
			if t.id == tile_id:
				visible += 1
		for t: Dictionary in p.nukita:
			if t.id == tile_id:
				visible += 1
		for m: Dictionary in p.naki:
			for mid in m.get("tile_ids", []):
				if int(mid) == tile_id:
					visible += 1
		if i == player_idx:
			for t: Dictionary in p.hand:
				if t.id == tile_id:
					visible += 1
	for t: Dictionary in dora_indicators:
		if t.id == tile_id:
			visible += 1
	return max(0, 4 - visible)

func _choose_npc_personality_discard_index(player_idx: int) -> int:
	var npc_id: String = str(players[player_idx].get("npc_id", ""))
	if npc_id == "kuma_saibo":
		if players[player_idx].get("npc_mode", "") == "kokushi":
			return _choose_kokushi_discard_index(player_idx)
		return _choose_saibo_discard_index(player_idx)
	if _is_black_family_npc(npc_id):
		if npc_id == "kuma_megane" and _npc_should_fold(player_idx):
			return _choose_npc_fold_discard_index(player_idx)
		if players[player_idx].get("npc_mode", "") == "kokushi":
			return _choose_kokushi_discard_index(player_idx)
		if _npc_should_fold(player_idx):
			return _choose_npc_fold_discard_index(player_idx)
	if _is_hokkyoku_npc(player_idx):
		return _choose_tsumogiri_index(player_idx)
	return _choose_npc_safe_discard_index(player_idx)

func _choose_saibo_discard_index(player_idx: int) -> int:
	var p: Dictionary = players[player_idx]
	var hand_ids: Array = MahjongLogic.get_ids(p.hand)
	var best: Array = []
	var best_score := -999999
	for i in range(p.hand.size()):
		if p.hand[i].id == MahjongLogic.NORTH:
			continue
		var test: Array = hand_ids.duplicate()
		test.remove_at(i)
		var shanten: int = MahjongLogic.calculate_shanten(test)
		var ukeire: int = MahjongLogic.count_ukeire_after_discard(test)
		var safety: int = _discard_safety_score_for_fold(player_idx, p.hand[i])
		var value: int = -shanten * 10000 + ukeire * 80 + safety
		if _is_dora_id(p.hand[i].id):
			value -= 120
		if p.hand[i].get("is_gold", false):
			value -= 180
		if p.hand[i].get("is_red", false):
			value -= 120
		if _riichi_opponents(player_idx).is_empty() and junme < 12:
			value -= safety / 2
		if value > best_score:
			best_score = value
			best = [i]
		elif value == best_score:
			best.append(i)
	if best.is_empty():
		return _choose_npc_discard_index(player_idx)
	return _prefer_non_bonus_discard(p.hand, best)

func _choose_kokushi_discard_index(player_idx: int) -> int:
	var p: Dictionary = players[player_idx]
	var best: Array = []
	var best_priority: int = -999
	for i in range(p.hand.size()):
		if p.hand[i].id == MahjongLogic.NORTH and _count_tile_in_hand(p.hand, MahjongLogic.NORTH) <= 1:
			continue
		var priority: int = _kokushi_discard_priority(player_idx, p.hand[i])
		if priority > best_priority:
			best_priority = priority
			best = [i]
		elif priority == best_priority:
			best.append(i)
	if best.is_empty():
		return _choose_npc_discard_index(player_idx)
	return int(best.pick_random())

func _kokushi_discard_priority(player_idx: int, tile: Dictionary) -> int:
	if tile.get("is_gold", false):
		return 100
	if tile.get("is_red", false):
		return 95
	if _is_chunchan(tile.id) and _is_dora_id(tile.id):
		return 90
	var num: int = _tile_number(tile.id)
	match num:
		5: return 80
		7: return 75
		3: return 70
		4, 6: return 65
		8, 2: return 60
		1, 9:
			if _count_tile_in_hand(players[player_idx].hand, tile.id) > 1:
				return 55
			return 10
	if MahjongLogic.is_honor(tile.id):
		if _is_otakaze(player_idx, tile.id):
			return 50
		if _is_yakuhai(player_idx, tile.id) and _visible_count_for_player(player_idx, tile.id) >= 3:
			return 45
		if tile.id == players[player_idx].wind:
			return 40
		if tile.id in [MahjongLogic.HAKU, MahjongLogic.HATSU, MahjongLogic.CHUN]:
			return 35
		if tile.id == round_wind:
			return 30
	return 20

func _npc_should_fold(player_idx: int) -> bool:
	var npc_id: String = str(players[player_idx].get("npc_id", ""))
	if npc_id == "kuma_hiyake" or npc_id == "kuma_saibo":
		return false
	if npc_id == "kuma_megane":
		return _riichi_opponents(player_idx).size() > 0
	var shanten: int = MahjongLogic.calculate_shanten(MahjongLogic.get_ids(players[player_idx].hand))
	if _riichi_opponents(player_idx).size() >= 2 and shanten > 0:
		return true
	if junme >= 13 and shanten > 0:
		return true
	return players[player_idx].wind != MahjongLogic.EAST and players[dealer].get("is_riichi", false) and shanten >= 2

func _choose_npc_fold_discard_index(player_idx: int) -> int:
	var p: Dictionary = players[player_idx]
	var best: Array = []
	var best_score: int = -999999
	for i in range(p.hand.size()):
		if p.hand[i].id == MahjongLogic.NORTH:
			continue
		var score: int = _discard_safety_score_for_fold(player_idx, p.hand[i])
		if score > best_score:
			best_score = score
			best = [i]
		elif score == best_score:
			best.append(i)
	if best.is_empty():
		return _choose_npc_discard_index(player_idx)
	return _prefer_non_bonus_discard(p.hand, best)

func _choose_npc_discard_index(player_idx: int) -> int:
	var p: Dictionary = players[player_idx]
	var hand_ids: Array = MahjongLogic.get_ids(p.hand)
	var best_indices: Array = []
	var best_shanten := 99
	for i in range(p.hand.size()):
		if p.hand[i].id == MahjongLogic.NORTH:
			continue
		var test: Array = hand_ids.duplicate()
		test.remove_at(i)
		var shanten: int = MahjongLogic.calculate_shanten(test)
		if shanten < best_shanten:
			best_shanten = shanten
			best_indices = [i]
		elif shanten == best_shanten:
			best_indices.append(i)
	if best_indices.is_empty():
		return p.hand.size() - 1

	var best_ukeire := -1
	var best_ukeire_indices: Array = []
	for i: int in best_indices:
		var test: Array = hand_ids.duplicate()
		test.remove_at(i)
		var ukeire: int = MahjongLogic.count_ukeire_after_discard(test)
		if ukeire > best_ukeire:
			best_ukeire = ukeire
			best_ukeire_indices = [i]
		elif ukeire == best_ukeire:
			best_ukeire_indices.append(i)
	return _prefer_non_bonus_discard(p.hand, best_ukeire_indices)

func _choose_npc_safe_discard_index(player_idx: int) -> int:
	var waits: Array = _open_riichi_wait_ids_against(player_idx)
	if waits.is_empty():
		return _choose_npc_discard_index(player_idx)
	var original_hand: Array = players[player_idx].hand
	var safe_indices: Array = []
	for i in range(original_hand.size()):
		if original_hand[i].id == MahjongLogic.NORTH:
			continue
		if original_hand[i].id not in waits:
			safe_indices.append(i)
	if safe_indices.is_empty():
		return _choose_npc_discard_index(player_idx)

	return _choose_best_discard_from_indices(player_idx, safe_indices)

func _choose_open_riichi_legal_discard_index(player_idx: int, preferred_idx: int) -> int:
	if player_idx < 0 or player_idx >= players.size():
		return preferred_idx
	var p: Dictionary = players[player_idx]
	if p.get("is_riichi", false):
		return preferred_idx
	if preferred_idx < 0 or preferred_idx >= p.hand.size():
		return preferred_idx
	var waits: Array = _open_riichi_wait_ids_against(player_idx)
	if waits.is_empty():
		return preferred_idx
	if p.hand[preferred_idx].id not in waits:
		return preferred_idx
	var safe_indices: Array = []
	for i in range(p.hand.size()):
		if p.hand[i].id == MahjongLogic.NORTH:
			continue
		if p.hand[i].id not in waits:
			safe_indices.append(i)
	if safe_indices.is_empty():
		return preferred_idx
	return _choose_best_discard_from_indices(player_idx, safe_indices)

func _open_riichi_wait_ids_against(player_idx: int) -> Array:
	var result: Array = []
	for i in range(players.size()):
		if i == player_idx:
			continue
		var p: Dictionary = players[i]
		if not p.get("is_open_riichi", false):
			continue
		for tid in p.get("riichi_waiting_ids", []):
			var id := int(tid)
			if id not in result:
				result.append(id)
	return result

func _choose_best_discard_from_indices(player_idx: int, indices: Array) -> int:
	if indices.is_empty():
		return _choose_npc_discard_index(player_idx)
	var p: Dictionary = players[player_idx]
	var hand_ids: Array = MahjongLogic.get_ids(p.hand)
	var best_indices: Array = []
	var best_shanten := 99
	for i: int in indices:
		if p.hand[i].id == MahjongLogic.NORTH:
			continue
		var test: Array = hand_ids.duplicate()
		test.remove_at(i)
		var shanten: int = MahjongLogic.calculate_shanten(test)
		if shanten < best_shanten:
			best_shanten = shanten
			best_indices = [i]
		elif shanten == best_shanten:
			best_indices.append(i)
	if best_indices.is_empty():
		best_indices = indices
	return _prefer_non_bonus_discard(p.hand, best_indices)

func _prefer_non_bonus_discard(hand: Array, indices: Array) -> int:
	var best_indices: Array = []
	var best_penalty := 99
	for i: int in indices:
		var penalty: int = _discard_bonus_penalty(hand[i])
		if penalty < best_penalty:
			best_penalty = penalty
			best_indices = [i]
		elif penalty == best_penalty:
			best_indices.append(i)
	return best_indices.pick_random()

func _discard_bonus_penalty(tile: Dictionary) -> int:
	var penalty := 0
	if tile.get("is_gold", false):
		penalty += 2
	if tile.get("is_red", false):
		penalty += 1
	return penalty

func _count_yaochu_types(hand_ids: Array) -> int:
	var yaochu: Dictionary = {}
	for tid in hand_ids:
		var id: int = int(tid)
		if id in [MahjongLogic.MAN_1, MahjongLogic.MAN_9, MahjongLogic.PIN_1, MahjongLogic.PIN_9,
				MahjongLogic.SOU_1, MahjongLogic.SOU_9, MahjongLogic.EAST, MahjongLogic.SOUTH,
				MahjongLogic.WEST, MahjongLogic.NORTH, MahjongLogic.HAKU, MahjongLogic.HATSU, MahjongLogic.CHUN]:
			yaochu[id] = true
	return yaochu.size()

func _is_chunchan(tile_id: int) -> bool:
	var n: int = _tile_number(tile_id)
	return n >= 2 and n <= 8

func _tile_number(tile_id: int) -> int:
	if tile_id >= 21 and tile_id <= 29:
		return tile_id - 20
	if tile_id >= 31 and tile_id <= 39:
		return tile_id - 30
	if tile_id == MahjongLogic.MAN_1:
		return 1
	if tile_id == MahjongLogic.MAN_9:
		return 9
	return 0

func _is_dora_id(tile_id: int) -> bool:
	for indicator: Dictionary in dora_indicators:
		if tile_id == MahjongLogic.get_dora_from_indicator(indicator.id):
			return true
	return false

func _is_yakuhai(player_idx: int, tile_id: int) -> bool:
	return tile_id in [MahjongLogic.HAKU, MahjongLogic.HATSU, MahjongLogic.CHUN, round_wind, players[player_idx].wind]

func _is_otakaze(player_idx: int, tile_id: int) -> bool:
	if tile_id not in [MahjongLogic.EAST, MahjongLogic.SOUTH, MahjongLogic.WEST, MahjongLogic.NORTH]:
		return false
	return tile_id != round_wind and tile_id != players[player_idx].wind

func _visible_count_for_player(player_idx: int, tile_id: int) -> int:
	var count: int = 0
	for i in range(players.size()):
		var p: Dictionary = players[i]
		if i == player_idx:
			for t: Dictionary in p.hand:
				if t.id == tile_id:
					count += 1
		for t: Dictionary in p.discards:
			if t.id == tile_id:
				count += 1
		for t: Dictionary in p.nukita:
			if t.id == tile_id:
				count += 1
		for m: Dictionary in p.naki:
			for mid in m.get("tile_ids", []):
				if int(mid) == tile_id:
					count += 1
	return count

func _riichi_opponents(player_idx: int) -> Array:
	var result: Array = []
	for i in range(players.size()):
		if i != player_idx and players[i].get("is_riichi", false):
			result.append(i)
	return result

func _discard_safety_score_for_all_opponents(player_idx: int, tile: Dictionary) -> int:
	var score: int = 0
	for i in range(players.size()):
		if i == player_idx:
			continue
		score += _discard_safety_score_against(i, tile)
	return score

func _discard_safety_score_for_fold(player_idx: int, tile: Dictionary) -> int:
	var riichi_targets: Array = _riichi_opponents(player_idx)
	if riichi_targets.is_empty():
		return _discard_safety_score_for_all_opponents(player_idx, tile)
	var total: int = 0
	for target: int in riichi_targets:
		var weight: int = 1
		if target == dealer:
			weight = 3
		elif player_idx == dealer and target == 0:
			weight = 3
		total += _discard_safety_score_against(target, tile) * weight
	return total

func _discard_safety_score_against(target_idx: int, tile: Dictionary) -> int:
	if _is_genbutsu(target_idx, tile.id):
		return 1000
	if _is_complete_suji_tile(tile.id):
		var visible: int = min(_visible_count_for_player(target_idx, tile.id), 4)
		return 900 + visible * 20
	if _is_nakasuji(target_idx, tile.id):
		return 600
	if _is_declared_tile_half_suji(target_idx, tile.id):
		return 80
	if _is_half_suji(target_idx, tile.id):
		return 200
	return _terminal_closeness_score(tile.id)

func _is_genbutsu(target_idx: int, tile_id: int) -> bool:
	for t: Dictionary in players[target_idx].discards:
		if t.id == tile_id:
			return true
	return false

func _is_complete_suji_tile(tile_id: int) -> bool:
	if MahjongLogic.is_honor(tile_id) or tile_id in [MahjongLogic.MAN_1, MahjongLogic.MAN_9]:
		return true
	var n: int = _tile_number(tile_id)
	return n == 1 or n == 9

func _is_nakasuji(target_idx: int, tile_id: int) -> bool:
	var n: int = _tile_number(tile_id)
	if n == 4:
		return _is_genbutsu(target_idx, tile_id - 3) and _is_genbutsu(target_idx, tile_id + 3)
	if n == 5:
		return _is_genbutsu(target_idx, tile_id - 3) and _is_genbutsu(target_idx, tile_id + 3)
	if n == 6:
		return _is_genbutsu(target_idx, tile_id - 3) and _is_genbutsu(target_idx, tile_id + 3)
	return false

func _is_half_suji(target_idx: int, tile_id: int) -> bool:
	var n: int = _tile_number(tile_id)
	if n == 1:
		return _is_genbutsu(target_idx, tile_id + 3)
	if n == 2:
		return _is_genbutsu(target_idx, tile_id + 3)
	if n == 3:
		return _is_genbutsu(target_idx, tile_id + 3)
	if n == 7:
		return _is_genbutsu(target_idx, tile_id - 3)
	if n == 8:
		return _is_genbutsu(target_idx, tile_id - 3)
	if n == 9:
		return _is_genbutsu(target_idx, tile_id - 3)
	return false

func _is_declared_tile_half_suji(target_idx: int, tile_id: int) -> bool:
	var idx: int = players[target_idx].get("riichi_discard_idx", -1)
	if idx < 0 or idx >= players[target_idx].discards.size():
		return false
	var declared_id: int = players[target_idx].discards[idx].id
	return _is_half_suji(target_idx, tile_id) and abs(_tile_number(declared_id) - _tile_number(tile_id)) == 3

func _terminal_closeness_score(tile_id: int) -> int:
	var n: int = _tile_number(tile_id)
	if n == 0:
		return 120
	return 100 - abs(5 - n) * 10

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

func player_decline_tsumo() -> void:
	if phase != Phase.PLAYER_TURN: return
	var p: Dictionary = players[0]
	if p.hand.is_empty(): return
	var hand_ids: Array = MahjongLogic.get_ids(p.hand)
	if not MahjongLogic.is_complete_hand(hand_ids): return
	p.is_doujun_furiten = true
	if p.is_riichi:
		p.is_riichi_furiten = true
	_do_discard_internal(0, p.hand.size() - 1)

func player_riichi(hand_idx: int, is_open_riichi: bool = false) -> void:
	if phase != Phase.PLAYER_TURN: return
	if not _is_closed_for_riichi(players[0]): return
	if players[0].score < (2000 if is_open_riichi else 1000): return
	# 北（花牌）はリーチ宣言牌にできない
	if hand_idx >= 0 and hand_idx < players[0].hand.size() and \
			players[0].hand[hand_idx].id == MahjongLogic.NORTH: return
	_do_riichi_discard(0, hand_idx, is_open_riichi)

func prepare_player_riichi(hand_idx: int, is_open_riichi: bool = false) -> bool:
	if phase != Phase.PLAYER_TURN:
		return false
	var p: Dictionary = players[0]
	if not _is_closed_for_riichi(p) or p.is_riichi:
		return false
	if p.score < (2000 if is_open_riichi else 1000):
		return false
	if hand_idx < 0 or hand_idx >= p.hand.size():
		return false
	if p.hand[hand_idx].id == MahjongLogic.NORTH:
		return false
	var riichi_hand_ids: Array = MahjongLogic.get_ids(p.hand)
	riichi_hand_ids.remove_at(hand_idx)
	p.riichi_waiting_ids = MahjongLogic.find_waiting_tiles(riichi_hand_ids)
	p.riichi_waiting_ids.sort()
	if p.riichi_waiting_ids.is_empty():
		return false
	p.is_riichi = true
	p.is_open_riichi = is_open_riichi
	p.is_daburi = _can_daburi(0) and p.hand.size() == 14
	p.riichi_discard_idx = p.discards.size()
	p.riichi_sticks = 2 if is_open_riichi else 1
	p.score -= 1000 * int(p.riichi_sticks)
	kyotaku += int(p.riichi_sticks)
	p.hand[hand_idx]["is_riichi_tile"] = true
	_pending_player_riichi_hand_idx = hand_idx
	return true

func finish_player_riichi() -> bool:
	if _pending_player_riichi_hand_idx < 0:
		return false
	var hand_idx: int = _pending_player_riichi_hand_idx
	_pending_player_riichi_hand_idx = -1
	var p: Dictionary = players[0]
	if hand_idx < 0 or hand_idx >= p.hand.size() or not p.is_riichi:
		return false
	_do_discard_internal(0, hand_idx)
	p.is_ippatsu = true
	if p.riichi_discard_idx >= 0 and p.riichi_discard_idx < p.discards.size():
		p.discards[p.riichi_discard_idx]["is_riichi_tile"] = true
	return true

func player_ron() -> void:
	if phase != Phase.ACTION_WAIT or not action_is_ron: return
	if not action_ron_candidates.is_empty():
		_finalize_ron_candidates(action_ron_candidates, last_discard_player)
		return
	_finalize_ron(0, last_discard_player)

func player_pon(selected_hand_idx: int = -1) -> void:
	if phase != Phase.ACTION_WAIT or action_pon_from < 0: return
	_do_pon(0, action_pon_from, last_discarded_tile, selected_hand_idx)

func player_kita() -> void:
	if phase != Phase.PLAYER_TURN: return
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
			var remaining: Array = []
			if action_ron_candidates.is_empty():
				remaining.append(_pending_npc_ron_after_skip)
			else:
				for idx: int in action_ron_candidates:
					if idx != 0:
						remaining.append(idx)
			_pending_npc_ron_after_skip = -1
			_finalize_ron_candidates(remaining, last_discard_player)
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
func _do_riichi_discard(player_idx: int, hand_idx: int, is_open_riichi: bool = false) -> void:
	var p: Dictionary = players[player_idx]
	if hand_idx < 0 or hand_idx >= p.hand.size():
		return
	if is_open_riichi and p.score < 2000:
		return
	var is_daburi: bool = _can_daburi(player_idx) and p.hand.size() == 14
	var riichi_hand_ids: Array = MahjongLogic.get_ids(p.hand)
	riichi_hand_ids.remove_at(hand_idx)
	p.riichi_waiting_ids = MahjongLogic.find_waiting_tiles(riichi_hand_ids)
	p.riichi_waiting_ids.sort()
	if p.riichi_waiting_ids.is_empty():
		return
	p.is_riichi  = true
	p.is_open_riichi = is_open_riichi
	p.is_daburi  = is_daburi
	p.riichi_discard_idx = p.discards.size()
	var riichi_sticks := 2 if is_open_riichi else 1
	p.riichi_sticks = riichi_sticks
	p.score -= 1000 * riichi_sticks
	kyotaku += riichi_sticks
	p.hand[hand_idx]["is_riichi_tile"] = true
	emit_signal("riichi_declared", player_idx)
	_do_discard_internal(player_idx, hand_idx)
	# is_ippatsu は _do_discard_internal の後にセットする
	# （_do_discard_internal 内で is_ippatsu = false されるため、後に上書きが必要）
	players[player_idx].is_ippatsu = true
	players[player_idx].discards[players[player_idx].riichi_discard_idx]["is_riichi_tile"] = true

func _do_discard_internal(player_idx: int, hand_idx: int, forced_tsumogiri: bool = false) -> void:
	if hand_idx < 0 or hand_idx >= players[player_idx].hand.size():
		push_error("Invariant violation [%s]: invalid discard index player=%d hand_idx=%d hand_size=%d" % ["discard", player_idx, hand_idx, players[player_idx].hand.size()])
		return
	var before_hand_size: int = players[player_idx].hand.size()
	var tile: Dictionary = players[player_idx].hand[hand_idx]
	if forced_tsumogiri:
		tile["is_forced_tsumogiri"] = true
	_mark_open_riichi_forced_houjuu(player_idx, tile)
	players[player_idx].hand.remove_at(hand_idx)
	players[player_idx].discards.append(tile)
	if player_idx >= 0 and player_idx < daburi_allowed.size():
		daburi_allowed[player_idx] = false
	if player_idx >= 0 and player_idx < first_round_win_allowed.size():
		first_round_win_allowed[player_idx] = false
	if players[player_idx].hand.size() != before_hand_size - 1:
		push_error("Invariant violation [%s]: discard must remove exactly one tile player=%d before=%d after=%d" % ["discard", player_idx, before_hand_size, players[player_idx].hand.size()])
	players[player_idx].is_ippatsu = false
	players[player_idx].pon_forbidden_id = -1  # 捨て牌後に食い変え禁止をリセット
	last_discarded_tile = tile
	last_discard_player = player_idx
	if _recorder:
		_recorder.record_discard(player_idx, tile, tile.get("is_riichi_tile", false))
	phase = Phase.ACTION_WAIT
	emit_signal("tile_discarded", player_idx, tile)
	_assert_kyoku_invariants("after_discard")
	_check_actions_after_discard(player_idx, tile)

func player_riichi_tsumogiri() -> void:
	if phase != Phase.PLAYER_TURN: return
	var p: Dictionary = players[0]
	if not p.is_riichi or p.hand.is_empty(): return
	_do_discard_internal(0, p.hand.size() - 1, true)

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
	if _recorder:
		_recorder.record_kita(player_idx, _kita_tile,
			players[player_idx].hand.duplicate(true) if not players[player_idx].is_npc else [])
	if player_idx == 0:
		phase = Phase.PLAYER_TURN
	else:
		current_player = player_idx
		phase = Phase.NPC_TURN
	emit_signal("tile_drawn", player_idx)
	if resume_npc and players[player_idx].is_npc:
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
	_cancel_all_daburi_rights()
	_cancel_all_first_round_win_rights()
	for pp: Dictionary in players:
		pp.is_ippatsu = false
	var kan_tiles: Array = []
	for i in range(p.hand.size() - 1, -1, -1):
		if p.hand[i].id == kan_id:
			kan_tiles.append(p.hand[i])
			p.hand.remove_at(i)
	p.naki.append({"type": "ankan", "tile_ids": [kan_id, kan_id, kan_id, kan_id], "tiles": kan_tiles})
	if _recorder:
		_recorder.record_meld(player_idx, "ankan", kan_id, -1)
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
		if int(p.get("pao_suukantsu_from", -1)) < 0:
			for m: Dictionary in p.naki:
				if m.get("type", "") == "kakan":
					p.pao_suukantsu_from = int(m.get("from_player", -1))
					break
	if player_idx == 0:
		phase = Phase.PLAYER_TURN
	else:
		current_player = player_idx
		phase = Phase.NPC_TURN
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
	if player_idx == 0:
		phase = Phase.PLAYER_TURN
	else:
		current_player = player_idx
		phase = Phase.NPC_TURN
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
	_cancel_all_daburi_rights()
	_cancel_all_first_round_win_rights()
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
	if _recorder:
		_recorder.record_meld(player_idx, "pon", tile.id, from_idx)
	_update_pao_after_meld(player_idx, from_idx)
	p.is_menzen = false
	p.pon_forbidden_id = tile.id  # 食い変え禁止: ポン直後に同種牌は切れない
	# ポンされた捨て牌にフラグを立てる（河に残るが黒マスクで覆う）
	_mark_taken_discard(from_idx, tile, "pon")
	action_minkan_possible = false
	emit_signal("naki_done", player_idx)
	_assert_kyoku_invariants("after_pon")
	if player_idx == 0:
		phase = Phase.AFTER_PON
		emit_signal("turn_started", player_idx)
	else:
		get_tree().create_timer(NPC_THINK_SEC * 0.5).timeout.connect(
			func(): _npc_pon_discard(player_idx), CONNECT_ONE_SHOT)

func _npc_pon_discard(player_idx: int) -> void:
	var p: Dictionary = players[player_idx]
	if p.hand.is_empty(): return
	_do_discard_internal(player_idx, _choose_npc_safe_discard_index(player_idx))

func _update_pao_after_meld(player_idx: int, from_idx: int) -> void:
	if from_idx < 0 or from_idx == player_idx:
		return
	var p: Dictionary = players[player_idx]
	if int(p.get("pao_daisangen_from", -1)) < 0 and _dragon_triplet_count(p) >= 3:
		p.pao_daisangen_from = from_idx
	if int(p.get("pao_suukantsu_from", -1)) < 0 and MahjongLogic._count_kantsu(p.naki) >= 4:
		p.pao_suukantsu_from = from_idx

func _dragon_triplet_count(p: Dictionary) -> int:
	var count := 0
	var hand_counts := {}
	for t: Dictionary in p.hand:
		hand_counts[t.id] = hand_counts.get(t.id, 0) + 1
	for id: int in [MahjongLogic.HAKU, MahjongLogic.HATSU, MahjongLogic.CHUN]:
		if int(hand_counts.get(id, 0)) >= 3:
			count += 1
	for m: Dictionary in p.naki:
		var ids: Array = m.get("tile_ids", [])
		if ids.size() >= 3 and ids[0] in [MahjongLogic.HAKU, MahjongLogic.HATSU, MahjongLogic.CHUN]:
			count += 1
	return count

func _mark_taken_discard(from_idx: int, tile: Dictionary, reason: String) -> void:
	if from_idx < 0 or from_idx >= players.size():
		push_error("Invariant violation [%s]: invalid from_idx=%d" % [reason, from_idx])
		return
	var discards: Array = players[from_idx].discards
	for i in range(discards.size() - 1, -1, -1):
		var d: Dictionary = discards[i]
		if d.get("is_taken", false):
			continue
		if d.get("id", -1) == tile.get("id", -2) and _tile_variant_key(d) == _tile_variant_key(tile):
			d["is_taken"] = true
			return
	push_error("Invariant violation [%s]: called tile not found in discards from=%d tile=%s" % [reason, from_idx, MahjongLogic.get_tile_name(tile)])

func _tile_variant_key(tile: Dictionary) -> String:
	return str(tile.get("is_red", false)) + ":" + str(tile.get("is_gold", false)) + ":" + str(tile.get("is_haku_pochi", false))

func _assert_kyoku_invariants(context: String) -> void:
	if players.is_empty() or phase == Phase.GAME_OVER:
		return
	if last_discard_player >= 0:
		if last_discard_player >= players.size():
			push_error("Invariant violation [%s]: last_discard_player out of range=%d" % [context, last_discard_player])
		elif last_discarded_tile.is_empty():
			push_error("Invariant violation [%s]: last_discarded_tile is empty" % context)
	for i in range(players.size()):
		var p: Dictionary = players[i]
		var hand_count: int = p.get("hand", []).size()
		if hand_count < 0 or hand_count > 14:
			push_error("Invariant violation [%s]: impossible hand size player=%d hand=%d" % [context, i, hand_count])
		var total_in_hand_area: int = hand_count + _meld_tile_count(p.get("naki", []))
		if total_in_hand_area < 10 or total_in_hand_area > 14:
			push_error("Invariant violation [%s]: hand/meld tile total out of range player=%d hand=%d meld_tiles=%d total=%d" % [context, i, hand_count, _meld_tile_count(p.get("naki", [])), total_in_hand_area])

func _meld_tile_count(melds: Array) -> int:
	var count := 0
	for meld: Dictionary in melds:
		var tile_ids: Array = meld.get("tile_ids", [])
		if not tile_ids.is_empty():
			count += tile_ids.size()
		else:
			count += (meld.get("tiles", []) as Array).size()
	return count

# ============================================================
# 捨て後のアクションチェック
# ============================================================
func _check_actions_after_discard(discarder_idx: int, tile: Dictionary) -> void:
	var player_can_ron: bool = false
	var open_riichi_blocked_player_ron: bool = false
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
					if _can_ron_against_open_riichi(0, discarder_idx, tile):
						player_can_ron = true
					else:
						open_riichi_blocked_player_ron = true
			# 当たり牌が出たがロンできない（フリテン or 役なし）→ 同順フリテン
			if not player_can_ron and not open_riichi_blocked_player_ron:
				players[0].is_doujun_furiten = true

	var ron_candidates: Array = []
	for step in range(1, players.size()):
		var candidate_idx: int = (discarder_idx + step) % players.size()
		if candidate_idx == discarder_idx:
			continue
		if candidate_idx == 0:
			if player_can_ron:
				ron_candidates.append(candidate_idx)
		elif _npc_can_ron(candidate_idx, discarder_idx, tile):
			ron_candidates.append(candidate_idx)
	if not ron_candidates.is_empty():
		if 0 in ron_candidates:
			_pending_npc_ron_after_skip = -1
			for idx: int in ron_candidates:
				if idx != 0:
					_pending_npc_ron_after_skip = idx
					break
			action_winner_idx = 0
			action_ron_candidates = ron_candidates.duplicate()
			action_is_ron = true
			action_pon_from = -1
			action_minkan_possible = false
			phase = Phase.ACTION_WAIT
			emit_signal("ron_opportunity", 0, discarder_idx, tile)
		else:
			_finalize_ron_candidates(ron_candidates, discarder_idx)
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
			phase = Phase.ACTION_WAIT
			action_is_ron = false
			action_pon_from = -1
			action_minkan_possible = false
			get_tree().create_timer(NPC_THINK_SEC * 0.3).timeout.connect(
				func(): _do_minkan(i, discarder_idx, tile), CONNECT_ONE_SHOT)
			return
		if _npc_wants_pon(i, tile):
			phase = Phase.ACTION_WAIT
			action_is_ron = false
			action_pon_from = -1
			action_minkan_possible = false
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

func _npc_can_ron(npc_idx: int, discarder_idx: int, tile: Dictionary) -> bool:
	var p: Dictionary = players[npc_idx]
	if _is_hokkyoku_npc(npc_idx) and not p.is_riichi and not _is_renhou_ron(npc_idx):
		return false
	var hand_ids: Array = MahjongLogic.get_ids(p.hand)
	if tile.id not in MahjongLogic.find_waiting_tiles(hand_ids):
		return false
	if MahjongLogic.is_furiten(hand_ids, MahjongLogic.get_ids(p.discards)):
		return false
	if not _can_ron_against_open_riichi(npc_idx, discarder_idx, tile):
		return false
	var test_hand: Array = hand_ids.duplicate()
	test_hand.append(tile.id)
	test_hand.sort()
	var ctx: Dictionary = _build_context(npc_idx, false, tile.id)
	var yaku: Array = MahjongLogic.check_yaku(test_hand, ctx)
	return not yaku.is_empty()

func _npc_wants_pon(npc_idx: int, tile: Dictionary) -> bool:
	if _is_hokkyoku_npc(npc_idx):
		return false
	if _npc_must_fold_before_actions(npc_idx):
		return false
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

func _can_ron_against_open_riichi(winner_idx: int, discarder_idx: int, tile: Dictionary) -> bool:
	var winner: Dictionary = players[winner_idx]
	if not winner.get("is_open_riichi", false):
		return true
	if tile.get("is_forced_tsumogiri", false) and players[discarder_idx].get("is_riichi", false):
		return true
	return tile.get("open_riichi_forced_houjuu", false)

func _mark_open_riichi_forced_houjuu(discarder_idx: int, tile: Dictionary) -> void:
	tile["open_riichi_forced_houjuu"] = false
	for i in range(players.size()):
		if i == discarder_idx:
			continue
		if not players[i].get("is_open_riichi", false):
			continue
		if _all_discardable_tiles_are_open_riichi_waits(discarder_idx, i):
			tile["open_riichi_forced_houjuu"] = true
			return

func _all_discardable_tiles_are_open_riichi_waits(discarder_idx: int, open_riichi_idx: int) -> bool:
	var waits: Array = players[open_riichi_idx].get("riichi_waiting_ids", [])
	if waits.is_empty():
		return false
	var has_discardable := false
	for t: Dictionary in players[discarder_idx].hand:
		if t.id == MahjongLogic.NORTH:
			continue
		has_discardable = true
		if t.id not in waits:
			return false
	return has_discardable

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
	if result.has("winning_display_tiles") and not result["winning_display_tiles"].is_empty():
		result["winning_display_tiles"][result["winning_display_tiles"].size() - 1] = MahjongLogic.make_tile(45, false, false, true)
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

func _finalize_ron_candidates(winner_indices: Array, loser_idx: int) -> void:
	action_ron_candidates = []
	if winner_indices.is_empty():
		_next_turn(loser_idx)
		return
	winner_indices = _sort_ron_winners_by_loser_order(winner_indices, loser_idx)
	var results: Array = []
	var head_winner: int = int(winner_indices[0])
	var original_kyotaku: int = kyotaku
	for wi in winner_indices:
		var winner_idx: int = int(wi)
		var winner: Dictionary = players[winner_idx]
		winner.hand.append(last_discarded_tile)
		var hand_ids: Array = MahjongLogic.get_ids(winner.hand)
		if MahjongLogic.is_complete_hand(hand_ids):
			var context: Dictionary = _build_context(winner_idx, false, last_discarded_tile.id)
			if _is_chankan_ron:
				context["is_chankan"] = true
			var yaku: Array = MahjongLogic.check_yaku(hand_ids, context)
			if not yaku.is_empty():
				if winner.get("is_open_riichi", false) \
						and last_discarded_tile.get("open_riichi_forced_houjuu", false) \
						and not last_discarded_tile.get("is_forced_tsumogiri", false):
					var actual_yakuman: Array = []
					for y: Dictionary in yaku:
						if int(y.get("han", 0)) >= 13:
							actual_yakuman.append(y)
					yaku = [{"name": "オープン立直（手詰まり放銃）", "han": 13, "no_yakuman_chip": true}]
					yaku.append_array(actual_yakuman)
				var result: Dictionary = _build_win_result(winner_idx, false, loser_idx, yaku)
				if winner_idx != head_winner:
					result["honba"] = 0
					result["honba_bonus"] = 0
					result["kyotaku_before_collection"] = 0
				results.append(result)
		winner.hand.pop_back()
	if results.is_empty():
		_is_chankan_ron = false
		_next_turn(loser_idx)
		return
	_pending_kakan_player = -1
	_pending_ankan_player = -1
	_pending_kita_player = -1
	_pending_npc_ron_after_skip = -1
	_is_chankan_ron = false
	for r: Dictionary in results:
		if int(r.get("winner_idx", -1)) != head_winner:
			kyotaku = 0
		_apply_score(r)
	kyotaku = 0
	var main_result: Dictionary = results[0]
	main_result["double_ron_results"] = results
	main_result["is_double_ron"] = results.size() >= 2
	main_result["kyotaku_before_collection"] = original_kyotaku
	main_result["score_after"] = _snapshot_scores()
	_process_kyoku_end(main_result)

func _sort_ron_winners_by_loser_order(winner_indices: Array, loser_idx: int) -> Array:
	var ordered: Array = winner_indices.duplicate()
	ordered.sort_custom(func(a, b) -> bool:
		return _ron_winner_priority_from_loser(int(a), loser_idx) < _ron_winner_priority_from_loser(int(b), loser_idx)
	)
	return ordered

func _ron_winner_priority_from_loser(winner_idx: int, loser_idx: int) -> int:
	for step in range(1, players.size()):
		if (loser_idx + step) % players.size() == winner_idx:
			return step
	return 99

func _finalize_ron(winner_idx: int, loser_idx: int) -> void:
	action_ron_candidates = []
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
	if winner.get("is_open_riichi", false) \
			and last_discarded_tile.get("open_riichi_forced_houjuu", false) \
			and not last_discarded_tile.get("is_forced_tsumogiri", false):
		var actual_yakuman: Array = []
		for y: Dictionary in yaku:
			if int(y.get("han", 0)) >= 13:
				actual_yakuman.append(y)
		yaku = [{"name": "オープン立直（手詰まり放銃）", "han": 13, "no_yakuman_chip": true}]
		yaku.append_array(actual_yakuman)
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
		"is_open_riichi":  p.is_open_riichi,
		"is_daburi":       p.is_daburi,
		"is_ippatsu":      p.is_ippatsu,
		"is_rinshan":      is_tsumo and _drew_from_rinshan,
		"is_chankan":      false,
		"is_haitei":       is_tsumo and wall.is_empty(),
		"is_houtei":       (not is_tsumo) and wall.is_empty(),
		"is_tenhou":       player_idx == dealer and is_tsumo and _can_first_round_win(player_idx) and p.naki.is_empty() and not p.is_riichi,
		"is_chiihou":      player_idx != dealer and is_tsumo and _can_first_round_win(player_idx),
		"is_renhou":       (not is_tsumo) and _is_renhou_ron(player_idx),
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
	var has_yakuman_chip_yaku: bool = false
	for y: Dictionary in yaku:
		if int(y.get("han", 0)) >= 13 and not y.get("no_yakuman_chip", false):
			has_yakuman_chip_yaku = true
			break
	var han: int = 13 if is_yakuman else MahjongLogic.count_han(yaku)
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
		for nt: Dictionary in winner.nukita:
			if nt.id == dora_id:
				han += 1; regular_dora += 1
			if ura_id >= 0 and nt.id == ura_id:
				han += 1; ura_count += 1

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
	var kita_normal: int = kita_count - kita_red
	if kita_normal > 0:
		yaku.append({"name": "北×" + str(kita_normal), "han": kita_normal})
	if kita_red > 0:
		yaku.append({"name": "北（赤）", "han": kita_red})

	var chips_per: int = _calc_chips(winner, is_tsumo, winner.is_ippatsu, has_yakuman_chip_yaku, ura_count)
	var score_data: Dictionary = MahjongLogic.calc_score(han, is_parent, is_tsumo)
	var pao_player_idx: int = _get_pao_player_idx(winner, yaku)
	var winning_display_tiles: Array = _build_winning_display_tiles(winner)
	var winning_display_melds: Array = _build_winning_display_melds(winner)
	return {
		"winner_idx": winner_idx, "winner_name": winner.name,
		"winner_npc_id": str(winner.get("npc_id", "")),
		"is_tsumo": is_tsumo, "loser_idx": loser_idx,
		"han": han, "is_parent": is_parent,
		"yaku": yaku, "score_data": score_data,
		"winning_display_tiles": winning_display_tiles,
		"winning_display_melds": winning_display_melds,
		"nukita_count": winner.nukita.size(),
		"nukita_tiles": winner.nukita.duplicate(true),
		"honba": honba, "honba_bonus": honba * 2000,
		"kyotaku_before_collection": kyotaku,
		"draw": false,
		"chips_per_player": chips_per,
		"ura_count": ura_count,
		"is_yakuman": is_yakuman,
		"pao_player_idx": pao_player_idx,
		"score_before": _kyoku_start_scores.duplicate(),
	}

func _get_pao_player_idx(winner: Dictionary, yaku: Array) -> int:
	for y: Dictionary in yaku:
		var name := str(y.get("name", ""))
		if name == "大三元" and int(winner.get("pao_daisangen_from", -1)) >= 0:
			return int(winner.get("pao_daisangen_from", -1))
		if name == "四槓子" and int(winner.get("pao_suukantsu_from", -1)) >= 0:
			return int(winner.get("pao_suukantsu_from", -1))
	return -1

func _build_winning_display_tiles(winner: Dictionary) -> Array:
	var concealed: Array = winner.hand.duplicate(true)
	var winning_tile: Dictionary = {}
	if not concealed.is_empty():
		winning_tile = concealed.pop_back()
	var display_tiles: Array = concealed
	display_tiles.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("id", 0)) < int(b.get("id", 0))
	)
	if not winning_tile.is_empty():
		display_tiles.append(winning_tile)
	return display_tiles

func _build_winning_display_melds(winner: Dictionary) -> Array:
	var melds: Array = []
	for meld: Dictionary in winner.naki:
		melds.append(meld.duplicate(true))
	return melds

func _apply_score(result: Dictionary) -> void:
	var winner_idx: int = result.winner_idx
	var is_tsumo: bool  = result.is_tsumo
	var sd: Dictionary  = result.score_data
	var honba_bonus: int = result.honba_bonus
	var pao_idx: int = int(result.get("pao_player_idx", -1))
	if pao_idx >= 0 and pao_idx != winner_idx:
		if is_tsumo:
			var total_pay: int = int(sd.get("total", 0)) + honba * 2000
			players[pao_idx].score -= total_pay
			players[winner_idx].score += total_pay
		else:
			var total_ron: int = int(sd.get("total", 0)) + honba_bonus
			var loser_idx: int = int(result.get("loser_idx", -1))
			if loser_idx == pao_idx:
				players[pao_idx].score -= total_ron
				players[winner_idx].score += total_ron
			else:
				var pao_pay: int = int(ceil(float(total_ron) / 2.0 / 1000.0)) * 1000
				var loser_pay: int = total_ron - pao_pay
				players[pao_idx].score -= pao_pay
				if loser_idx >= 0:
					players[loser_idx].score -= loser_pay
				players[winner_idx].score += total_ron
	elif is_tsumo:
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
	result["score_after"] = _snapshot_scores()

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
	if not result.has("player_winds"):
		result["player_winds"] = _snapshot_player_winds()
	_record_player_stats(result)

	# 流局テンパイ精算
	if result.get("draw", false):
		if not result.has("score_before"):
			result["score_before"] = _kyoku_start_scores.duplicate()
		var tenpai_info: Dictionary = _apply_tenpai_payments()
		result["tenpai_info"] = tenpai_info
		result["score_after"] = _snapshot_scores()

	# 飛び判定
	var bust_indices: Array = _check_bust()
	if not bust_indices.is_empty():
		_pending_match_end = true
		var bust_idx: int = bust_indices[0]
		result["bust_player_idx"] = bust_idx
		result["bust_player_indices"] = bust_indices
		# 飛び賞チップ。和了以外で飛んだ場合は上家取り。
		if not result.get("draw", false):
			var w_idx: int = result.get("winner_idx", -1)
			if w_idx >= 0:
				for bi: int in bust_indices:
					player_chips[w_idx] += 2
					player_chips[bi] -= 2
		else:
			for bi: int in bust_indices:
				var receiver: int = (bi - 1 + players.size()) % players.size()
				player_chips[receiver] += 2
				player_chips[bi] -= 2

	if not _pending_match_end:
		var winner_idx: int = result.get("winner_idx", -1)
		var dealer_wins: bool = (not result.get("draw", false)) and (winner_idx == dealer)
		var draw_dealer_tenpai: bool = result.get("draw", false) and _is_player_tenpai(dealer)
		if _is_oorasu():
			_apply_oorasu_end_policy(result, dealer_wins or draw_dealer_tenpai)
		else:
			_advance_kyoku_state(dealer_wins or draw_dealer_tenpai, result.get("draw", false))

	result["match_will_end"] = _pending_match_end
	result["oorasu_choice_required"] = _pending_oorasu_player_choice
	if _recorder:
		_recorder.end_round(result)
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

func _is_oorasu() -> bool:
	return round_wind == MahjongLogic.SOUTH and kyoku == 3

func _apply_oorasu_end_policy(result: Dictionary, dealer_continues: bool) -> void:
	if dealer_continues:
		if dealer == 0:
			_pending_oorasu_player_choice = true
		elif _is_top_score(dealer):
			_pending_match_end = true
		else:
			honba += 1
	else:
		_pending_match_end = true

func _is_top_score(player_idx: int) -> bool:
	var score: int = int(players[player_idx].score)
	for i in range(players.size()):
		if i != player_idx and int(players[i].score) > score:
			return false
	return true

func _find_dealer_index() -> int:
	for i in range(players.size()):
		if int(players[i].wind) == MahjongLogic.EAST:
			return i
	return 0

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
	if _recorder:
		var final_scores: Array = players.map(func(p2: Dictionary) -> int: return p2.score)
		_recorder.end_game(final_scores, player_chips.duplicate())
		_recorder = null

# ============================================================
# 流局
# ============================================================
func _end_round_draw() -> void:
	for i in range(players.size()):
		if _is_nagashi_yakuman_player(i):
			var result: Dictionary = _build_win_result(i, true, -1, [{"name": "流し役満", "han": 13}])
			_apply_score(result)
			emit_signal("tsumo_declared", i, result)
			_process_kyoku_end(result)
			return
	var result: Dictionary = {"draw": true, "winner_idx": -1, "score_before": _kyoku_start_scores.duplicate()}
	_process_kyoku_end(result)

func _is_nagashi_yakuman_player(player_idx: int) -> bool:
	var p: Dictionary = players[player_idx]
	if p.get("is_riichi", false):
		return false
	if not p.get("naki", []).is_empty():
		return false
	if p.get("discards", []).is_empty():
		return false
	for d: Dictionary in p.discards:
		if d.get("is_taken", false):
			return false
		if not MahjongLogic.is_yaochuupai(int(d.get("id", -1))):
			return false
	return true

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
	if players.is_empty():
		return false
	var p: Dictionary = players[0]
	if not _is_closed_for_riichi(p) or p.is_riichi or p.score < 1000: return false
	return not get_riichi_selectable_indices().is_empty()

func can_player_open_riichi() -> bool:
	if players.is_empty():
		return false
	var p: Dictionary = players[0]
	if p.score < 2000:
		return false
	return can_player_riichi()

func _is_closed_for_riichi(p: Dictionary) -> bool:
	for meld: Dictionary in p.get("naki", []):
		if meld.get("type", "") != "ankan":
			return false
	return true

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
	if _is_hokkyoku_npc(npc_idx):
		return false
	if _npc_must_fold_before_actions(npc_idx):
		return false
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
	_cancel_all_daburi_rights()
	_cancel_all_first_round_win_rights()
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
	if _recorder:
		_recorder.record_meld(player_idx, "minkan", tile.id, from_idx)
	_update_pao_after_meld(player_idx, from_idx)
	p.is_menzen = false
	_mark_taken_discard(from_idx, tile, "minkan")
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
	if player_idx == 0:
		phase = Phase.PLAYER_TURN
	else:
		current_player = player_idx
		phase = Phase.NPC_TURN
	_assert_kyoku_invariants("after_minkan")
	emit_signal("naki_done", player_idx)
	emit_signal("tile_drawn", player_idx)
	if player_idx == 0:
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
	_cancel_all_daburi_rights()
	_cancel_all_first_round_win_rights()
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
	if _recorder:
		_recorder.record_meld(player_idx, "kakan", kakan_tile_id, -1)
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
	if player_idx == 0:
		phase = Phase.PLAYER_TURN
	else:
		current_player = player_idx
		phase = Phase.NPC_TURN
	emit_signal("kakan_done", player_idx)
	emit_signal("tile_drawn", player_idx)
	if player_idx != 0:
		get_tree().create_timer(NPC_THINK_SEC).timeout.connect(
			func(): _npc_turn(player_idx), CONNECT_ONE_SHOT)

# ============================================================
# デバッグ用
# ============================================================
func debug_set_hand(hand_tiles_13: Array, draw_tile: Dictionary = {}, next_draw_tile: Dictionary = {}, target_player: int = 0) -> void:
	var p: Dictionary = players[target_player]
	var was_riichi: bool = p.get("is_riichi", false)
	var was_daburi: bool = p.get("is_daburi", false)
	var was_open_riichi: bool = p.get("is_open_riichi", false)
	var was_ippatsu: bool = p.get("is_ippatsu", false)
	var old_riichi_discard_idx: int = int(p.get("riichi_discard_idx", -1))
	p.hand.clear()
	p.naki.clear()
	p.is_menzen = true
	p.is_riichi = false
	p.is_daburi = false
	p.is_ippatsu = false
	p.is_open_riichi = false
	p.riichi_waiting_ids.clear()
	p.riichi_discard_idx = -1
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
	if was_riichi:
		var riichi_base_hand: Array = p.hand.duplicate()
		if draw_id > 0 and not riichi_base_hand.is_empty():
			riichi_base_hand.pop_back()
		p.is_riichi = true
		p.is_daburi = was_daburi
		p.is_open_riichi = was_open_riichi
		p.is_ippatsu = was_ippatsu
		p.riichi_discard_idx = old_riichi_discard_idx
		p.riichi_waiting_ids = MahjongLogic.find_waiting_tiles(MahjongLogic.get_ids(riichi_base_hand))
		p.riichi_waiting_ids.sort()
	if target_player >= 0:
		var next_id: int = next_draw_tile.get("id", 0)
		if next_id > 0:
			# draw_id > 0 の場合：プレイヤーが捨てた後にNPC2人が引くので wall[2] が次順ツモ
			# draw_id == 0 の場合：次にプレイヤーが引く位置は wall[0]
			var wall_idx: int = debug_next_draw_wall_index(target_player, draw_id > 0)
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

func debug_next_draw_wall_index(target_player: int, has_current_draw_tile: bool = false) -> int:
	if players.is_empty():
		return 0
	if has_current_draw_tile:
		return max(players.size() - 1, 0)
	if target_player == 0:
		return 0
	var distance: int = (target_player - current_player + players.size()) % players.size()
	if distance == 0:
		distance = players.size()
	return max(distance - 1, 0)

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
