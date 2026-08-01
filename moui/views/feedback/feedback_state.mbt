// FeedbackTone and BadgeTone moved to style/ sub-package.
// StateViewAction moved to controls/ sub-package and re-exported here.

///|
pub using @controls {type StateViewAction}

///|
pub struct ToastStackItem[Msg] {
  id : String
  message : String
  tone : @style.FeedbackTone
  action : StateViewAction[Msg]?
  dismiss : Msg?
}

///|
pub struct ToastQueueItem[Msg] {
  id : String
  message : String
  tone : @style.FeedbackTone
  action : StateViewAction[Msg]?
  dismiss : Msg?
  created_at_ms : Double
  ttl_ms : Double
}

///|
pub struct ToastQueue[Msg] {
  items : Array[ToastQueueItem[Msg]]
}

///|
pub fn[Msg] ToastStackItem::new(
  id~ : String,
  message~ : String,
  tone? : @style.FeedbackTone = @style.FeedbackTone::Neutral,
  action? : StateViewAction[Msg]? = None,
  dismiss? : Msg? = None,
) -> ToastStackItem[Msg] {
  { id, message, tone, action, dismiss }
}

///|
pub fn[Msg] ToastQueueItem::new(
  id~ : String,
  message~ : String,
  tone? : @style.FeedbackTone = @style.FeedbackTone::Neutral,
  action? : StateViewAction[Msg]? = None,
  dismiss? : Msg? = None,
  created_at_ms? : Double = 0.0,
  ttl_ms? : Double = 0.0,
) -> ToastQueueItem[Msg] {
  { id, message, tone, action, dismiss, created_at_ms, ttl_ms }
}

///|
pub fn[Msg] ToastQueue::new(
  items? : Array[ToastQueueItem[Msg]] = [],
) -> ToastQueue[Msg] {
  { items: items.copy() }
}

///|
pub fn[Msg] ToastQueue::push(
  self : ToastQueue[Msg],
  item : ToastQueueItem[Msg],
) -> ToastQueue[Msg] {
  let items = self.items.filter(existing => existing.id != item.id)
  items.push(item)
  ToastQueue::new(items~)
}

///|
pub fn[Msg] ToastQueue::expire(
  self : ToastQueue[Msg],
  now_ms : Double,
) -> ToastQueue[Msg] {
  ToastQueue::new(
    items=self.items.filter(item => {
      item.ttl_ms <= 0.0 || now_ms - item.created_at_ms < item.ttl_ms
    }),
  )
}

///|
pub fn[Msg] ToastQueue::to_stack_items(
  self : ToastQueue[Msg],
) -> Array[ToastStackItem[Msg]] {
  self.items.map(item => {
    ToastStackItem::new(
      id=item.id,
      message=item.message,
      tone=item.tone,
      action=item.action,
      dismiss=item.dismiss,
    )
  })
}
