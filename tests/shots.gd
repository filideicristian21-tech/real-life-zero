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
