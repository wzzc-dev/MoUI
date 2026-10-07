///|
/// 墙钟快照(app 自有类型):组合根把平台 HostWallClock 映射成本结构注入
/// `program(wall_clock=…)`——app 不 import runtime,时钟以**纯数据**过边界
/// (mo_desktop 的 DesktopClock 同款先例)。它是瞬时值不是定时器:需要走动
/// 的显示(AI 模式时间线/相对时间)由 1s 订阅的 ClockUpdated 每秒重取一次。
pub(all) struct StudioClock {
  year : Int
  month : Int
  day : Int
  /// 周日 = 0(与平台 FFI 同口径)
  weekday : Int
  hour : Int
  minute : Int
  second : Int
}

///|
/// 默认时钟(组合根未注入 wall_clock 时的常数,如裸测试组合根与 Web 的
/// 部分场景):2026-01-01(周四)00:00:00。测试要确定的时间戳时手动置
/// Model.clock。
pub fn default_studio_clock() -> StudioClock {
  { year: 2026, month: 1, day: 1, weekday: 4, hour: 0, minute: 0, second: 0 }
}

///|
/// 从民用日期算自 1970-01-01 起的天数(Howard Hinnant days_from_civil,
/// 公历)。整除向零截断——负年份分支的 `- 399` 正是为此。
fn days_from_civil(year : Int, month : Int, day : Int) -> Int {
  let y2 = if month <= 2 { year - 1 } else { year }
  let era = (if y2 >= 0 { y2 } else { y2 - 399 }) / 400
  let yoe = y2 - era * 400
  let mp = (month + 9) % 12
  let doy = (153 * mp + 2) / 5 + day - 1
  let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
  era * 146097 + doe - 719468
}

///|
/// 时间戳:自 epoch 起的秒数(可比较、可求差)。卡片的 at 戳、会话的
/// updated 戳、「已工作 N 秒」时长与相对时间都从它派生。
pub fn civil_seconds(clock : StudioClock) -> Int {
  days_from_civil(clock.year, clock.month, clock.day) * 86400 +
  clock.hour * 3600 +
  clock.minute * 60 +
  clock.second
}

///|
/// HH:MM 显示(时间线动作行的时间戳),24 小时制零填充。
pub fn format_hhmm(clock : StudioClock) -> String {
  let hh = if clock.hour < 10 { "0\{clock.hour}" } else { "\{clock.hour}" }
  let mm = if clock.minute < 10 { "0\{clock.minute}" } else { "\{clock.minute}" }
  "\{hh}:\{mm}"
}

///|
/// 从 civil_seconds 戳还原 HH:MM 显示(卡片只存整数戳,不存整个时钟)。
pub fn hhmm_of_stamp(at : Int) -> String {
  let in_day = ((at % 86400) + 86400) % 86400
  let hour = in_day / 3600
  let minute = (in_day % 3600) / 60
  let hh = if hour < 10 { "0\{hour}" } else { "\{hour}" }
  let mm = if minute < 10 { "0\{minute}" } else { "\{minute}" }
  "\{hh}:\{mm}"
}

///|
/// 相对时间分桶:(i18n 键, 数量)。just_now 桶不带数量。
/// 刷新由 AI 模式的 1s ClockUpdated 订阅承担(不需要单独的 30s 计时)。
pub fn relative_time_bucket(now : Int, at : Int) -> (String, Int) {
  let diff = (now - at).max(0)
  if diff < 60 {
    ("app.ai.time.just_now", 0)
  } else if diff < 3600 {
    ("app.ai.time.minutes", diff / 60)
  } else if diff < 86400 {
    ("app.ai.time.hours", diff / 3600)
  } else {
    ("app.ai.time.days", diff / 86400)
  }
}
