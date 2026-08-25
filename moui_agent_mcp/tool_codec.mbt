///|
/// Package-private wire codec used to keep one JSON value's schema and
/// decoder together.
priv struct JsonCodec[T] {
  schema : Json
  decode : (Json) -> Result[T, String]
}

///|
/// Type-erased input codec used by the heterogeneous MCP tool registry.
priv struct ToolInputCodec {
  schema : Json
  decode : (Map[String, Json]) -> Result[ToolInvocation, String]
}

///|
/// Type-erased output codec. Pairing the output schema with its dispatcher
/// prevents a registry entry from selecting one without the other.
priv struct ToolOutputCodec[Host] {
  schema : Json
  dispatch : (Host, Json, ToolInvocation) -> Json
}

///|
priv struct ToolSpec[Host] {
  name : String
  description : String
  input : ToolInputCodec
  output : ToolOutputCodec[Host]
}

///|
fn object_schema(properties : Json, required? : Array[String] = []) -> Json {
  (
    {
      "type": "object",
      "properties": properties,
      "required": required,
      "additionalProperties": false,
    } : Json)
}

///|
fn one_of_schema(options : Array[Json]) -> Json {
  ({ "oneOf": options } : Json)
}

///|
fn nullable_schema(value_schema : Json) -> Json {
  one_of_schema([value_schema, ({ "type": "null" } : Json)])
}

///|
fn array_schema(item_schema : Json) -> Json {
  ({ "type": "array", "items": item_schema } : Json)
}

///|
fn tagged_empty_schema(kind : String) -> Json {
  object_schema(({ "kind": { "const": kind } } : Json), required=["kind"])
}

///|
// This regular expression accepts exactly the canonical decimal spellings in
// UInt64's closed range. The decoder uses the same canonicality rules and also
// performs overflow-checked accumulation.
let uint64_decimal_pattern : String = "^(0|[1-9][0-9]{0,18}|1[0-7][0-9]{18}|18[0-3][0-9]{17}|184[0-3][0-9]{16}|1844[0-5][0-9]{15}|18446[0-6][0-9]{14}|184467[0-3][0-9]{13}|1844674[0-3][0-9]{12}|184467440[0-6][0-9]{10}|1844674407[0-2][0-9]{9}|18446744073[0-6][0-9]{8}|1844674407370[0-8][0-9]{6}|18446744073709[0-4][0-9]{5}|184467440737095[0-4][0-9]{4}|18446744073709550[0-9]{3}|18446744073709551[0-5][0-9]{2}|1844674407370955160[0-9]|1844674407370955161[0-5])$"

///|
let positive_uint64_decimal_pattern : String = "^([1-9][0-9]{0,18}|1[0-7][0-9]{18}|18[0-3][0-9]{17}|184[0-3][0-9]{16}|1844[0-5][0-9]{15}|18446[0-6][0-9]{14}|184467[0-3][0-9]{13}|1844674[0-3][0-9]{12}|184467440[0-6][0-9]{10}|1844674407[0-2][0-9]{9}|18446744073[0-6][0-9]{8}|1844674407370[0-8][0-9]{6}|18446744073709[0-4][0-9]{5}|184467440737095[0-4][0-9]{4}|18446744073709550[0-9]{3}|18446744073709551[0-5][0-9]{2}|1844674407370955160[0-9]|1844674407370955161[0-5])$"

///|
fn parse_decimal_u64(value : String) -> UInt64? {
  if value == "" || (value.length() > 1 && value[0] == '0') {
    return None
  }
  let mut parsed = 0UL
  for character in value {
    let code = character.to_int()
    if code < '0' || code > '9' {
      return None
    }
    let digit = (code - ('0' : Int)).to_uint64()
    if parsed > (18446744073709551615UL - digit) / 10UL {
      return None
    }
    parsed = parsed * 10UL + digit
  }
  Some(parsed)
}

///|
fn decimal_u64_codec(positive? : Bool = false) -> JsonCodec[UInt64] {
  let expected = if positive {
    "a canonical positive UInt64 decimal string"
  } else {
    "a canonical UInt64 decimal string"
  }
  {
    schema: (
      {
        "type": "string",
        "pattern": if positive {
          positive_uint64_decimal_pattern
        } else {
          uint64_decimal_pattern
        },
        "minLength": 1,
        "maxLength": 20,
        "description": expected,
      } : Json),
    decode: value => {
      match value {
        Json::String(text) =>
          match parse_decimal_u64(text) {
            Some(number) if !positive || number > 0UL => Ok(number)
            _ => Err("Expected \{expected}.")
          }
        _ => Err("Expected \{expected}.")
      }
    },
  }
}

///|
// JSON Schema counts Unicode characters rather than encoded bytes. The custom
// keyword carries the exact byte constraint used by SemanticId::parse, while
// the standard pattern mirrors its complete whitespace/control exclusion.
let semantic_id_pattern : String = "^[^\\u0000-\\u0020\\u007F-\\u009F\\u00A0\\u1680\\u2000-\\u200A\\u2028\\u2029\\u202F\\u205F\\u3000]+$"

///|
fn semantic_id_codec() -> JsonCodec[@core.SemanticId] {
  {
    schema: (
      {
        "type": "string",
        "pattern": semantic_id_pattern,
        "minLength": 1,
        "maxLength": 255,
        "x-moui-utf8ByteLength": { "minimum": 1, "maximum": 255 },
        "description": "An exact SemanticId containing 1-255 UTF-8 bytes and no whitespace or control characters.",
      } : Json),
    decode: value => {
      match value {
        Json::String(text) =>
          match @core.SemanticId::parse(text) {
            Some(id) => Ok(id)
            None => Err("Invalid semantic_id.")
          }
        _ => Err("Invalid semantic_id.")
      }
    },
  }
}

///|
fn semantics_target_codec() -> JsonCodec[@core.SemanticsTarget] {
  let semantic_id = semantic_id_codec()
  let node_id = decimal_u64_codec(positive=true)
  {
    schema: one_of_schema([
      object_schema(
        ({ "kind": { "const": "semantic_id" }, "id": semantic_id.schema } : Json),
        required=["kind", "id"],
      ),
      object_schema(
        ({ "kind": { "const": "node_id" }, "id": node_id.schema } : Json),
        required=["kind", "id"],
      ),
    ]),
    decode: value => {
      match value {
        Json::Object(fields) =>
          decode_target_with_codecs(fields, semantic_id, node_id)
        _ => Err("Missing tagged 'target' object.")
      }
    },
  }
}

///|
fn semantics_action_codec() -> JsonCodec[@core.SemanticsAction] {
  {
    schema: one_of_schema([
      tagged_empty_schema("activate"),
      tagged_empty_schema("focus"),
      object_schema(
        (
          { "kind": { "const": "set_text" }, "value": { "type": "string" } } :
          Json),
        required=["kind", "value"],
      ),
      tagged_empty_schema("submit"),
      object_schema(
        (
          {
            "kind": { "const": "scroll" },
            "direction": {
              "type": "string",
              "enum": ["forward", "backward", "up", "down", "left", "right"],
            },
          } : Json),
        required=["kind", "direction"],
      ),
      tagged_empty_schema("select"),
      tagged_empty_schema("expand"),
      tagged_empty_schema("collapse"),
      tagged_empty_schema("dismiss"),
      tagged_empty_schema("increment"),
      tagged_empty_schema("decrement"),
      object_schema(
        (
          {
            "kind": { "const": "set_numeric_value" },
            "value": { "type": "number" },
          } : Json),
        required=["kind", "value"],
      ),
      object_schema(
        (
          {
            "kind": { "const": "set_selection" },
            "start": { "type": "integer", "minimum": 0 },
            "end": { "type": "integer", "minimum": 0 },
          } : Json),
        required=["kind", "start", "end"],
      ),
      tagged_empty_schema("show_menu"),
    ]),
    decode: value => {
      match value {
        Json::Object(fields) => decode_action(fields)
        _ => Err("Missing tagged 'action' object.")
      }
    },
  }
}

///|
fn generation_precondition_codec() -> JsonCodec[
  @agent.AgentGenerationPrecondition,
] {
  let generation = decimal_u64_codec()
  {
    schema: one_of_schema([
      tagged_empty_schema("latest"),
      object_schema(
        (
          { "kind": { "const": "exact" }, "generation": generation.schema } :
          Json),
        required=["kind", "generation"],
      ),
    ]),
    decode: value => {
      match value {
        Json::Object(fields) =>
          decode_precondition_with_codec(fields, generation)
        _ => Err("Missing tagged 'precondition' object.")
      }
    },
  }
}

///|
fn read_semantics_input_codec() -> ToolInputCodec {
  let generation = decimal_u64_codec()
  {
    schema: object_schema(({ "since": generation.schema } : Json)),
    decode: arguments => {
      decode_read_semantics_invocation_with_codec(arguments, generation)
    },
  }
}

///|
fn agent_read_trace_input_codec() -> ToolInputCodec {
  let cursor = decimal_u64_codec()
  {
    schema: object_schema(({ "cursor": cursor.schema } : Json)),
    decode: arguments => {
      if !fields_are_exact(arguments, ["cursor"]) {
        return Err("agent_read_trace contains unknown arguments.")
      }
      let value = arguments.get("cursor").unwrap_or("0".to_json())
      match (cursor.decode)(value) {
        Ok(number) => Ok(ToolInvocation::AgentReadTrace(number))
        Err(message) => Err(message)
      }
    },
  }
}

///|
fn agent_replay_trace_input_codec() -> ToolInputCodec {
  let cursor = decimal_u64_codec()
  {
    schema: object_schema(
      (
        {
          "cursor": cursor.schema,
          "require_confirmation": { "type": "boolean" },
        } : Json),
      required=["cursor"],
    ),
    decode: arguments => {
      if !fields_are_exact(arguments, ["cursor", "require_confirmation"]) {
        return Err("agent_replay_trace contains unknown arguments.")
      }
      let cursor_value = arguments.get("cursor").unwrap_or("0".to_json())
      let require_confirmation = match arguments.get("require_confirmation") {
        None => true
        Some(Json::True) => true
        Some(Json::False) => false
        Some(_) => return Err("'require_confirmation' must be boolean.")
      }
      match (cursor.decode)(cursor_value) {
        Ok(number) =>
          Ok(
            ToolInvocation::AgentReplayTrace(
              @agent.AgentReplayRequest::new(
                cursor=number,
                require_confirmation~,
              ),
            ),
          )
        Err(message) => Err(message)
      }
    },
  }
}

///|
fn decode_agent_read_policy_state_invocation(
  arguments : Map[String, Json],
) -> Result[ToolInvocation, String] {
  if arguments.length() == 0 {
    Ok(ToolInvocation::AgentReadPolicyState)
  } else {
    Err("agent_read_policy_state does not accept arguments.")
  }
}

///|
fn perform_action_input_codec() -> ToolInputCodec {
  let target = semantics_target_codec()
  let action = semantics_action_codec()
  let precondition = generation_precondition_codec()
  {
    schema: object_schema(
      (
        {
          "target": target.schema,
          "action": action.schema,
          "precondition": precondition.schema,
        } : Json),
      required=["target", "action", "precondition"],
    ),
    decode: arguments => {
      decode_action_request_with_codecs(arguments, target, action, precondition)
    },
  }
}

///|
fn tool_output_schema(value_schema : Json) -> Json {
  one_of_schema([
    object_schema(({ "ok": { "const": true }, "value": value_schema } : Json), required=[
      "ok", "value",
    ]),
    object_schema(
      (
        {
          "ok": { "const": false },
          "error": object_schema(
            (
              {
                "code": { "type": "string" },
                "message": { "type": "string" },
                "details": { "type": "object" },
              } : Json),
            required=["code", "message", "details"],
          ),
        } : Json),
      required=["ok", "error"],
    ),
  ])
}

///|
fn semantics_state_schema() -> Json {
  let boolean = ({ "type": "boolean" } : Json)
  object_schema(
    (
      {
        "focused": boolean,
        "disabled": boolean,
        "selected": boolean,
        "pressed": boolean,
        "checked": nullable_schema(
          (
            { "type": "string", "enum": ["unchecked", "checked", "mixed"] } :
            Json),
        ),
        "expanded": boolean,
        "invalid": boolean,
        "required": boolean,
        "read_only": boolean,
        "busy": boolean,
        "multiline": boolean,
        "password": boolean,
        "modal": boolean,
      } : Json),
    required=[
      "focused", "disabled", "selected", "pressed", "checked", "expanded", "invalid",
      "required", "read_only", "busy", "multiline", "password", "modal",
    ],
  )
}

///|
fn point_schema() -> Json {
  let number = ({ "type": "number" } : Json)
  object_schema(({ "x": number, "y": number } : Json), required=["x", "y"])
}

///|
fn size_schema() -> Json {
  let number = ({ "type": "number" } : Json)
  object_schema(({ "width": number, "height": number } : Json), required=[
    "width", "height",
  ])
}

///|
fn rect_schema() -> Json {
  object_schema(({ "origin": point_schema(), "size": size_schema() } : Json), required=[
    "origin", "size",
  ])
}

///|
fn text_range_schema() -> Json {
  let index = ({ "type": "integer", "minimum": 0 } : Json)
  object_schema(({ "start": index, "end": index } : Json), required=[
    "start", "end",
  ])
}

///|
fn semantics_numeric_schema() -> Json {
  let optional_number = nullable_schema(({ "type": "number" } : Json))
  object_schema(
    (
      {
        "current": optional_number,
        "min": optional_number,
        "max": optional_number,
        "step": optional_number,
        "value_text": nullable_schema(({ "type": "string" } : Json)),
      } : Json),
    required=["current", "min", "max", "step", "value_text"],
  )
}

///|
fn semantics_text_schema() -> Json {
  object_schema(
    (
      {
        "selection": nullable_schema(text_range_schema()),
        "caret": nullable_schema(({ "type": "integer", "minimum": 0 } : Json)),
        "editable": { "type": "boolean" },
      } : Json),
    required=["selection", "caret", "editable"],
  )
}

///|
fn semantics_collection_schema() -> Json {
  let optional_integer = nullable_schema(({ "type": "integer" } : Json))
  object_schema(
    (
      {
        "row_index": optional_integer,
        "row_count": optional_integer,
        "row_span": optional_integer,
        "column_index": optional_integer,
        "column_count": optional_integer,
        "column_span": optional_integer,
        "set_size": optional_integer,
        "set_position": optional_integer,
      } : Json),
    required=[
      "row_index", "row_count", "row_span", "column_index", "column_count", "column_span",
      "set_size", "set_position",
    ],
  )
}

///|
fn semantics_relations_schema(node_id : Json) -> Json {
  let ids = array_schema(node_id)
  object_schema(
    (
      {
        "labelled_by": ids,
        "described_by": ids,
        "controls": ids,
        "error_message": ids,
        "active_descendant": ids,
      } : Json),
    required=[
      "labelled_by", "described_by", "controls", "error_message", "active_descendant",
    ],
  )
}

///|
fn semantics_action_kind_schema() -> Json {
  (
    {
      "type": "string",
      "enum": [
        "activate", "focus", "set_text", "submit", "scroll", "select", "expand",
        "collapse", "dismiss", "increment", "decrement", "set_numeric_value", "set_selection",
        "show_menu",
      ],
    } : Json)
}

///|
fn semantics_role_schema() -> Json {
  (
    {
      "type": "string",
      "enum": [
        "none", "text", "link", "heading", "navigation", "main", "button", "checkbox",
        "text_field", "list", "list_item", "grid", "scroll_view", "switch", "radio",
        "slider", "progress", "tab", "dialog", "tooltip", "menu", "button_group",
        "form", "form_field", "tree", "tree_item", "group", "web_view", "image",
        "alert", "status", "combo_box", "option", "table", "row", "cell", "separator",
      ],
    } : Json)
}

///|
fn semantics_node_schema() -> Json {
  let node_id = decimal_u64_codec(positive=true).schema
  let semantic_id = semantic_id_codec().schema
  let optional_integer = nullable_schema(({ "type": "integer" } : Json))
  object_schema(
    (
      {
        "node_id": node_id,
        "semantic_id": nullable_schema(semantic_id),
        "role": semantics_role_schema(),
        "level": optional_integer,
        "url": { "type": "string" },
        "label": { "type": "string" },
        "value": { "type": "string" },
        "description": { "type": "string" },
        "state": semantics_state_schema(),
        "numeric": nullable_schema(semantics_numeric_schema()),
        "text": nullable_schema(semantics_text_schema()),
        "collection": nullable_schema(semantics_collection_schema()),
        "relations": semantics_relations_schema(node_id),
        "live": { "type": "string", "enum": ["off", "polite", "assertive"] },
        "atomic": { "type": "boolean" },
        "actions": array_schema(semantics_action_kind_schema()),
        "focus_order": optional_integer,
        "frame": rect_schema(),
        "children": array_schema(node_id),
      } : Json),
    required=[
      "node_id", "semantic_id", "role", "level", "url", "label", "value", "description",
      "state", "numeric", "text", "collection", "relations", "live", "atomic", "actions",
      "focus_order", "frame", "children",
    ],
  )
}

///|
fn semantics_issue_schema() -> Json {
  let node_id = decimal_u64_codec(positive=true).schema
  let semantic_id = semantic_id_codec().schema
  let relation = (
    {
      "type": "string",
      "enum": [
        "labelled_by", "described_by", "controls", "error_message", "active_descendant",
      ],
    } : Json)
  one_of_schema([
    object_schema(
      (
        {
          "kind": { "const": "duplicate_semantic_id" },
          "semantic_id": semantic_id,
          "nodes": array_schema(node_id),
        } : Json),
      required=["kind", "semantic_id", "nodes"],
    ),
    object_schema(
      (
        {
          "kind": { "const": "missing_relation_target" },
          "source": node_id,
          "relation": relation,
          "semantic_id": semantic_id,
        } : Json),
      required=["kind", "source", "relation", "semantic_id"],
    ),
    object_schema(
      (
        {
          "kind": { "const": "ambiguous_relation_target" },
          "source": node_id,
          "relation": relation,
          "semantic_id": semantic_id,
          "nodes": array_schema(node_id),
        } : Json),
      required=["kind", "source", "relation", "semantic_id", "nodes"],
    ),
  ])
}

///|
fn semantics_read_value_schema() -> Json {
  let generation = decimal_u64_codec().schema
  let node_id = decimal_u64_codec(positive=true).schema
  let optional_node_id = nullable_schema(node_id)
  let nodes = array_schema(semantics_node_schema())
  let issues = array_schema(semantics_issue_schema())
  let announcements = array_schema(
    object_schema(
      (
        {
          "node_id": node_id,
          "generation": generation,
          "live": { "type": "string", "enum": ["off", "polite", "assertive"] },
          "atomic": { "type": "boolean" },
          "text": { "type": "string" },
        } : Json),
      required=["node_id", "generation", "live", "atomic", "text"],
    ),
  )
  one_of_schema([
    object_schema(
      (
        {
          "kind": { "const": "full" },
          "generation": generation,
          "root": optional_node_id,
          "focused": optional_node_id,
          "nodes": nodes,
          "issues": issues,
        } : Json),
      required=["kind", "generation", "root", "focused", "nodes", "issues"],
    ),
    object_schema(
      (
        {
          "kind": { "const": "delta" },
          "from": generation,
          "to": generation,
          "root": optional_node_id,
          "focused": optional_node_id,
          "upserted": nodes,
          "removed": array_schema(node_id),
          "issues": issues,
          "announcements": announcements,
        } : Json),
      required=[
        "kind", "from", "to", "root", "focused", "upserted", "removed", "issues",
        "announcements",
      ],
    ),
    object_schema(
      ({ "kind": { "const": "unchanged" }, "generation": generation } : Json),
      required=["kind", "generation"],
    ),
  ])
}

///|
fn action_receipt_value_schema() -> Json {
  let generation = decimal_u64_codec().schema
  object_schema(
    (
      {
        "before": generation,
        "after": generation,
        "pending_work": { "type": "boolean" },
      } : Json),
    required=["before", "after", "pending_work"],
  )
}
