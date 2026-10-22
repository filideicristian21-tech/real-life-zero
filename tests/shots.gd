extends Node
## Cattura screenshot reali dal gioco (usato con xvfb-run + renderer opengl3). Non è un test.
var out_dir := "/workspace/reallife-shots"

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	var main = load("res://scenes/main.tscn").instantiate()
	Game.headless_test = true
	get_tree().root.add_child.call_deferred(main)
	await get_tree().create_timer(0.5).timeout
	SaveSystem.save_path = "user://shots_save.json"
	SaveSystem.backup_path = "user://shots_backup.json"
	Game.new_game()
	main.ui.close_modal()
	var p: Player = main.player
	var shots := [
		["01_casa_interno", Vector3(-51.5, 0.12, -23.0), 2.4, "07:10", -0.35],
		["02_via_dei_tigli", Vector3(-45.3, 0.12, -14.0), PI, "08:30", -0.25],
		["03_piazza_fontana", Vector3(10.0, 0.12, -11.0), PI, "10:15", -0.2],
		["04_bar_esterno", Vector3(5.0, 0.12, -33.0), PI, "09:00", -0.18],
		["05_bar_interno", Vector3(8.0, 0.12, -43.0), PI + 0.4, "09:30", -0.3],
		["06_market_esterno", Vector3(18.0, 0.12, -2.0), 0.0, "11:00", -0.2],
		["07_market_interno", Vector3(15.8, 0.12, 9.0), 0.3, "11:30", -0.3],
		["08_fermata_bus", Vector3(-21.0, 0.12, -1.0), PI + 0.2, "07:20", -0.2],
		["09_via_roma_tramonto", Vector3(-60.0, 0.12, 5.6), -PI / 2.0, "19:30", -0.15],
		["10_piazza_notte", Vector3(10.0, 0.12, -10.0), PI, "22:30", -0.2],
		["10b_parcheggio", Vector3(-16.0, 0.12, -41.0), PI - 0.5, "16:00", -0.4],
		["16_banca_boutique_palestra", Vector3(52.0, 0.12, 4.6), PI, "10:30", -0.12],
		["17_trattoria_distributore", Vector3(44.0, 0.12, -4.8), 0.0, "12:40", -0.12],
		["18_autosalone", Vector3(70.0, 0.12, -1.5), 0.25, "15:00", -0.2],
		["19_campanile", Vector3(4.0, 0.12, -14.0), PI + 0.36, "17:45", 0.22],
		["19b_via_roma_alba", Vector3(-30.0, 0.12, 4.8), -PI / 2.0 - 0.15, "06:20", -0.1],
	]
	Game.skip_tutorial()
	for s in shots:
		var hm: int = Data.hhmm_to_min(s[3])
		GameTime.total_minutes = float((GameTime.day() - 1) * 1440 + hm)
		GameTime.running = false
		p.teleport(s[1], s[2])
		p.cam_pitch_node.rotation.x = s[4]
		main.day_night.update(true)
		for i in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/%s.png" % [out_dir, s[0]])
		print("[stats] ", s[0], " draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " objects=", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), " primitives=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		print("shot ", s[0])
	# UI: telefono e negozio
	GameTime.total_minutes = float(Data.hhmm_to_min("11:30"))
	p.teleport(Vector3(16.0, 0.12, 12.0), PI)
	main.ui.open_shop_panel("Pane e colazione", ["pane_500g", "latte_1l", "biscotti", "banane_1kg"])
	for i in 10: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir + "/11_ui_market.png")
	main.ui.close_modal()
	main.ui.toggle_phone()
	for i in 6: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir + "/12_ui_telefono.png")
	main.ui.phone_open_app("conto")
	for i in 6: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir + "/13_ui_conto.png")
	main.ui.close_modal()
	for i in 4: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir + "/14_hud.png")
	for app in [["banca", "spese", "20_app_banca_spese"], ["lavori", "offerte", "21_app_lavori"], ["casa", "cerca", "22_app_casa"], ["auto", "conc", "23_app_auto"]]:
		main.ui.toggle_phone()
		main.ui.life_ui.tabs[app[0]] = app[1]
		main.ui.phone_open_app(app[0])
		for i in 6: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir + "/" + app[2] + ".png")
		main.ui.close_modal()
	# guida: auto di prova consegnata davanti all'Autosalone
	Economy.earn(500000, "Prova screenshot", "test")
	GameTime.total_minutes = float(Data.hhmm_to_min("10:00"))
	Life.buy_car("utilitaria_ginestra", false, Vector3(30.0, 0.02, 0.95), -PI / 2.0)
	Life.buy_insurance()
	main.player.teleport(Vector3(30.0, 0.12, -1.5), 0.0)
	main.player_car.enter_car()
	main.player.cam_yaw_node.rotation.y = -PI / 2.0 + 0.5
	main.player.cam_pitch_node.rotation.x = -0.25
	main.day_night.update(true)
	for i in 10: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir + "/24_guida.png")
	main.player_car.speed = 0.0
	main.player_car.exit_car()
	main.ui.show_main_menu()
	for i in 6: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir + "/00_menu.png")
	Game.new_game()
	main.ui.close_modal()
	Jobs.hire()
	GameTime.total_minutes = float(1440 + Data.hhmm_to_min("06:30"))
	main.ui.start_shift_ui()
	for i in 30: await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir + "/15_turno_bar.png")
	Jobs.abandon_shift()
	SaveSystem.delete_all()
	get_tree().quit()
