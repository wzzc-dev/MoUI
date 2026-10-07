///|
/// 工作区全文搜索（G4 F3）：对扫描树里的文本文件逐个 read_text 找子串。
/// 任务形态与 walk 同款（@services.ServiceTask + 完成回调状态机）;上限
/// 双护栏（文件数/命中数）+ 每文件命中数上限,大仓库不失控。

///|
/// 一条命中:文件 rel + 1-based 行号 + 截断摘录。
pub(all) struct SearchHit {
  rel : String
  line : Int
  preview : String
}

///|
const SEARCH_MAX_FILES : Int = 60

///|
const SEARCH_MAX_HITS : Int = 200

///|
const SEARCH_MAX_PER_FILE : Int = 8

///|
/// 摘录宽度:命中行首尾裁到 ~96 字符（中文按字符算,够读即可）。
fn search_preview(line : String) -> String {
  let trimmed = line.trim(chars=" \t").to_owned()
  if trimmed.length() <= 96 {
    return trimmed
  }
  let buf = StringBuilder()
  let mut taken = 0
  for ch in trimmed {
    if taken >= 96 {
      break
    }
    buf.write_char(ch)
    taken = taken + 1
  }
  buf.to_string() + "…"
}

///|
priv struct SearchState {
  files : @services.FileServices
  root : String
  query : String
  queue : Array[String]
  hits : Array[SearchHit]
  /// 已完整读过的文件数（上限护栏）
  mut scanned : Int
}

///|
/// 搜索任务:完成后 `Success(Array[SearchHit])`;基础设施失败走
/// `Failure`（单文件读失败跳过,不算失败——搜索要容忍个别文件读不到）。
pub fn project_search_task(
  files : @services.FileServices,
  root : String,
  targets : Array[String],
  query~ : String,
) -> @services.ServiceTask[Array[SearchHit]] {
  @services.ServiceTask::new(
    key="project:search:\{root}:\{query}",
    label="搜索 \{query}",
    start=complete => {
      let state : SearchState = SearchState::{
        files,
        root,
        query,
        queue: targets,
        hits: [],
        scanned: 0,
      }
      search_step(state, complete)
      None
    },
  )
}

///|
fn search_step(
  state : SearchState,
  complete : (@services.ServiceTaskResult[Array[SearchHit]]) -> Unit,
) -> Unit {
  // 护栏:文件数/命中数任一到顶即收
  if state.scanned >= SEARCH_MAX_FILES || state.hits.length() >= SEARCH_MAX_HITS {
    complete(Success(state.hits))
    return
  }
  let rel = match state.queue.pop() {
    Some(head) => head
    None => {
      complete(Success(state.hits))
      return
    }
  }
  state.scanned = state.scanned + 1
  let _ = (state.files.read_text_fn)("\{state.root}/\{rel}").start(result => {
    match result {
      Success(text) => {
        // 逐行找子串;单文件命中数到顶就跳到下一文件
        let mut line_no = 0
        let mut file_hits = 0
        for view in text.split("\n") {
          let line = view.to_owned()
          line_no = line_no + 1
          if file_hits >= SEARCH_MAX_PER_FILE ||
            state.hits.length() >= SEARCH_MAX_HITS {
            break
          }
          if line.contains(state.query) {
            state.hits.push(SearchHit::{
              rel,
              line: line_no,
              preview: search_preview(line),
            })
            file_hits = file_hits + 1
          }
        }
        search_step(state, complete)
      }
      // 单文件读失败 = 跳过继续（搜索的韧性口径）
      Failure(_) => search_step(state, complete)
      Cancelled => complete(Cancelled)
    }
  })
}
