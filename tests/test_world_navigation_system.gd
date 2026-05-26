extends RefCounted

const NavigationSystemScript = preload("res://scripts/systems/world_navigation_system.gd")

func run(assertions) -> void:
	var nav = NavigationSystemScript.new()
	# 初始化一个 1000x1000 的网格，步长为 50
	nav.setup_grid(Vector2(1000, 1000), 50)
	
	# 测试基本寻路：从 (0,0) 到 (100,100)
	var path = nav.get_path_to_point(Vector2(0, 0), Vector2(100, 100))
	assertions.assert_true(path.size() > 0, "基本寻路：应该能找到路径")
	assertions.assert_eq(path[0], Vector2(0, 0), "路径起点应为 (0,0)")
	# 50px 步长，(100,100) 应该是网格点
	assertions.assert_eq(path[-1], Vector2(100, 100), "路径终点应为 (100,100)")

	# 测试阻挡逻辑
	# 假设我们在 (50, 50) 设置一个阻挡
	nav.set_point_disabled(Vector2(50, 50), true)
	var path_blocked = nav.get_path_to_point(Vector2(0, 0), Vector2(100, 100))
	assertions.assert_true(path_blocked.size() > 0, "绕路测试：即使中间有阻挡也应能找到路径")
	for point in path_blocked:
		assertions.assert_true(point != Vector2(50, 50), "路径不应包含阻挡点 (50,50)")

	# 测试坐标换算（映射到最近的网格点）
	var path_approx = nav.get_path_to_point(Vector2(2, 3), Vector2(98, 102))
	assertions.assert_true(path_approx.size() > 0, "模糊坐标寻路：应自动映射到最近网格点")
	assertions.assert_eq(path_approx[0], Vector2(0, 0), "起点 (2,3) 应映射到 (0,0)")
	assertions.assert_eq(path_approx[-1], Vector2(100, 100), "终点 (98,102) 应映射到 (100,100)")
