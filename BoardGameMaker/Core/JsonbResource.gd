class_name JsonbResource extends Resource
## Base class for save data that can be converted to jsonb.[br]
## Every property marked with @export (or @export_storage) in this class, its subclasses, and any nested Resources is saved and restored.
##[br][br]
## Written for Godot 4.4+ (typed Dictionary support and Script.get_global_name()).
##[br][br]
## Usage:[br]
##     var dict := my_state.to_jsonb()[br]
##     var text := JSON.stringify(dict)[br]
##     ...[br]
##     var loaded := GameState.from_jsonb(JSON.parse_string(text))[br]

# Keys used in the serialized format.
const KEY_TYPE := "__type__"
const KEY_ID := "__id__"
const KEY_SCRIPT_PATH := "__script_path__"
const KEY_SCRIPT_CLASS := "__script_class__"
const KEY_CLASS := "__class__"
const KEY_PROPS := "props"
const KEY_PATH := "path"
const KEY_ITEMS := "items"
const KEY_ENTRIES := "entries"
const KEY_TYPED := "typed"
const KEY_ELEM_TYPE := "elem_type"
const KEY_ELEM_CLASS := "elem_class"
const KEY_ELEM_SCRIPT := "elem_script"
const KEY_DICT_TYPES := "dict_types"

# Values for KEY_TYPE.
const T_RESOURCE := "resource"
const T_EXTERNAL := "external"
const T_BACKREF := "backref"
const T_ARRAY := "array"
const T_DICT := "dict"

const EXCLUDED_PROPS: Array[String] = [
	"resource_path",
	"resource_name",
	"script",
	"resource_local_to_scene",
	"resource_scene_unique_id",
]


# --- Public API ---

func to_jsonb() -> Dictionary:
	return _serialize_value(self, {"ids": {}})


static func from_jsonb(data: Dictionary) -> JsonbResource:
	if data.is_empty():
		return null
	var result: Variant = _deserialize_value(data, {})
	# `as` returns null if the result is not a JsonbResource (corrupt/foreign data).
	return result as JsonbResource


# --- Serialization ---

static func _serialize_value(value: Variant, ctx: Dictionary) -> Variant:
	var type := typeof(value)

	if type == TYPE_NIL:
		return null

	if type == TYPE_OBJECT:
		if value is Resource:
			return _serialize_resource(value, ctx)
		# Nodes, RefCounted, freed objects, etc. cannot be saved safely.
		push_warning("GameState: skipping non-Resource object value.")
		return null

	# Not serializable.
	if type == TYPE_CALLABLE or type == TYPE_SIGNAL or type == TYPE_RID:
		return null

	if type == TYPE_ARRAY:
		return _serialize_array(value, ctx)

	if type == TYPE_DICTIONARY:
		return _serialize_dictionary(value, ctx)

	# Everything else (int, float, String, Vector2, Color, Packed*Array, ...) round-trips
	# exactly through var_to_str/str_to_var, including int64 precision, NAN and INF.
	return var_to_str(value)


static func _serialize_resource(res: Resource, ctx: Dictionary) -> Dictionary:
	var ids: Dictionary = ctx["ids"]
	var instance_id := res.get_instance_id()

	# Shared or cyclic reference: point back to the already-serialized resource.
	if ids.has(instance_id):
		return {KEY_TYPE: T_BACKREF, KEY_ID: ids[instance_id]}

	var id: int = ids.size()
	ids[instance_id] = id

	var script: Script = res.get_script()

	# Asset resources living in their own file (textures, audio, ...) are saved by path.
	if script == null and _is_external_resource(res):
		return {KEY_TYPE: T_EXTERNAL, KEY_ID: id, KEY_PATH: res.resource_path}

	var out := {KEY_TYPE: T_RESOURCE, KEY_ID: id}
	if script != null:
		out[KEY_SCRIPT_PATH] = script.resource_path
		out[KEY_SCRIPT_CLASS] = String(script.get_global_name())
	else:
		# Built-in resource without a script (Gradient, Curve, ...).
		out[KEY_CLASS] = res.get_class()

	var props := {}
	for prop_name in _storage_property_names(res):
		props[prop_name] = _serialize_value(res.get(prop_name), ctx)
	out[KEY_PROPS] = props
	return out


static func _serialize_array(arr: Array, ctx: Dictionary) -> Dictionary:
	var items := []
	for item in arr:
		items.append(_serialize_value(item, ctx))

	var out := {KEY_TYPE: T_ARRAY, KEY_ITEMS: items}
	if arr.is_typed():
		out[KEY_ELEM_TYPE] = arr.get_typed_builtin()
		out[KEY_ELEM_CLASS] = String(arr.get_typed_class_name())
		var elem_script: Script = arr.get_typed_script()
		out[KEY_ELEM_SCRIPT] = elem_script.resource_path if elem_script else ""
	return out


static func _serialize_dictionary(dict: Dictionary, ctx: Dictionary) -> Dictionary:
	# Stored as [key, value] pairs so non-string keys (int, Vector2i, ...) survive JSON.
	var entries := []
	for key in dict:
		entries.append([_serialize_value(key, ctx), _serialize_value(dict[key], ctx)])

	var out := {KEY_TYPE: T_DICT, KEY_ENTRIES: entries}
	if dict.is_typed():
		var key_script: Script = dict.get_typed_key_script()
		var value_script: Script = dict.get_typed_value_script()
		out[KEY_TYPED] = true
		out[KEY_DICT_TYPES] = [
			dict.get_typed_key_builtin(),
			String(dict.get_typed_key_class_name()),
			key_script.resource_path if key_script else "",
			dict.get_typed_value_builtin(),
			String(dict.get_typed_value_class_name()),
			value_script.resource_path if value_script else "",
		]
	return out


# --- Deserialization ---

static func _deserialize_value(value: Variant, ctx: Dictionary) -> Variant:
	if value == null:
		return null

	if value is String:
		return _parse_leaf(value)

	if value is Dictionary:
		var type: String = str(value.get(KEY_TYPE, ""))
		match type:
			T_RESOURCE:
				return _deserialize_resource(value, ctx)
			T_EXTERNAL:
				return _deserialize_external(value, ctx)
			T_BACKREF:
				return ctx.get(int(value.get(KEY_ID, -1)), null)
			T_ARRAY:
				return _deserialize_array(value, ctx)
			T_DICT:
				return _deserialize_dictionary(value, ctx)
		push_warning("GameState: unknown serialized dictionary, ignoring.")
		return null

	return value


static func _parse_leaf(text: String) -> Variant:
	# str_to_var can instantiate Objects. We never write those, so refuse them
	# (string literals are safe and start with a quote).
	if not text.begins_with("\"") and text.contains("Object("):
		push_warning("GameState: refusing to parse object data from save.")
		return null
	return str_to_var(text)


static func _deserialize_resource(data: Dictionary, ctx: Dictionary) -> Resource:
	var res: Resource = null

	if data.has(KEY_SCRIPT_PATH):
		var script: Variant = _resolve_script(
			str(data[KEY_SCRIPT_PATH]), str(data.get(KEY_SCRIPT_CLASS, "")))
		if script == null:
			push_warning("GameState: could not find script '%s'." % data[KEY_SCRIPT_PATH])
			return null
		var created: Variant = script.new()
		if not created is Resource:
			return null
		res = created
	else:
		var cls := str(data.get(KEY_CLASS, ""))
		if (cls.is_empty()
				or not ClassDB.class_exists(cls)
				or not ClassDB.is_parent_class(cls, "Resource")
				or not ClassDB.can_instantiate(cls)):
			push_warning("GameState: cannot instantiate resource class '%s'." % cls)
			return null
		res = ClassDB.instantiate(cls)

	# Register BEFORE filling properties so cyclic/shared references resolve.
	ctx[int(data.get(KEY_ID, -1))] = res

	var props: Dictionary = data.get(KEY_PROPS, {})
	var valid := _storage_property_names(res)
	for key in props:
		# Ignore properties that no longer exist (renamed/removed in newer versions).
		if not valid.has(key):
			continue
		res.set(key, _deserialize_value(props[key], ctx))

	return res


static func _deserialize_external(data: Dictionary, ctx: Dictionary) -> Resource:
	var path := str(data.get(KEY_PATH, ""))
	if not path.begins_with("res://") or not ResourceLoader.exists(path):
		push_warning("GameState: external resource '%s' not found." % path)
		return null
	var res: Resource = load(path)
	ctx[int(data.get(KEY_ID, -1))] = res
	return res


static func _deserialize_array(data: Dictionary, ctx: Dictionary) -> Array:
	var result: Array = []

	var elem_type := int(data.get(KEY_ELEM_TYPE, TYPE_NIL))
	if elem_type != TYPE_NIL:
		var elem_script: Variant = null
		var script_path := str(data.get(KEY_ELEM_SCRIPT, ""))
		if not script_path.is_empty():
			elem_script = _resolve_script(script_path, "")
		result = Array([], elem_type, StringName(str(data.get(KEY_ELEM_CLASS, ""))), elem_script)

	for item in data.get(KEY_ITEMS, []):
		result.append(_deserialize_value(item, ctx))
	return result


static func _deserialize_dictionary(data: Dictionary, ctx: Dictionary) -> Dictionary:
	var result: Dictionary = {}

	if data.get(KEY_TYPED, false):
		var t: Array = data.get(KEY_DICT_TYPES, [])
		if t.size() == 6:
			var key_script: Variant = _resolve_script(str(t[2]), "") if str(t[2]) != "" else null
			var value_script: Variant = _resolve_script(str(t[5]), "") if str(t[5]) != "" else null
			result = Dictionary({},
				int(t[0]), StringName(str(t[1])), key_script,
				int(t[3]), StringName(str(t[4])), value_script)

	for entry in data.get(KEY_ENTRIES, []):
		if entry is Array and entry.size() == 2:
			result[_deserialize_value(entry[0], ctx)] = _deserialize_value(entry[1], ctx)
	return result


# --- Helpers ---

static func _storage_property_names(obj: Object) -> Array[String]:
	var names: Array[String] = []
	for prop in obj.get_property_list():
		var prop_name: String = prop["name"]
		if (prop["usage"] & PROPERTY_USAGE_STORAGE) and not EXCLUDED_PROPS.has(prop_name):
			names.append(prop_name)
	return names


static func _is_external_resource(res: Resource) -> bool:
	# Sub-resources embedded in a scene/resource file have paths like "res://x.tscn::Foo_1".
	return not res.resource_path.is_empty() and not res.resource_path.contains("::")


## Finds a script by path, falling back to its global class_name if the file moved.
static func _resolve_script(path: String, global_name: String) -> Variant:
	if path.begins_with("res://") and ResourceLoader.exists(path):
		var loaded: Variant = load(path)
		if loaded is Script:
			return loaded

	if not global_name.is_empty():
		for entry in ProjectSettings.get_global_class_list():
			if entry["class"] == global_name:
				var by_name: Variant = load(entry["path"])
				if by_name is Script:
					return by_name
	return null
