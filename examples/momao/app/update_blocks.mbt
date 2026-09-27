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
                  let updated = @blocks.replace_stmt_at(
                    handler.body,
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
            let updated = @blocks.delete_stmt_at(handler.body, item.path)
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
    CommitBlock => Some((commit_block(model), @moui.Effect::none()))
    DeleteBlock => Some((delete_block(model), @moui.Effect::none()))
    _ => None
  }
}
