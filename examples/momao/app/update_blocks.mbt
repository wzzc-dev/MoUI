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
                @momao_lang.render_stmts([stmt], model.language.dsl_language())
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
              @momao_lang.parse_handler_body(
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
    SelectBlock(index) =>
      Some((select_block(model, index), @moui.Effect::none()))
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
      // 按上积木：选中并建立同层拖拽态；落空清除
      let blocks = block_chain_of(model)
      let hit = blocks_hit_index(blocks, x, y)
      if hit >= 0 && blocks[hit].path.length() > 0 {
        let item = blocks[hit]
        let list_path = blocks_parent_of(item.path)
        let sibling_index = item.path[item.path.length() - 1]
        let next = select_block(model, hit)
        Some(
          (
            {
              ..next,
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
          let selected = if hit >= 0 { hit } else { next.selected_block }
          Some(
            (
              { ..next, block_drag: None, selected_block: selected, },
              @moui.Effect::none(),
            ),
          )
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
    DeleteBlock =>
      Some(
        (with_undo_point(model, "", m => delete_block(m)), @moui.Effect::none()),
      )
    _ => None
  }
}
