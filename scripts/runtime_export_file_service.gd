class_name RuntimeExportFileService
extends RefCounted

# The file-system mechanics behind Runtime Export: where a World's Catalog and
# its Runtime packages live, whether what is on disk still matches what was
# built, how a package is replaced without ever destroying a valid one, and
# which package directories may be removed again.
#
# It owns no editor state and resolves nothing from the World document. Every
# input is passed in: the World root or the export root, an Asset Key, the
# already built Catalog or Manifest Dictionary, and — for pruning — the set of
# package names main.gd has decided to keep. It knows nothing about Assets,
# selections, Geometry documents, Views or main.gd, and it decides nothing about
# validity: main.gd checks a build before handing it over.
#
# The package layout is the one docs/RUNTIME_EXPORT_CONTRACT.md fixes:
#
#   res://worlds/<world_key>/
#   ├── catalog.json
#   └── PolyToolsRuntimeExports/
#       └── <asset_key>/
#           └── manifest.json
#
# Safety invariants this service keeps, and which its tests mutate against:
#   - the export root itself is never removed;
#   - nothing outside the export root is ever removed;
#   - staging and backup directories are hidden (dot-prefixed) and are never
#     treated as packages, neither when pruning nor when reading;
#   - a failed package write leaves the previously written package complete.

const PACKAGE_DIRECTORY_NAME := "PolyToolsRuntimeExports"
const MANIFEST_FILE_NAME := "manifest.json"
const CATALOG_FILE_NAME := "catalog.json"


static func _absolute_path(path: String) -> String:
	return "" if path.is_empty() else ProjectSettings.globalize_path(path).simplify_path().trim_suffix("/")


static func _is_asset_key(asset_key: String) -> bool:
	# Package names are Asset Keys, not arbitrary relative paths. Besides
	# preserving the export contract, this keeps staging and target paths as one
	# directory directly below the export root.
	return not asset_key.is_empty() and AssetCatalogService.asset_key(asset_key) == asset_key


static func export_root(world_root: String) -> String:
	# The absolute directory holding one package directory per exported Asset.
	# Callers pass the World root; an empty World root has no export root.
	if world_root.is_empty():
		return ""
	return _absolute_path(world_root).path_join(PACKAGE_DIRECTORY_NAME)


static func catalog_path(world_root: String) -> String:
	# The Catalog stays a resource path: it is read back with FileAccess and is
	# handed to the Consumer Sync as it is.
	if world_root.is_empty():
		return ""
	return "%s/%s" % [world_root, CATALOG_FILE_NAME]


static func package_path(root: String, asset_key: String) -> String:
	var bounded_root := _absolute_path(root)
	if bounded_root.is_empty() or not _is_asset_key(asset_key):
		return ""
	return bounded_root.path_join(asset_key)


static func manifest_path(root: String, asset_key: String) -> String:
	var package := package_path(root, asset_key)
	return "" if package.is_empty() else package.path_join(MANIFEST_FILE_NAME)


static func catalog_text(catalog: Dictionary) -> String:
	return JSON.stringify(catalog, "\t")


static func catalog_is_stale(world_root: String, catalog: Dictionary) -> bool:
	# Freshness is decided by comparing the expected bytes, not by remembering
	# that an export happened.
	var path := catalog_path(world_root)
	if path.is_empty() or not FileAccess.file_exists(path):
		return true
	return FileAccess.get_file_as_string(path) != catalog_text(catalog)


static func write_catalog(world_root: String, catalog: Dictionary) -> bool:
	var path := catalog_path(world_root)
	if path.is_empty():
		return false
	return WorldDocumentService.write_text_atomically(
		ProjectSettings.globalize_path(path), catalog_text(catalog))


static func manifest_text(manifest: Dictionary) -> String:
	return JSON.stringify(manifest, "\t")


static func manifest_text_matches(expected_text: String, staged_text: String) -> bool:
	# Byte equality is not enough on its own: what was read back must also still
	# parse as a Manifest the contract accepts.
	if staged_text.is_empty() or staged_text != expected_text:
		return false
	var parsed = JSON.parse_string(staged_text)
	return parsed is Dictionary and RuntimeExportService.manifest_validation_issues(parsed).is_empty()


static func package_is_stale(root: String, asset_key: String, manifest: Dictionary) -> bool:
	var path := manifest_path(root, asset_key)
	if path.is_empty() or not FileAccess.file_exists(path):
		return true
	return not manifest_text_matches(manifest_text(manifest), FileAccess.get_file_as_string(path))


static func write_package(root: String, asset_key: String, manifest: Dictionary) -> bool:
	# The package is staged beside its target, read back, and only then swapped
	# in; the previous package is moved aside first and put back if the swap
	# fails. Nothing is written into the target directory itself, so a failure
	# at any step leaves the previous complete package in place.
	var bounded_root := _absolute_path(root)
	if bounded_root.is_empty() or not _is_asset_key(asset_key):
		return false
	DirAccess.make_dir_recursive_absolute(bounded_root)
	var target := package_path(bounded_root, asset_key)
	var staging := bounded_root.path_join(".%s.staging" % asset_key)
	var backup := bounded_root.path_join(".%s.backup" % asset_key)
	remove_tree(bounded_root, staging)
	remove_tree(bounded_root, backup)
	if DirAccess.make_dir_recursive_absolute(staging) != OK:
		return false
	var expected_text := manifest_text(manifest)
	var manifest_file := FileAccess.open(staging.path_join(MANIFEST_FILE_NAME), FileAccess.WRITE)
	if manifest_file == null:
		remove_tree(bounded_root, staging)
		return false
	manifest_file.store_string(expected_text)
	manifest_file.close()
	if not manifest_text_matches(expected_text, FileAccess.get_file_as_string(staging.path_join(MANIFEST_FILE_NAME))):
		remove_tree(bounded_root, staging)
		return false
	if DirAccess.dir_exists_absolute(target) and DirAccess.rename_absolute(target, backup) != OK:
		remove_tree(bounded_root, staging)
		return false
	if DirAccess.rename_absolute(staging, target) != OK:
		if DirAccess.dir_exists_absolute(backup):
			DirAccess.rename_absolute(backup, target)
		remove_tree(bounded_root, staging)
		return false
	remove_tree(bounded_root, backup)
	return true


static func prune_packages(root: String, allowed_keys: Dictionary) -> int:
	# Which keys survive is a document question and is answered by the caller:
	# the Catalog set plus every visible Asset, so an invalid visible Asset keeps
	# its last known-good package while staying unadvertised. Dot-prefixed
	# directories are this service's own staging and backup residue and are
	# never packages.
	var bounded_root := _absolute_path(root)
	if bounded_root.is_empty() or not DirAccess.dir_exists_absolute(bounded_root):
		return 0
	var directory := DirAccess.open(bounded_root)
	if directory == null:
		return 0
	var removed := 0
	for directory_name in directory.get_directories():
		var name := str(directory_name)
		if name.begins_with(".") or allowed_keys.has(name):
			continue
		remove_tree(bounded_root, bounded_root.path_join(name))
		removed += 1
	return removed


static func remove_tree(root: String, path: String) -> void:
	# Recursive removal, bounded to strictly below the export root. The root
	# itself never satisfies the prefix test, so it cannot be removed here.
	var bounded_root := _absolute_path(root)
	var bounded_path := _absolute_path(path)
	if bounded_root.is_empty() or bounded_path.is_empty() \
		or not bounded_path.begins_with(bounded_root + "/") \
		or not DirAccess.dir_exists_absolute(bounded_path):
		return
	var directory := DirAccess.open(bounded_path)
	if directory == null:
		return
	for file_name in directory.get_files():
		DirAccess.remove_absolute(bounded_path.path_join(file_name))
	for directory_name in directory.get_directories():
		remove_tree(bounded_root, bounded_path.path_join(directory_name))
	DirAccess.remove_absolute(bounded_path)
