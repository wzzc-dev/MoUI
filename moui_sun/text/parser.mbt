///|
/// Error returned by the checked TTF parser entry point.
pub(all) enum FontParseError {
  UnexpectedEndOfData(Int, Int, Int)
  InvalidFontHeader(UInt)
  UnsupportedFontIndex(Int)
  MissingTable(String)
  TableOutOfBounds(String, Int, Int, Int)
  TableTooShort(String, Int, Int)
  UnsupportedIndexToLocFormat(Int)
  MissingHorizontalMetrics
  UnsortedLocaOffsets
  UnsortedGlyphContourEndpoints
  GlyphFlagRepeatOverflow
  UnsupportedCmapVersion(Int)
  InvalidCmapSegmentCount(Int)
  InvalidCmapSegmentRange(Int, Int)
  InvalidCmapGroupRange(Int, Int)
} derive(Eq, Debug)

///|
/// Parse a TTF font file and report structural errors as Result values.
fn parse_font_result(data : Bytes) -> Result[Font, FontParseError] {
  parse_font_checked(data)
}

///|
fn parse_font_checked(data : Bytes) -> Result[Font, FontParseError] {
  let tables = match parse_table_directory(data) {
    Err(error) => return Err(error)
    Ok(tables) => tables
  }
  let head = match parse_head_checked(data, tables) {
    Err(error) => return Err(error)
    Ok(head) => head
  }
  let hhea = match parse_hhea_checked(data, tables) {
    Err(error) => return Err(error)
    Ok(hhea) => hhea
  }
  let hmtx = match parse_hmtx_checked(data, tables, hhea.num_h_metrics) {
    Err(error) => return Err(error)
    Ok(hmtx) => hmtx
  }
  let cmap = match parse_cmap_checked(data, tables) {
    Err(error) => return Err(error)
    Ok(cmap) => cmap
  }
  let num_glyphs = match parse_maxp_checked(data, tables) {
    Err(error) => return Err(error)
    Ok(num_glyphs) => num_glyphs
  }
  let loca = match
    parse_loca_checked(data, tables, head.index_to_loc_format, num_glyphs) {
    Err(error) => return Err(error)
    Ok(loca) => loca
  }
  let (glyphs, glyph_count) = match
    parse_glyf_checked(data, tables, loca, head.index_to_loc_format, num_glyphs) {
    Err(error) => return Err(error)
    Ok(result) => result
  }
  let kern = match parse_kern_checked(data, tables) {
    Err(error) => return Err(error)
    Ok(kern) => kern
  }
  Ok({ head, hhea, hmtx, cmap, glyphs, glyph_count, kern })
}

///|
fn parse_table_directory(
  data : Bytes,
) -> Result[Map[String, TableRecord], FontParseError] {
  guard data.length() >= 12 else {
    return Err(FontParseError::UnexpectedEndOfData(0, 12, data.length()))
  }
  let sf_version = read_u32_be_at(data, 0)
  guard sf_version == 0x00010000 else {
    return Err(FontParseError::InvalidFontHeader(sf_version))
  }

  let num_tables = read_u16_be_at(data, 4).to_int()
  let directory_len = 12 + num_tables * 16
  guard data.length() >= directory_len else {
    return Err(
      FontParseError::UnexpectedEndOfData(12, num_tables * 16, data.length()),
    )
  }

  let tables : Map[String, TableRecord] = {}
  for i in 0..<num_tables {
    let pos = 12 + i * 16
    let tag = read_tag_at(data, pos)
    let checksum = read_u32_be_at(data, pos + 4)
    let offset = read_u32_be_at(data, pos + 8)
    let length = read_u32_be_at(data, pos + 12)
    tables[tag] = { tag, checksum, offset, length }
  }
  Ok(tables)
}

///|
fn parse_head_checked(
  data : Bytes,
  tables : Map[String, TableRecord],
) -> Result[FontHead, FontParseError] {
  let head = match require_table(data, tables, "head") {
    Err(error) => return Err(error)
    Ok(table) => table
  }
  match require_min_length(head, 54) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let head_offset = head.offset.reinterpret_as_int()
  let index_to_loc_format = read_i16_be_at(data, head_offset + 50)
  guard index_to_loc_format is 0 || index_to_loc_format is 1 else {
    return Err(FontParseError::UnsupportedIndexToLocFormat(index_to_loc_format))
  }
  let units_per_em = read_u16_be_at(data, head_offset + 18).to_int()
  Ok({ units_per_em, index_to_loc_format })
}

///|
fn parse_hhea_checked(
  data : Bytes,
  tables : Map[String, TableRecord],
) -> Result[FontHhea, FontParseError] {
  let hhea = match require_table(data, tables, "hhea") {
    Err(error) => return Err(error)
    Ok(table) => table
  }
  match require_min_length(hhea, 36) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }

  let hhea_offset = hhea.offset.reinterpret_as_int()
  let num_h_metrics = read_u16_be_at(data, hhea_offset + 34).to_int()
  guard num_h_metrics > 0 else {
    return Err(FontParseError::MissingHorizontalMetrics)
  }
  let ascent = read_i16_be_at(data, hhea_offset + 4)
  let descent = read_i16_be_at(data, hhea_offset + 6)
  let line_gap = read_i16_be_at(data, hhea_offset + 8)
  Ok({ ascent, descent, line_gap, num_h_metrics })
}

///|
fn parse_hmtx_checked(
  data : Bytes,
  tables : Map[String, TableRecord],
  num_h_metrics : Int,
) -> Result[Array[LongHorMetric], FontParseError] {
  let hmtx = match require_table(data, tables, "hmtx") {
    Err(error) => return Err(error)
    Ok(table) => table
  }
  match require_min_length(hmtx, num_h_metrics * 4) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let hmtx_offset = hmtx.offset.reinterpret_as_int()
  let metrics = []
  for i in 0..<num_h_metrics {
    let pos = hmtx_offset + i * 4
    let advance_width = read_u16_be_at(data, pos).to_int()
    let lsb = read_i16_be_at(data, pos + 2)
    metrics.push({ advance_width, lsb })
  }
  Ok(metrics)
}

///|
fn parse_cmap_checked(
  data : Bytes,
  tables : Map[String, TableRecord],
) -> Result[Map[Int, Int], FontParseError] {
  parse_cmap(data, tables)
}

///|
fn parse_maxp_checked(
  data : Bytes,
  tables : Map[String, TableRecord],
) -> Result[Int, FontParseError] {
  let maxp = match require_table(data, tables, "maxp") {
    Err(error) => return Err(error)
    Ok(table) => table
  }
  match require_min_length(maxp, 6) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let maxp_offset = maxp.offset.reinterpret_as_int()
  Ok(read_u16_be_at(data, maxp_offset + 4).to_int())
}

///|
fn parse_loca_checked(
  data : Bytes,
  tables : Map[String, TableRecord],
  index_to_loc_format : Int,
  num_glyphs : Int,
) -> Result[Array[Int], FontParseError] {
  let loca = match require_table(data, tables, "loca") {
    Err(error) => return Err(error)
    Ok(table) => table
  }
  let required_loca_len = if index_to_loc_format is 0 {
    (num_glyphs + 1) * 2
  } else {
    (num_glyphs + 1) * 4
  }
  match require_min_length(loca, required_loca_len) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let loca_offset = loca.offset.reinterpret_as_int()
  let offsets = []
  for i in 0..<=num_glyphs {
    if index_to_loc_format is 0 {
      offsets.push(read_u16_be_at(data, loca_offset + i * 2).to_int() * 2)
    } else {
      offsets.push(
        read_u32_be_at(data, loca_offset + i * 4).reinterpret_as_int(),
      )
    }
  }
  Ok(offsets)
}

///|
fn parse_glyf_checked(
  data : Bytes,
  tables : Map[String, TableRecord],
  loca : Array[Int],
  index_to_loc_format : Int,
  num_glyphs : Int,
) -> Result[(Array[GlyphData], Int), FontParseError] {
  let loca_table = match require_table(data, tables, "loca") {
    Err(error) => return Err(error)
    Ok(table) => table
  }
  let glyf = match require_table(data, tables, "glyf") {
    Err(error) => return Err(error)
    Ok(table) => table
  }
  match
    validate_loca_offsets(
      data, loca_table, glyf, index_to_loc_format, num_glyphs,
    ) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  match validate_glyf_table(data, glyf, loca) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  parse_glyf_data_checked(data, glyf, loca)
}

///|
fn parse_kern_checked(
  data : Bytes,
  tables : Map[String, TableRecord],
) -> Result[Array[KernPair], FontParseError] {
  parse_kern(data, tables)
}

///|
fn require_table(
  data : Bytes,
  tables : Map[String, TableRecord],
  tag : String,
) -> Result[TableRecord, FontParseError] {
  let table = match tables.get(tag) {
    Some(table) => table
    None => return Err(FontParseError::MissingTable(tag))
  }
  match require_table_bounds(data, table) {
    Err(error) => Err(error)
    Ok(_) => Ok(table)
  }
}

///|
fn require_table_bounds(
  data : Bytes,
  table : TableRecord,
) -> Result[Unit, FontParseError] {
  let offset = table.offset.reinterpret_as_int()
  let length = table.length.reinterpret_as_int()
  guard offset >= 0 &&
    length >= 0 &&
    offset <= data.length() &&
    length <= data.length() - offset else {
    return Err(
      FontParseError::TableOutOfBounds(table.tag, offset, length, data.length()),
    )
  }
  Ok(())
}

///|
fn require_min_length(
  table : TableRecord,
  minimum : Int,
) -> Result[Unit, FontParseError] {
  let length = table.length.reinterpret_as_int()
  guard length >= minimum else {
    return Err(FontParseError::TableTooShort(table.tag, length, minimum))
  }
  Ok(())
}

///|
fn validate_loca_offsets(
  data : Bytes,
  loca : TableRecord,
  glyf : TableRecord,
  index_to_loc_format : Int,
  num_glyphs : Int,
) -> Result[Unit, FontParseError] {
  let loca_offset = loca.offset.reinterpret_as_int()
  let glyf_len = glyf.length.reinterpret_as_int()
  let loca_entry_size = if index_to_loc_format is 0 { 2 } else { 4 }
  let mut previous = 0
  for i in 0..<=num_glyphs {
    let entry_offset = loca_offset + i * loca_entry_size
    let glyph_offset = if index_to_loc_format is 0 {
      read_u16_be_at(data, entry_offset).to_int() * 2
    } else {
      read_u32_be_at(data, entry_offset).reinterpret_as_int()
    }
    guard glyph_offset >= previous else {
      return Err(FontParseError::UnsortedLocaOffsets)
    }
    guard glyph_offset <= glyf_len else {
      return Err(
        FontParseError::TableOutOfBounds(
          "glyf",
          glyf.offset.reinterpret_as_int() + glyph_offset,
          0,
          data.length(),
        ),
      )
    }
    previous = glyph_offset
  }
  Ok(())
}

///|
fn validate_glyf_table(
  data : Bytes,
  glyf : TableRecord,
  loca : Array[Int],
) -> Result[Unit, FontParseError] {
  let glyf_offset = glyf.offset.reinterpret_as_int()
  for i in 0..<(loca.length() - 1) {
    let offset = loca[i]
    let next_offset = loca[i + 1]
    if offset < next_offset {
      let glyph_length = next_offset - offset
      match validate_glyph_data(data, glyf_offset + offset, glyph_length) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
    }
  }
  Ok(())
}

///|
fn parse_glyf_data_checked(
  data : Bytes,
  glyf : TableRecord,
  loca : Array[Int],
) -> Result[(Array[GlyphData], Int), FontParseError] {
  let glyf_offset = glyf.offset.reinterpret_as_int()
  let glyph_count = loca.length() - 1
  let glyphs = []

  // CJK fonts can have many glyphs; keep the historical parse limit.
  let max_glyphs = if glyph_count > 65536 { 65536 } else { glyph_count }
  for i in 0..<max_glyphs {
    let offset = loca[i]
    let next_offset = loca[i + 1]

    if offset >= next_offset {
      glyphs.push(GlyphData::Empty)
    } else {
      let glyph_data = match
        parse_glyph_checked(data, glyf_offset + offset, next_offset - offset) {
        Err(error) => return Err(error)
        Ok(glyph) => glyph
      }
      glyphs.push(glyph_data)
    }
  }
  for _ in max_glyphs..<glyph_count {
    glyphs.push(GlyphData::Empty)
  }

  Ok((glyphs, glyph_count))
}

///|
fn parse_glyph_checked(
  data : Bytes,
  offset : Int,
  length : Int,
) -> Result[GlyphData, FontParseError] {
  match require_glyph_bytes(length, 0, 10) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let num_contours = read_i16_be_at(data, offset)
  let xmin = read_i16_be_at(data, offset + 2)
  let ymin = read_i16_be_at(data, offset + 4)
  let xmax = read_i16_be_at(data, offset + 6)
  let ymax = read_i16_be_at(data, offset + 8)

  guard num_contours != 0 else { return Ok(GlyphData::Empty) }
  if num_contours > 0 {
    parse_simple_glyph_checked(
      data, offset, length, num_contours, xmin, ymin, xmax, ymax,
    )
  } else {
    parse_composite_glyph_checked(data, offset, length)
  }
}

///|
fn parse_simple_glyph_checked(
  data : Bytes,
  offset : Int,
  length : Int,
  num_contours : Int,
  xmin : Int,
  ymin : Int,
  xmax : Int,
  ymax : Int,
) -> Result[GlyphData, FontParseError] {
  let mut pos = 10
  let end_points_len = num_contours * 2
  match require_glyph_bytes(length, pos, end_points_len) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let end_pts_of_contour = []
  let mut previous_end_point = -1
  for i in 0..<num_contours {
    let end_point = read_u16_be_at(data, offset + pos + i * 2).to_int()
    guard end_point > previous_end_point else {
      return Err(FontParseError::UnsortedGlyphContourEndpoints)
    }
    end_pts_of_contour.push(end_point)
    previous_end_point = end_point
  }
  pos = pos + end_points_len
  match require_glyph_bytes(length, pos, 2) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let instruction_length = read_u16_be_at(data, offset + pos).to_int()
  pos = pos + 2
  match require_glyph_bytes(length, pos, instruction_length) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  pos = pos + instruction_length

  let num_points = previous_end_point + 1
  let flags : Array[Int] = []
  while flags.length() < num_points {
    match require_glyph_bytes(length, pos, 1) {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
    let flag = data[offset + pos].to_int()
    pos = pos + 1
    flags.push(flag)
    if flag.land(0x08) != 0 {
      match require_glyph_bytes(length, pos, 1) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      let repeat_count = data[offset + pos].to_int()
      pos = pos + 1
      for _ in 0..<repeat_count {
        flags.push(flag)
      }
      guard flags.length() <= num_points else {
        return Err(FontParseError::GlyphFlagRepeatOverflow)
      }
    }
  }

  let x_coords = []
  let mut prev_x = 0
  for idx in 0..<num_points {
    let flag = flags[idx]
    let dx = if flag.land(0x02) != 0 {
      match require_glyph_bytes(length, pos, 1) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      let value = data[offset + pos].to_int()
      pos = pos + 1
      if flag.land(0x10) != 0 {
        value
      } else {
        -value
      }
    } else if flag.land(0x10) != 0 {
      0
    } else {
      match require_glyph_bytes(length, pos, 2) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      let value = read_i16_be_at(data, offset + pos)
      pos = pos + 2
      value
    }
    prev_x = prev_x + dx
    x_coords.push(prev_x)
  }

  let y_coords = []
  let mut prev_y = 0
  for idx in 0..<num_points {
    let flag = flags[idx]
    let dy = if flag.land(0x04) != 0 {
      match require_glyph_bytes(length, pos, 1) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      let value = data[offset + pos].to_int()
      pos = pos + 1
      if flag.land(0x20) != 0 {
        value
      } else {
        -value
      }
    } else if flag.land(0x20) != 0 {
      0
    } else {
      match require_glyph_bytes(length, pos, 2) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      let value = read_i16_be_at(data, offset + pos)
      pos = pos + 2
      value
    }
    prev_y = prev_y + dy
    y_coords.push(prev_y)
  }

  let contours = []
  let mut point_start = 0
  for ci in 0..<num_contours {
    let point_end = end_pts_of_contour[ci] + 1
    let points = []
    for pi in point_start..<point_end {
      let on_curve = flags[pi].land(0x01) != 0
      points.push({ x: x_coords[pi], y: y_coords[pi], on_curve })
    }
    contours.push({ points, })
    point_start = point_end
  }

  Ok(GlyphData::Simple({ contours, xmin, ymin, xmax, ymax }))
}

///|
fn parse_composite_glyph_checked(
  data : Bytes,
  offset : Int,
  length : Int,
) -> Result[GlyphData, FontParseError] {
  let components = []

  let arg_1_and_2_are_words = 0x0001
  let args_are_xy_values = 0x0002
  let we_have_a_scale = 0x0008
  let more_components = 0x0020
  let we_have_an_x_and_y_scale = 0x0040
  let we_have_a_two_by_two = 0x0080

  let mut pos = 10
  let mut has_more = true
  while has_more {
    match require_glyph_bytes(length, pos, 4) {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
    let flags = read_u16_be_at(data, offset + pos).to_int()
    let glyph_index = read_u16_be_at(data, offset + pos + 2).to_int()
    pos = pos + 4

    let (x_offset, y_offset) = if flags.land(arg_1_and_2_are_words) != 0 {
      match require_glyph_bytes(length, pos, 4) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      let x = read_i16_be_at(data, offset + pos)
      let y = read_i16_be_at(data, offset + pos + 2)
      pos = pos + 4
      (x, y)
    } else {
      match require_glyph_bytes(length, pos, 2) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      let arg1 = read_i8_at(data, offset + pos)
      let arg2 = read_i8_at(data, offset + pos + 1)
      pos = pos + 2
      if flags.land(args_are_xy_values) != 0 {
        (arg1, arg2)
      } else {
        (0, 0)
      }
    }

    let (scale_x, scale_y, scale_xy, scale_yx) = if flags.land(we_have_a_scale) !=
      0 {
      match require_glyph_bytes(length, pos, 2) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      let scale = read_i16_be_at(data, offset + pos).to_double() / 16384.0
      pos = pos + 2
      (scale, scale, 0.0, 0.0)
    } else if flags.land(we_have_an_x_and_y_scale) != 0 {
      match require_glyph_bytes(length, pos, 4) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      let sx = read_i16_be_at(data, offset + pos).to_double() / 16384.0
      let sy = read_i16_be_at(data, offset + pos + 2).to_double() / 16384.0
      pos = pos + 4
      (sx, sy, 0.0, 0.0)
    } else if flags.land(we_have_a_two_by_two) != 0 {
      match require_glyph_bytes(length, pos, 8) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      let sx = read_i16_be_at(data, offset + pos).to_double() / 16384.0
      let sxy = read_i16_be_at(data, offset + pos + 2).to_double() / 16384.0
      let syx = read_i16_be_at(data, offset + pos + 4).to_double() / 16384.0
      let sy = read_i16_be_at(data, offset + pos + 6).to_double() / 16384.0
      pos = pos + 8
      (sx, sy, sxy, syx)
    } else {
      (1.0, 1.0, 0.0, 0.0)
    }

    components.push({
      glyph_index,
      x_offset,
      y_offset,
      scale_x,
      scale_y,
      scale_xy,
      scale_yx,
    })

    has_more = flags.land(more_components) != 0
  }

  Ok(GlyphData::Composite(components))
}

///|
fn validate_glyph_data(
  data : Bytes,
  offset : Int,
  length : Int,
) -> Result[Unit, FontParseError] {
  match require_glyph_bytes(length, 0, 10) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let num_contours = read_i16_be_at(data, offset)
  guard num_contours != 0 else { return Ok(()) }
  if num_contours > 0 {
    validate_simple_glyph_data(data, offset, length, num_contours)
  } else {
    validate_composite_glyph_data(data, offset, length)
  }
}

///|
fn validate_simple_glyph_data(
  data : Bytes,
  offset : Int,
  length : Int,
  num_contours : Int,
) -> Result[Unit, FontParseError] {
  let mut pos = 10
  let end_points_len = num_contours * 2
  match require_glyph_bytes(length, pos, end_points_len) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let mut previous_end_point = -1
  for i in 0..<num_contours {
    let end_point = read_u16_be_at(data, offset + pos + i * 2).to_int()
    guard end_point > previous_end_point else {
      return Err(FontParseError::UnsortedGlyphContourEndpoints)
    }
    previous_end_point = end_point
  }
  pos = pos + end_points_len
  match require_glyph_bytes(length, pos, 2) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let instruction_length = read_u16_be_at(data, offset + pos).to_int()
  pos = pos + 2
  match require_glyph_bytes(length, pos, instruction_length) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  pos = pos + instruction_length

  let num_points = previous_end_point + 1
  let flags = []
  while flags.length() < num_points {
    match require_glyph_bytes(length, pos, 1) {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
    let flag = data[offset + pos].to_int()
    pos = pos + 1
    flags.push(flag)
    if flag.land(0x08) != 0 {
      match require_glyph_bytes(length, pos, 1) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      let repeat_count = data[offset + pos].to_int()
      pos = pos + 1
      for _ in 0..<repeat_count {
        flags.push(flag)
      }
    }
  }

  let x_bytes = glyph_coordinate_bytes(flags, num_points, is_x=true)
  match require_glyph_bytes(length, pos, x_bytes) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  pos = pos + x_bytes
  let y_bytes = glyph_coordinate_bytes(flags, num_points, is_x=false)
  match require_glyph_bytes(length, pos, y_bytes) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  Ok(())
}

///|
fn validate_composite_glyph_data(
  data : Bytes,
  offset : Int,
  length : Int,
) -> Result[Unit, FontParseError] {
  let arg_1_and_2_are_words = 0x0001
  let more_components = 0x0020
  let we_have_a_scale = 0x0008
  let we_have_an_x_and_y_scale = 0x0040
  let we_have_a_two_by_two = 0x0080

  let mut pos = 10
  let mut has_more = true
  while has_more {
    match require_glyph_bytes(length, pos, 4) {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
    let flags = read_u16_be_at(data, offset + pos).to_int()
    pos = pos + 4
    let argument_len = if flags.land(arg_1_and_2_are_words) != 0 {
      4
    } else {
      2
    }
    match require_glyph_bytes(length, pos, argument_len) {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
    pos = pos + argument_len
    let scale_len = if flags.land(we_have_a_scale) != 0 {
      2
    } else if flags.land(we_have_an_x_and_y_scale) != 0 {
      4
    } else if flags.land(we_have_a_two_by_two) != 0 {
      8
    } else {
      0
    }
    match require_glyph_bytes(length, pos, scale_len) {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
    pos = pos + scale_len
    has_more = flags.land(more_components) != 0
  }
  Ok(())
}

///|
fn glyph_coordinate_bytes(
  flags : Array[Int],
  num_points : Int,
  is_x~ : Bool,
) -> Int {
  let short_vector = if is_x { 0x02 } else { 0x04 }
  let same_or_positive = if is_x { 0x10 } else { 0x20 }
  let mut total = 0
  for i in 0..<num_points {
    let flag = flags[i]
    if flag.land(short_vector) != 0 {
      total = total + 1
    } else if flag.land(same_or_positive) == 0 {
      total = total + 2
    }
  }
  total
}

///|
fn require_glyph_bytes(
  glyph_length : Int,
  pos : Int,
  required : Int,
) -> Result[Unit, FontParseError] {
  guard pos >= 0 &&
    required >= 0 &&
    pos <= glyph_length &&
    required <= glyph_length - pos else {
    return Err(
      FontParseError::TableTooShort("glyf", glyph_length, pos + required),
    )
  }
  Ok(())
}

///|
fn require_table_bytes(
  tag : String,
  table_length : Int,
  pos : Int,
  required : Int,
) -> Result[Unit, FontParseError] {
  guard pos >= 0 &&
    required >= 0 &&
    pos <= table_length &&
    required <= table_length - pos else {
    return Err(FontParseError::TableTooShort(tag, table_length, pos + required))
  }
  Ok(())
}

///|
fn require_cmap_subtable_offset(
  table : TableRecord,
  subtable_offset : Int,
  data_length : Int,
) -> Result[Unit, FontParseError] {
  let table_length = table.length.reinterpret_as_int()
  guard subtable_offset >= 0 && subtable_offset < table_length else {
    return Err(
      FontParseError::TableOutOfBounds(
        table.tag,
        table.offset.reinterpret_as_int() + subtable_offset,
        0,
        data_length,
      ),
    )
  }
  Ok(())
}

///|
fn read_u16_be_at(data : Bytes, offset : Int) -> UInt16 {
  let hi = data[offset].to_uint16()
  let lo = data[offset + 1].to_uint16()
  (hi << 8) | lo
}

///|
fn read_i16_be_at(data : Bytes, offset : Int) -> Int {
  let value = read_u16_be_at(data, offset).to_int()
  if value > 32767 {
    value - 65536
  } else {
    value
  }
}

///|
fn read_i8_at(data : Bytes, offset : Int) -> Int {
  let value = data[offset].to_int()
  if value > 127 {
    value - 256
  } else {
    value
  }
}

///|
fn read_u32_be_at(data : Bytes, offset : Int) -> UInt {
  let b1 = data[offset].to_uint()
  let b2 = data[offset + 1].to_uint()
  let b3 = data[offset + 2].to_uint()
  let b4 = data[offset + 3].to_uint()
  (b1 << 24) | (b2 << 16) | (b3 << 8) | b4
}

///|
fn read_tag_at(data : Bytes, offset : Int) -> String {
  let sb = StringBuilder()
  sb.write_char(data[offset].to_uint16().unsafe_to_char())
  sb.write_char(data[offset + 1].to_uint16().unsafe_to_char())
  sb.write_char(data[offset + 2].to_uint16().unsafe_to_char())
  sb.write_char(data[offset + 3].to_uint16().unsafe_to_char())
  sb.to_string()
}

///|
/// Parse cmap table (supports format 4 and format 12)
fn parse_cmap(
  data : Bytes,
  tables : Map[String, TableRecord],
) -> Result[Map[Int, Int], FontParseError] {
  let table = match require_table(data, tables, "cmap") {
    Err(error) => return Err(error)
    Ok(table) => table
  }
  match require_min_length(table, 4) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let base_offset = table.offset.reinterpret_as_int()
  let table_length = table.length.reinterpret_as_int()
  let cmap : Map[Int, Int] = {}

  let version = read_u16_be_at(data, base_offset).to_int()
  guard version is 0 else {
    return Err(FontParseError::UnsupportedCmapVersion(version))
  }
  let num_tables = read_u16_be_at(data, base_offset + 2).to_int()
  match require_table_bytes("cmap", table_length, 0, 4 + num_tables * 8) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }

  let mut format4_offset = -1
  let mut format12_offset = -1
  for i in 0..<num_tables {
    let record_pos = 4 + i * 8
    let platform_id = read_u16_be_at(data, base_offset + record_pos).to_int()
    let encoding_id = read_u16_be_at(data, base_offset + record_pos + 2).to_int()
    let subtable_offset = read_u32_be_at(data, base_offset + record_pos + 4).reinterpret_as_int()
    match require_cmap_subtable_offset(table, subtable_offset, data.length()) {
      Err(error) => return Err(error)
      Ok(_) => ()
    }

    // Prefer format 12 (full Unicode) over format 4 (BMP only).
    if platform_id is 0 && encoding_id is 4 {
      format12_offset = subtable_offset
    } else if platform_id is 3 && encoding_id is 10 {
      format12_offset = subtable_offset
    } else if platform_id is 3 && encoding_id is 1 {
      format4_offset = subtable_offset
    }
  }

  if format12_offset >= 0 {
    let result = match parse_cmap_format12(data, table, format12_offset) {
      Err(error) => return Err(error)
      Ok(result) => result
    }
    if result.length() > 0 {
      return Ok(result)
    }
  }

  if format4_offset >= 0 {
    return parse_cmap_format4(data, table, format4_offset)
  }

  Ok(cmap)
}

///|
/// Parse cmap format 4 subtable (BMP characters)
fn parse_cmap_format4(
  data : Bytes,
  table : TableRecord,
  subtable_offset : Int,
) -> Result[Map[Int, Int], FontParseError] {
  let cmap : Map[Int, Int] = {}
  let table_base = table.offset.reinterpret_as_int()
  let table_length = table.length.reinterpret_as_int()
  match require_table_bytes("cmap", table_length, subtable_offset, 4) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let offset = table_base + subtable_offset
  let format = read_u16_be_at(data, offset).to_int()
  guard format is 4 else { return Ok(cmap) }

  let subtable_length = read_u16_be_at(data, offset + 2).to_int()
  guard subtable_length >= 16 else {
    return Err(FontParseError::TableTooShort("cmap", subtable_length, 16))
  }
  match
    require_table_bytes("cmap", table_length, subtable_offset, subtable_length) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }

  let seg_count_x2 = read_u16_be_at(data, offset + 6).to_int()
  guard (seg_count_x2 % 2) is 0 else {
    return Err(FontParseError::InvalidCmapSegmentCount(seg_count_x2))
  }
  let seg_count = seg_count_x2 / 2
  let required_length = 16 + seg_count * 8
  guard required_length <= subtable_length else {
    return Err(
      FontParseError::TableTooShort("cmap", subtable_length, required_length),
    )
  }

  let end_codes_offset = 14
  let start_codes_offset = end_codes_offset + seg_count * 2 + 2
  let id_deltas_offset = start_codes_offset + seg_count * 2
  let id_range_offsets_offset = id_deltas_offset + seg_count * 2
  let end_codes = []
  let start_codes = []
  let id_deltas = []
  let id_range_offsets = []
  for i in 0..<seg_count {
    end_codes.push(
      read_u16_be_at(data, offset + end_codes_offset + i * 2).to_int(),
    )
    start_codes.push(
      read_u16_be_at(data, offset + start_codes_offset + i * 2).to_int(),
    )
    id_deltas.push(read_i16_be_at(data, offset + id_deltas_offset + i * 2))
    id_range_offsets.push(
      read_u16_be_at(data, offset + id_range_offsets_offset + i * 2).to_int(),
    )
  }

  for i in 0..<seg_count {
    let start = start_codes[i]
    let end = end_codes[i]
    let delta = id_deltas[i]
    let range_offset = id_range_offsets[i]
    guard start <= end else {
      return Err(FontParseError::InvalidCmapSegmentRange(start, end))
    }

    for c in start..<=end {
      let glyph_id = if range_offset is 0 {
        (c + delta) % 65536
      } else {
        let range_offset_location = id_range_offsets_offset + i * 2
        let glyph_rel = range_offset_location + range_offset + (c - start) * 2
        match require_table_bytes("cmap", subtable_length, glyph_rel, 2) {
          Err(error) => return Err(error)
          Ok(_) => ()
        }
        let gid = read_u16_be_at(data, offset + glyph_rel).to_int()
        if gid is 0 {
          0
        } else {
          (gid + delta) % 65536
        }
      }
      if glyph_id > 0 {
        cmap[c] = glyph_id
      }
    }
  }

  Ok(cmap)
}

///|
/// Parse cmap format 12 subtable (full Unicode repertoire)
fn parse_cmap_format12(
  data : Bytes,
  table : TableRecord,
  subtable_offset : Int,
) -> Result[Map[Int, Int], FontParseError] {
  let cmap : Map[Int, Int] = {}
  let table_base = table.offset.reinterpret_as_int()
  let table_length = table.length.reinterpret_as_int()
  match require_table_bytes("cmap", table_length, subtable_offset, 16) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let offset = table_base + subtable_offset
  let format = read_u16_be_at(data, offset).to_int()
  guard format is 12 else { return Ok(cmap) }

  let subtable_length = read_u32_be_at(data, offset + 4).reinterpret_as_int()
  guard subtable_length >= 16 else {
    return Err(FontParseError::TableTooShort("cmap", subtable_length, 16))
  }
  match
    require_table_bytes("cmap", table_length, subtable_offset, subtable_length) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let n_groups = read_u32_be_at(data, offset + 12).reinterpret_as_int()
  guard n_groups >= 0 && n_groups <= (subtable_length - 16) / 12 else {
    return Err(
      FontParseError::TableTooShort("cmap", subtable_length, 16 + n_groups * 12),
    )
  }

  for i in 0..<n_groups {
    let group_pos = 16 + i * 12
    let start_char_code = read_u32_be_at(data, offset + group_pos).reinterpret_as_int()
    let end_char_code = read_u32_be_at(data, offset + group_pos + 4).reinterpret_as_int()
    let start_glyph_id = read_u32_be_at(data, offset + group_pos + 8).reinterpret_as_int()
    guard start_char_code >= 0 &&
      end_char_code >= start_char_code &&
      end_char_code <= 0x10FFFF else {
      return Err(
        FontParseError::InvalidCmapGroupRange(start_char_code, end_char_code),
      )
    }

    for c in start_char_code..<=end_char_code {
      let glyph_id = start_glyph_id + (c - start_char_code)
      cmap[c] = glyph_id
    }
  }

  Ok(cmap)
}

///|
/// Parse kern table
fn parse_kern(
  data : Bytes,
  tables : Map[String, TableRecord],
) -> Result[Array[KernPair], FontParseError] {
  let kern = []

  match tables.get("kern") {
    Some(table) => {
      match require_table_bounds(data, table) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      match require_min_length(table, 4) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }

      let offset = table.offset.reinterpret_as_int()
      let table_length = table.length.reinterpret_as_int()
      let version = read_u16_be_at(data, offset).to_int()
      guard version is 0 else { return Ok(kern) }

      let n_tables = read_u16_be_at(data, offset + 2).to_int()
      let mut pos = 4

      for _ in 0..<n_tables {
        match require_table_bytes("kern", table_length, pos, 6) {
          Err(error) => return Err(error)
          Ok(_) => ()
        }
        let subtable_length = read_u16_be_at(data, offset + pos + 2).to_int()
        let coverage = read_u16_be_at(data, offset + pos + 4).to_int()
        guard subtable_length >= 6 else {
          return Err(FontParseError::TableTooShort("kern", subtable_length, 6))
        }
        match require_table_bytes("kern", table_length, pos, subtable_length) {
          Err(error) => return Err(error)
          Ok(_) => ()
        }

        let format = (coverage >> 8).land(0xFF)
        if format is 0 {
          guard subtable_length >= 14 else {
            return Err(
              FontParseError::TableTooShort("kern", subtable_length, 14),
            )
          }
          let n_pairs = read_u16_be_at(data, offset + pos + 6).to_int()
          let required_length = 14 + n_pairs * 6
          guard required_length <= subtable_length else {
            return Err(
              FontParseError::TableTooShort(
                "kern", subtable_length, required_length,
              ),
            )
          }
          let pairs_offset = pos + 14
          for i in 0..<n_pairs {
            let pair_pos = pairs_offset + i * 6
            let left = read_u16_be_at(data, offset + pair_pos).to_int()
            let right = read_u16_be_at(data, offset + pair_pos + 2).to_int()
            let value = read_i16_be_at(data, offset + pair_pos + 4)
            kern.push({ left, right, value })
          }
        }
        pos = pos + subtable_length
      }
    }
    None =>
      // No kern table
      ignore(0)
  }

  Ok(kern)
}
