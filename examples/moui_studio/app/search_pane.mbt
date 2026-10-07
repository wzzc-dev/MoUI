///|
/// 全文搜索面板（G4 F3,底栏 BtSearch 页签体）：查询输入 + 搜索按钮 +
/// 命中列表（点击跳转 = 切到代码工作区并打开该文件）。

///|
pub fn search_pane(
  model : Model,
  t : @i18n.Translator,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  let input_row = @views.row(
    [
      @views.text_field(
        model.search_query,
        on_input=value => SearchQueryDraft(value),
        width=(width - 130.0).max(80.0),
        height=24.0,
      ),
      foot_chip(
        text(t, "app.search.run"),
        text_estimate_width(text(t, "app.search.run")) + 24.0,
        model.search_busy,
        SearchRun,
      ),
    ],
    spacing=8.0,
    align=Center,
  )
  let hit_rows : Array[@moui.View[Msg]] = []
  for hit in model.search_hits {
    let rel = hit.rel
    let label = "\{rel}:\{hit.line}"
    hit_rows.push(
      @views.container(
        @views.column(
          [
            @views.text(
              fit_label(label, (width - 40.0).max(60.0)),
              theme=studio_theme(),
              role=Mono,
              width=(width - 40.0).max(60.0),
              height=14.0,
              align=TextStart,
            ).foreground(ide_accent()),
            @views.text(
              fit_label(hit.preview, (width - 40.0).max(60.0)),
              theme=studio_theme(),
              width=(width - 40.0).max(60.0),
              height=14.0,
              align=TextStart,
            ).foreground(ide_text()),
          ],
          spacing=1.0,
        ),
        width~,
        height=32.0,
        padding=0.0,
      ).on_tap(SearchHitClicked(rel)),
    )
  }
  let body : @moui.View[Msg] = if model.search_busy {
    @views.text(
      text(t, "app.search.running"),
      theme=studio_theme(),
      width=(width - 24.0).max(60.0),
      height=18.0,
      align=TextStart,
    ).foreground(ide_text_faint())
  } else if model.search_hits.is_empty() {
    @views.text(
      text(t, "app.search.empty"),
      theme=studio_theme(),
      width=(width - 24.0).max(60.0),
      height=18.0,
      align=TextStart,
    ).foreground(ide_text_faint())
  } else {
    @views.scroll_view(
      @views.column(hit_rows, spacing=0.0),
      width=(width - 12.0).max(80.0),
      height=(height - 40.0).max(60.0),
      shows_indicator=true,
    )
  }
  @views.container(
    @views.column([input_row, body], spacing=6.0),
    background=ide_editor_background(),
    width~,
    height~,
    padding=0.0,
  )
}
