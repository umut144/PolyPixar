# PolyTools test runner.
#
#   godot --headless --path . -s res://tests/run_tests.gd
#
# The tests live in the suites listed below; each is a script extending
# tests/test_case.gd whose `_test_*` functions are the tests. The runner finds
# them with `get_method_list()`, so declaring a test is what makes it run — a
# suite cannot forget to list one.
#
# A runtime error in GDScript aborts only the function it occurs in and
# returns null to the caller, so a test whose helper or whose main.gd call
# failed keeps running and may still reach the end of the suite without any
# assertion noticing. The runner therefore registers a Logger for the duration
# of the run: every engine ERROR and SCRIPT ERROR raised while a test runs is
# attributed to that test and counted as a failure, whatever the test's own
# assertions concluded. Warnings are left to tools/verify.sh, which also reads
# the leak report Godot prints after this script has quit.
extends SceneTree

const SUITES := [
	"res://tests/topology_tests.gd",
	"res://tests/geometry_tests.gd",
	"res://tests/editor_tests.gd",
	"res://tests/persistence_tests.gd",
	"res://tests/motion_tests.gd",
]


class ErrorRecorder extends Logger:
	var errors: Array[String] = []

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_ERROR and error_type != ERROR_TYPE_SCRIPT:
			return
		var detail := rationale if not rationale.is_empty() else code
		errors.append("%s:%d — %s" % [file, line, detail])


func _init() -> void:
	var recorder := ErrorRecorder.new()
	OS.add_logger(recorder)
	var total_tests := 0
	var failures := 0
	for suite_path in SUITES:
		var outcome = _run_suite(suite_path, recorder)
		if outcome == null:
			printerr("FAIL %s: the suite could not be run; see the errors above." % suite_path)
			failures += 1
			continue
		total_tests += int(outcome["tests"])
		failures += int(outcome["failures"])
	OS.remove_logger(recorder)
	print("%d PolyTools tests run." % total_tests)
	if failures == 0:
		print("All PolyTools tests passed.")
		quit(0)
	else:
		printerr("%d PolyTools test failure(s)." % failures)
		quit(1)


## One suite, run to its end, as {tests, failures} - or null if it aborted.
##
## Everything that can raise a runtime error happens in here rather than in
## `_init`, and that placement is the whole point. A runtime error ends only the
## function it occurs in and hands null to its caller, so an error here costs
## one suite; the same error in `_init` cost the run its `quit()` and left the
## headless process alive until somebody killed it by hand. The return type is
## deliberately left off: a declared one would coerce that null into an empty
## Dictionary, and an aborted suite would read as an empty one.
func _run_suite(suite_path: String, recorder: ErrorRecorder):
	var suite_script = load(suite_path)
	# A suite that fails to parse does not come back as null. It comes back as a
	# GDScript that cannot be instantiated, and `new()` on it raises the runtime
	# error that used to take the run down.
	if suite_script == null or not suite_script.can_instantiate():
		printerr("FAIL %s: the suite did not load; see the SCRIPT ERROR above." % suite_path)
		return {"tests": 0, "failures": 1}
	var suite = suite_script.new()
	var test_names := _test_names(suite)
	var suite_failures := 0
	if test_names.is_empty():
		suite_failures += 1
		printerr("FAIL %s: the suite declares no _test_ function." % suite_path)
	var logged_errors := 0
	for test_name in test_names:
		suite.current_test = test_name
		recorder.errors.clear()
		suite.call(test_name)
		for error in recorder.errors:
			printerr("FAIL %s: Godot reported an error while it ran: %s" % [test_name, error])
		logged_errors += recorder.errors.size()
	suite_failures += suite.failures + logged_errors
	print("%s: %d tests, %d failures" % [suite_path.get_file(), test_names.size(), suite.failures + logged_errors])
	return {"tests": test_names.size(), "failures": suite_failures}


static func _test_names(suite: RefCounted) -> Array[String]:
	# Script methods come back in declaration order, so a suite runs top to
	# bottom; tests do not depend on that, but a stable order keeps two runs
	# comparable.
	var names: Array[String] = []
	for method in suite.get_method_list():
		var method_name := str(method["name"])
		if method_name.begins_with("_test_"):
			names.append(method_name)
	return names
