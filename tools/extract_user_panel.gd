extends Node
## 从原开始菜单 01StartMenu.tscn 提取 User 节点为独立子场景 scenes/start_menu/user_panel.tscn
## 供新的开始界面/主菜单复用（用户管理：选择/新建/重命名/删除）。
## 注意：必须以游戏模式运行本场景（headless 运行 res://tools/extract_user_panel.tscn），
## 因为 --script 模式不会注册 autoload 全局标识符，导致 user.gd 等脚本编译失败无法附加。

func _ready() -> void:
	var menu: PackedScene = load("res://scenes/main/01StartMenu.tscn")
	if menu == null:
		print("ERR: 01StartMenu.tscn 加载失败")
		get_tree().quit(1)
		return
	var root: Node = menu.instantiate()
	var user: Node = root.get_node("User")
	root.remove_child(user)
	user.name = "UserPanel"

	## 重新设置 owner：pack 只序列化 owner 指向打包根节点的子树（根节点自身无需设置）
	for n in user.find_children("*", "", true, false):
		n.owner = user

	print("root script before = ", user.script)
	var packed := PackedScene.new()
	var pack_err: Error = packed.pack(user)
	print("pack err = ", pack_err)
	if pack_err != OK:
		print("pack 失败: ", pack_err)
		user.free()
		root.free()
		get_tree().quit(1)
		return

	var dir := "res://scenes/start_menu"
	DirAccess.make_dir_recursive_absolute(dir)
	var save_err: Error = ResourceSaver.save(packed, dir + "/user_panel.tscn")
	print("save err = ", save_err)
	if save_err == OK:
		print("OK: user_panel.tscn 已保存")
	else:
		user.free()
		root.free()
		get_tree().quit(1)
		return
	user.free()
	root.free()
	get_tree().quit()
