///|
pub fn[Msg] web_view(
  id~ : String,
  url~ : String,
  width? : Double? = None,
  height? : Double? = None,
  title? : String = "",
  policy? : @core.WebViewNavigationPolicy = @core.WebViewNavigationPolicy::AllowHttpHttpsFile,
  on_event? : ((@core.WebViewEvent) -> Msg)? = None,
) -> @core.View[Msg] {
  @core.View::primitive_web_view(
    id~,
    url~,
    width~,
    height~,
    title~,
    policy~,
    on_event~,
  )
}
