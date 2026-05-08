extends RefCounted

var failures: Array[String] = []

func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s。期望：%s，实际：%s" % [message, str(expected), str(actual)])

func assert_true(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
