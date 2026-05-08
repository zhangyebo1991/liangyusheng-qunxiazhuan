extends SceneTree

const TestAssertionsScript = preload("res://tests/support/test_assertions.gd")
const TestDataLoaderScript = preload("res://tests/test_data_loader.gd")
const TestDomainModelsScript = preload("res://tests/test_domain_models.gd")

func _init() -> void:
	var assertions = TestAssertionsScript.new()
	var suites: Array = [
		TestDataLoaderScript.new(),
		TestDomainModelsScript.new(),
	]

	for suite in suites:
		suite.run(assertions)

	for failure in assertions.failures:
		push_error(failure)

	if assertions.failures.is_empty():
		print("测试通过：%d 个测试套件" % suites.size())
		quit(0)
	else:
		print("测试失败：%d 个问题" % assertions.failures.size())
		quit(1)
