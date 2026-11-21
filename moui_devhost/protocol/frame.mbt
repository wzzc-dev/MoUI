///|
/// Encode the subset of a plugin `DrawFrame` the bridge host can replay.
/// Unsupported variants are counted so DevTools can report a real gap instead
/// of silently dropping paint. The plugin's `Clear` is skipped because the
/// host runtime owns frame initialization.
pub fn encode_frame(frame : @core.DrawFrame) -> String {
  let commands : Array[Json] = []
  let mut unsupported : Int32 = 0
  for command in frame.commands {
    match command {
      @core.DrawCommand::FillRoundedRect(rounded, color) =>
        commands.push(
          rounded_color_command("fill_rounded_rect", rounded, color),
        )
      @core.DrawCommand::FillRoundedRectBrush(rounded, brush) =>
        match brush {
          @core.Brush::Solid(color) =>
            commands.push(
              rounded_color_command("fill_rounded_rect", rounded, color),
            )
          _ => unsupported = unsupported + 1
        }
      @core.DrawCommand::StrokeRoundedRect(rounded, color, width) =>
        commands.push(
          rounded_stroke_command("stroke_rounded_rect", rounded, color, width),
        )
      @core.DrawCommand::StrokeRoundedRectBrush(rounded, brush, width) =>
        match brush {
          @core.Brush::Solid(color) =>
            commands.push(
              rounded_stroke_command(
                "stroke_rounded_rect", rounded, color, width,
              ),
            )
          _ => unsupported = unsupported + 1
        }
      @core.DrawCommand::DrawText(run) => commands.push(text_command(run))
      @core.DrawCommand::PushTransform(transform) =>
        commands.push(transform_command(transform))
      @core.DrawCommand::PopTransform => {
        let fields : Map[String, Json] = Map([])
        fields["kind"] = string_json("pop_transform")
        commands.push(Json::object(fields))
      }
      @core.DrawCommand::Clear(_) => ()
      _ => unsupported = unsupported + 1
    }
  }
  let root : Map[String, Json] = Map([])
  root["version"] = Json::number(
    abi_version().to_double(),
    repr=abi_version().to_string(),
  )
  root["commands"] = Json::array(commands)
  root["unsupported"] = Json::number(
    unsupported.to_double(),
    repr=unsupported.to_string(),
  )
  Json::object(root).stringify()
}

///|
fn rounded_color_command(
  kind : String,
  rounded : @core.RoundedRect,
  color : @core.Color,
) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["kind"] = string_json(kind)
  fields["rounded"] = rounded_rect_json(rounded)
  fields["color"] = color_json(color)
  Json::object(fields)
}

///|
fn rounded_stroke_command(
  kind : String,
  rounded : @core.RoundedRect,
  color : @core.Color,
  width : Double,
) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["kind"] = string_json(kind)
  fields["rounded"] = rounded_rect_json(rounded)
  fields["color"] = color_json(color)
  fields["width"] = number_json(width)
  Json::object(fields)
}

///|
fn font_family_name(font : @core.FontSpec) -> String {
  if font.families.families.is_empty() {
    "system-ui"
  } else {
    font.families.families[0].css_name()
  }
}

///|
fn text_align_name(align : @core.TextAlign) -> String {
  match align {
    @core.TextAlign::TextStart => "TextStart"
    @core.TextAlign::TextCenter => "TextCenter"
    @core.TextAlign::TextEnd => "TextEnd"
  }
}

///|
fn transform_command(transform : @core.Transform2D) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["kind"] = string_json("push_transform")
  fields["a"] = number_json(transform.a)
  fields["b"] = number_json(transform.b)
  fields["c"] = number_json(transform.c)
  fields["d"] = number_json(transform.d)
  fields["tx"] = number_json(transform.tx)
  fields["ty"] = number_json(transform.ty)
  Json::object(fields)
}

///|
fn text_command(run : @core.TextRun) -> Json {
  let font : Map[String, Json] = Map([])
  font["family"] = string_json(font_family_name(run.font))
  font["size"] = number_json(run.font.size)
  font["weight"] = Json::number(
    run.font.weight.to_double(),
    repr=run.font.weight.to_string(),
  )
  font["italic"] = bool_json(
    match run.font.style {
      @core.FontStyle::Normal => false
      @core.FontStyle::Italic => true
    },
  )
  font["line_height"] = match run.font.line_height {
    Some(value) => number_json(value)
    None => Json::null()
  }
  font["letter_spacing"] = match run.font.letter_spacing {
    Some(value) => number_json(value)
    None => Json::null()
  }
  let fields : Map[String, Json] = Map([])
  fields["kind"] = string_json("text")
  fields["text"] = string_json(run.text)
  fields["rect"] = rect_json(run.frame)
  fields["font"] = Json::object(font)
  fields["color"] = color_json(run.color)
  fields["align"] = string_json(text_align_name(run.align))
  fields["stroke_color"] = match run.stroke_color {
    Some(color) => color_json(color)
    None => Json::null()
  }
  fields["stroke_width"] = number_json(run.stroke_width)
  Json::object(fields)
}

///|
/// Decode the bridge frame back into real core commands. Any malformed
/// command rejects the whole payload: a partially painted frame is worse than
/// keeping the previous one.
pub fn decode_frame(text : String) -> Array[@core.DrawCommand]? {
  let parsed = @json.parse(text) catch { _ => return None }
  let root = match wire_object(Some(parsed)) {
    Some(root) => root
    None => return None
  }
  match wire_int(root.get("version")) {
    Some(version) => if version != abi_version() { return None }
    None => return None
  }
  let items = match wire_array(root.get("commands")) {
    Some(items) => items
    None => return None
  }
  let commands : Array[@core.DrawCommand] = []
  for item in items {
    match decode_command(item) {
      Some(command) => commands.push(command)
      None => return None
    }
  }
  Some(commands)
}

///|
fn decode_command(value : Json) -> @core.DrawCommand? {
  let fields = match wire_object(Some(value)) {
    Some(fields) => fields
    None => return None
  }
  let kind = match wire_string(fields.get("kind")) {
    Some(kind) => kind
    None => return None
  }
  match kind {
    "fill_rounded_rect" => {
      let rounded = match rounded_rect_from_json(fields.get("rounded")) {
        Some(rounded) => rounded
        None => return None
      }
      let color = match color_from_json(fields.get("color")) {
        Some(color) => color
        None => return None
      }
      Some(@core.DrawCommand::FillRoundedRect(rounded, color))
    }
    "stroke_rounded_rect" => {
      let rounded = match rounded_rect_from_json(fields.get("rounded")) {
        Some(rounded) => rounded
        None => return None
      }
      let color = match color_from_json(fields.get("color")) {
        Some(color) => color
        None => return None
      }
      let width = match wire_number(fields.get("width")) {
        Some(width) => width
        None => return None
      }
      Some(@core.DrawCommand::StrokeRoundedRect(rounded, color, width))
    }
    "push_transform" => {
      let a = match wire_number(fields.get("a")) {
        Some(value) => value
        None => return None
      }
      let b = match wire_number(fields.get("b")) {
        Some(value) => value
        None => return None
      }
      let c = match wire_number(fields.get("c")) {
        Some(value) => value
        None => return None
      }
      let d = match wire_number(fields.get("d")) {
        Some(value) => value
        None => return None
      }
      let tx = match wire_number(fields.get("tx")) {
        Some(value) => value
        None => return None
      }
      let ty = match wire_number(fields.get("ty")) {
        Some(value) => value
        None => return None
      }
      Some(
        @core.DrawCommand::PushTransform(@core.Transform2D::{
          a,
          b,
          c,
          d,
          tx,
          ty,
        }),
      )
    }
    "pop_transform" => Some(@core.DrawCommand::PopTransform)
    "text" => {
      let rect = match rect_from_json(fields.get("rect")) {
        Some(rect) => rect
        None => return None
      }
      let color = match color_from_json(fields.get("color")) {
        Some(color) => color
        None => return None
      }
      let font_fields = match wire_object(fields.get("font")) {
        Some(font) => font
        None => return None
      }
      let family = match wire_string(font_fields.get("family")) {
        Some(family) => family
        None => return None
      }
      let size = match wire_number(font_fields.get("size")) {
        Some(size) => size
        None => return None
      }
      let weight = match wire_int(font_fields.get("weight")) {
        Some(weight) => weight
        None => return None
      }
      let italic = match wire_bool(font_fields.get("italic")) {
        Some(italic) => italic
        None => return None
      }
      let families = if family == "system-ui" || family == "" {
        @core.FontFamilyStack::system_ui()
      } else {
        @core.FontFamilyStack::named(family)
      }
      let font = @core.FontSpec::new(
        families~,
        size~,
        weight~,
        style=if italic {
          @core.FontStyle::Italic
        } else {
          @core.FontStyle::Normal
        },
        line_height?=wire_nullable_number(font_fields.get("line_height")),
        letter_spacing?=wire_nullable_number(font_fields.get("letter_spacing")),
      )
      let align = match wire_string(fields.get("align")) {
        Some("TextStart") => @core.TextAlign::TextStart
        Some("TextCenter") => @core.TextAlign::TextCenter
        Some("TextEnd") => @core.TextAlign::TextEnd
        _ => return None
      }
      let stroke_color = match fields.get("stroke_color") {
        Some(Json::Null) | None => None
        Some(value) => color_from_json(Some(value))
      }
      let stroke_width = match wire_number(fields.get("stroke_width")) {
        Some(width) => width
        None => 0.0
      }
      Some(
        @core.DrawCommand::DrawText(@core.TextRun::{
          text: match wire_string(fields.get("text")) {
            Some(text) => text
            None => return None
          },
          frame: rect,
          font,
          color,
          align,
          stroke_color,
          stroke_width,
        }),
      )
    }
    _ => None
  }
}
