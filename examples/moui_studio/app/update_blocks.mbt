///|
/// 积木域状态转移：选中/编辑/提交/删除，全部经语句路径写回 IR。

///|
/// 当前选中 handler 的积木链（无选中子程序 = 空链）。
pub fn block_chain_of(model : Model) -> Array[@blocks.BlockItem] {
  match current_handler(model) {
    None => []
    Some(handler) => @blocks.block_chain(handler.body)
  }
}

///|
fn block_at(
  blocks : Array[@blocks.BlockItem],
  index : Int,
) -> @blocks.BlockItem? {
  if index < 0 || index >= blocks.length() {
    None
  } else {
    Some(blocks[index])
  }
}

///|
/// 选中积木：把该语句的 DSL 源码预填进编辑草稿。
fn select_block(model : Model, index : Int) -> Model {
  let blocks = block_chain_of(model)
  let draft = match block_at(blocks, index) {
    Some(item) =>
      if item.path.length() == 0 {
        ""
      } else {
        match current_handler(model) {
          None => ""
          Some(handler) =>
            match @blocks.stmt_at(handler.body, item.path) {
              Some(stmt) =>
                @studio_lang.render_stmts([stmt], model.language.dsl_language())
                .trim_end()
                .to_owned()
              None => ""
            }
        }
      }
    None => ""
  }
  { ..model, selected_block: index, block_draft: draft, }
}

///|
/// 按语句路径选中积木（编译诊断行号 → 生成源码里的语句路径 → 此处）。
/// 与 `SelectBlock` 的区别是入口按路径而非链下标，供「编译错误点击跳积木」
/// 使用：路径是 IR 的稳定坐标，链下标随展开块（if/end）变化。
pub fn select_block_by_path(model : Model, path : Array[Int]) -> Model {
  if path.length() == 0 {
    return model
  }
  let blocks = block_chain_of(model)
  let mut index = -1
  let mut i = 0
  while i < blocks.length() {
    if index == -1 && blocks_same_path(blocks[i].path, path) {
      index = i
    }
    i = i + 1
  }
  if index == -1 {
    model
  } else {
    select_block({ ..model, mode: ModeBlocks, }, index)
  }
}

///|
/// 积木编辑回写：草稿解析成单条语句 → 按路径替换 → IR 更新 →
/// 代码视图草稿与积木选择同步刷新（三视图同源）。
fn commit_block(model : Model) -> Model {
  match current_handler(model) {
    None => model
    Some(handler) => {
      let blocks = block_chain_of(model)
      match block_at(blocks, model.selected_block) {
        None => model
        Some(item) =>
          if item.path.length() == 0 {
            model
          } else {
            match
              @studio_lang.parse_handler_body(
                model.block_draft,
                model.language.dsl_language(),
              ) {
              Err(_) =>
                {
                  ..model,
                  notice: text(translator(model), "app.status.parse_error"),
                }
              Ok(body) =>
                if body.length() == 0 {
                  model
                } else {
                  // 克隆后再手术：replace_stmt_at 是就地语义，
                  // 直接改 handler.body 会污染撤销快照（共享数组引用）
                  let working = @blocks.clone_stmts(handler.body)
                  let updated = @blocks.replace_stmt_at(
                    working,
                    item.path,
                    body[0].stmt,
                  )
                  let next = replace_handler_body(model, handler, updated)
                  // 同步代码视图（同一份 IR 的另一种渲染）
                  let synced = sync_code_draft(next)
                  { ..synced, notice: "", }
                }
            }
          }
      }
    }
  }
}

///|
/// 积木删除回写：按路径删除语句并同步其他视图。
fn delete_block(model : Model) -> Model {
  match current_handler(model) {
    None => model
    Some(handler) => {
      let blocks = block_chain_of(model)
      match block_at(blocks, model.selected_block) {
        None => model
        Some(item) =>
          if item.path.length() == 0 {
            model
          } else {
            // 同上：克隆后再手术（撤销快照安全）
            let working = @blocks.clone_stmts(handler.body)
            let updated = @blocks.delete_stmt_at(working, item.path)
            let next = replace_handler_body(model, handler, updated)
            let synced = sync_code_draft(next)
            { ..synced, selected_block: -1, block_draft: "", }
          }
      }
    }
  }
}

///|
/// 积木复制回写（Scratch/Blockly 的 Duplicate）：克隆选中语句插入其
/// 同层下一位，选中新副本。编辑卡上的复制图标与拖拽并列的第三条编辑路径。
fn duplicate_block(model : Model) -> Model {
  match current_handler(model) {
    None => model
    Some(handler) => {
      let blocks = block_chain_of(model)
      match block_at(blocks, model.selected_block) {
        None => model
        Some(item) =>
          if item.path.length() == 0 {
            model
          } else {
            // 克隆后再手术（撤销快照安全，同 commit/delete）
            let working = @blocks.clone_stmts(handler.body)
            let stmt = match @blocks.stmt_at(working, item.path) {
              Some(stmt) => stmt
              None => return model
            }
            let parent = blocks_parent_of(item.path)
            let index = item.path[item.path.length() - 1]
            match @blocks.stmt_list_at(working, parent) {
              // 插入到原语句之后：IR 列表与积木链同序，链下标即列表下标
              Some(list) => list.insert(index + 1, @blocks.clone_stmt(stmt))
              None => return model
            }
            let next = replace_handler_body(model, handler, working)
            let synced = sync_code_draft(next)
            let new_path = {
              let path : Array[Int] = []
              for part in parent {
                path.push(part)
              }
              path.push(index + 1)
              path
            }
            select_block_by_path(synced, new_path)
          }
      }
    }
  }
}

///|
/// 用新 body 替换选中 handler（其余 handler 原样）。
fn replace_handler_body(
  model : Model,
  handler : @ir.Handler,
  body : Array[@ir.Stmt],
) -> Model {
  let updated = @ir.Handler::{ ..handler, body, }
  let handlers : Array[@ir.Handler] = []
  for existing in model.program.handlers {
    if existing.control_name == handler.control_name &&
      existing.event.tag() == handler.event.tag() {
      handlers.push(updated)
    } else {
      handlers.push(existing)
    }
  }
  { ..model, program: { ..model.program, handlers, }, }
}

///|
/// 积木域消息处理：未命中的消息返回 None 交还链式分发。
fn update_blocks_msgs(model : Model, msg : Msg) -> (Model, @moui.Effect[Msg])? {
  match msg {
    EditBlock(source) =>
      Some(({ ..model, block_draft: source, }, @moui.Effect::none()))
    BlocksCanvasTap(x, y) =>
      // 点选积木（拖拽结束的 tap 以 block_drag 态区分，不重复选中）
      if model.block_drag is Some(_) {
        Some((model, @moui.Effect::none()))
      } else {
        let blocks = block_chain_of(model)
        let hit = blocks_hit_index(blocks, x, y)
        if hit >= 0 {
          Some((select_block(model, hit), @moui.Effect::none()))
        } else {
          Some((model, @moui.Effect::none()))
        }
      }
    BlocksCanvasPress(x, y) => {
      // 按上积木：建立同层拖拽态；落空清除。**按下不换选中**——选中决定
      // 编辑卡的拆分位置，手势中途换选中会让画布在手势进行时重构（上下段
      // 重新分配），指针捕获随元素重建而丢失，拖拽断在第一帧。选中交给
      // 松手后的 tap / 选中跟随。
      let blocks = block_chain_of(model)
      let hit = blocks_hit_index(blocks, x, y)
      if hit >= 0 && blocks[hit].path.length() > 0 {
        let item = blocks[hit]
        let list_path = blocks_parent_of(item.path)
        let sibling_index = item.path[item.path.length() - 1]
        Some(
          (
            {
              ..model,
              block_drag: Some(BlocksDragState::{
                list_path,
                from: sibling_index,
                to: sibling_index,
              }),
            },
            @moui.Effect::none(),
          ),
        )
      } else {
        Some(({ ..model, block_drag: None, }, @moui.Effect::none()))
      }
    }
    BlocksCanvasDragTo(x, y) =>
      // 拖拽中：按指针 y 更新同层落槽
      match model.block_drag {
        None => Some((model, @moui.Effect::none()))
        Some(drag) => {
          let blocks = block_chain_of(model)
          let rects = blocks_item_rects(blocks)
          let slot = blocks_drop_slot(blocks, drag.list_path, y, rects)
          Some(
            (
              { ..model, block_drag: Some({ ..drag, to: slot, }), },
              @moui.Effect::none(),
            ),
          )
        }
      }
    BlocksCanvasRelease =>
      // 松手：落槽有效（非原位/原位下一位）才重排；过撤销点
      match model.block_drag {
        None => Some((model, @moui.Effect::none()))
        Some(drag) => {
          let moved = drag.to != drag.from && drag.to != drag.from + 1
          let next = if moved {
            with_undo_point(model, "", m => {
              match current_handler(m) {
                None => m
                Some(handler) =>
                  match
                    @blocks.reorder_stmt(
                      handler.body,
                      drag.list_path,
                      drag.from,
                      drag.to,
                    ) {
                    Some(new_body) => replace_handler_body(m, handler, new_body)
                    None => m
                  }
              }
            })
          } else {
            model
          }
          // 重排后选中跟随被移动的语句（新链下标 = list_path ++ 新语句位）
          let new_stmt_index = if drag.to > drag.from {
            drag.to - 1
          } else {
            drag.to
          }
          let new_path = {
            let path : Array[Int] = []
            for part in drag.list_path {
              path.push(part)
            }
            path.push(new_stmt_index)
            path
          }
          let chain = block_chain_of(next)
          let mut hit = -1
          let mut i = 0
          for item in chain {
            if hit == -1 && blocks_same_path(item.path, new_path) {
              hit = i
            }
            i = i + 1
          }
          // 选中走 select_block：草稿与新选中同步（按下已不再即时选中，
          // 拖拽别的块时草稿还停留在旧选中上，直接改下标会错配）
          let cleared = { ..next, block_drag: None, }
          let result = if hit >= 0 {
            select_block(cleared, hit)
          } else {
            cleared
          }
          Some((result, @moui.Effect::none()))
        }
      }
    CommitBlock =>
      Some(
        (
          // 仅当语句真的写回 IR 时产生还原点（解析失败为 no-op）
          with_undo_point(model, "", m => commit_block(m)),
          @moui.Effect::none(),
        ),
      )
    DuplicateBlock =>
      Some(
        (
          // 与 commit/delete 同一口径：写回 IR 才产生还原点（no-op 不入栈）
          with_undo_point(model, "", m => duplicate_block(m)),
          @moui.Effect::none(),
        ),
      )
    DeleteBlock =>
      Some(
        (with_undo_point(model, "", m => delete_block(m)), @moui.Effect::none()),
      )
    ToggleStatementPalette(index) =>
      // 再点同一个分类 = 收起（与图标栏「再点当前项」同一心智）。
      Some(
        (
          {
            ..model,
            selected_category: index,
            statement_palette_open: if model.statement_palette_open &&
              model.selected_category == index {
              false
            } else {
              true
            },
          },
          @moui.Effect::none(),
        ),
      )
    InsertStatement(category_index, template_index) =>
      Some(
        (
          // 与 commit/delete 同一口径：写回 IR 才产生还原点
          with_recent_undo_point(
            model,
            text(translator(model), "app.recent.action.insert_stmt"),
            "app.recent.action.insert_stmt",
            m => insert_statement(m, category_index, template_index),
          ),
          @moui.Effect::none(),
        ),
      )
    _ => None
  }
}

///|
/// 插入一条语句骨架（语句面板的唯一落地路径）。
///
/// 插入位置：**选中块之后**（同层）；没有选中块则插到顶层末尾。
/// 新语句成为新的选中块，右栏编辑卡随之出现——用户可以立刻改写参数，
/// 与「插入 → 微调」的自然节奏一致。
///
/// 骨架先过 `parse_handler_body`（与手打草稿、AI 提案同一条校验链），
/// 解析失败就什么都不做并给出提示——绝不把非法语句塞进 IR。
fn insert_statement(
  model : Model,
  category_index : Int,
  template_index : Int,
) -> Model {
  let handler = match current_handler(model) {
    None =>
      return {
        ..model,
        notice: text(translator(model), "app.stmt.palette.no_handler"),
      }
    Some(handler) => handler
  }
  let category = match category_at(category_index) {
    None => return model
    Some(category) => category
  }
  let templates = templates_for_category(category)
  if template_index < 0 || template_index >= templates.length() {
    return model
  }
  let template = templates[template_index]
  let parsed = match
    @studio_lang.parse_handler_body(
      template.skeleton(model.language.dsl_language()),
      model.language.dsl_language(),
    ) {
    Err(_) =>
      return {
        ..model,
        notice: text(translator(model), "app.stmt.palette.parse_error"),
      }
    Ok(body) => body
  }
  if parsed.length() == 0 {
    return model
  }
  // 插入位置：选中块的下一行（同层）；无选中 → 顶层末尾。
  let chain = block_chain_of(model)
  let (list_path, at) = match block_at(chain, model.selected_block) {
    Some(item) if item.path.length() > 0 => {
      let parent = blocks_parent_of(item.path)
      (parent, item.path[item.path.length() - 1] + 1)
    }
    _ => {
      let top : Array[Int] = []
      (top, handler.body.length())
    }
  }
  // 一条骨架可能解析出多条语句（如「如果…结束」内部已有内容）——
  // 逐条按序插入，保持骨架内部的相对顺序。
  let mut working = @blocks.clone_stmts(handler.body)
  let mut insert_at = at
  let mut inserted = 0
  for traced in parsed {
    match @blocks.insert_stmt_at(working, list_path, insert_at, traced.stmt) {
      Some(next) => {
        working = next
        insert_at = insert_at + 1
        inserted = inserted + 1
      }
      None => ()
    }
  }
  if inserted == 0 {
    return model
  }
  let next = replace_handler_body(model, handler, working)
  let synced = sync_code_draft(next)
  // 选中新插入的第一条语句（按路径定位，链下标随展开块变化）。
  let new_path : Array[Int] = []
  for part in list_path {
    new_path.push(part)
  }
  new_path.push(at)
  let selected = select_block_by_path(
    { ..synced, statement_palette_open: false, },
    new_path,
  )
  { ..selected, notice: "", }
}
