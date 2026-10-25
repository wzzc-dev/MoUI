// The VM's opcode alphabet.  Numbers, arities and operand positions are the
// original engine's (re-read from `decompiled/d.java`, see
// /Users/zc/Downloads/xjqq-re/tools/marpg/ops.py); only the content the scripts
// address is self-authored, which is what makes this a reproduction of the
// reversed semantics rather than a resemblance.

///|
/// Opcodes the slice's scripts actually emit.  `ARITY` in the generated content
/// carries the engine's full 75-entry table; this enum is the dispatch surface.
pub enum Opcode {
  If
  Endif
  Kill
  Var
  Scene
  Show
  Dialog
  WaitSprite
  Anim
  Walk
  TimerWait
  Else
  Choice
  Battle
  GameOver
  Title
  StatToVar
  Give
  Restore
  Unlock
  Message
  Money
  KeyWait
  Join
} derive(Eq, @debug.Debug)

///|
pub fn Opcode::code(self : Opcode) -> Int32 {
  match self {
    If => 0
    Endif => 1
    Kill => 2
    Var => 3
    Scene => 4
    Show => 6
    Dialog => 7
    WaitSprite => 9
    Anim => 12
    Walk => 13
    TimerWait => 14
    Else => 15
    Choice => 16
    Battle => 21
    GameOver => 23
    Title => 24
    StatToVar => 38
    Give => 40
    Restore => 46
    Unlock => 65
    Message => 66
    Money => 68
    KeyWait => 71
    Join => 72
  }
}

///|
/// `None` for anything the slice does not implement, so a bundle that suddenly
/// uses a new opcode is a visible gap instead of a silently ignored instruction.
pub fn opcode_of_code(code : Int32) -> Opcode? {
  match code {
    0 => Some(If)
    1 => Some(Endif)
    2 => Some(Kill)
    3 => Some(Var)
    4 => Some(Scene)
    6 => Some(Show)
    7 => Some(Dialog)
    9 => Some(WaitSprite)
    12 => Some(Anim)
    13 => Some(Walk)
    14 => Some(TimerWait)
    15 => Some(Else)
    16 => Some(Choice)
    21 => Some(Battle)
    23 => Some(GameOver)
    24 => Some(Title)
    38 => Some(StatToVar)
    40 => Some(Give)
    46 => Some(Restore)
    65 => Some(Unlock)
    66 => Some(Message)
    68 => Some(Money)
    71 => Some(KeyWait)
    72 => Some(Join)
    _ => None
  }
}

///|
/// Operand value kinds, `c(int,int,int)` @ d.java:3027.  Kind 2 is the RNG
/// `abs(nextInt()) % (hi - lo) + lo` @ d.java:4957, not a sprite stat read.
pub let kind_const : Int32 = 0

///|
pub let kind_var : Int32 = 1

///|
pub let kind_rand : Int32 = 2

///|
/// Comparators and in-place variable operators, `a(int,int,int)` @ d.java:4724.
pub let cmp_eq : Int32 = 0

///|
pub let cmp_ne : Int32 = 1

///|
pub let cmp_lt : Int32 = 2

///|
pub let cmp_gt : Int32 = 3

///|
pub let cmp_le : Int32 = 4

///|
pub let cmp_ge : Int32 = 5

///|
pub let var_set : Int32 = 6

///|
pub let var_add : Int32 = 7

///|
pub let var_sub : Int32 = 8

///|
pub let var_mul : Int32 = 9

///|
pub let var_div : Int32 = 10

///|
pub let var_mod : Int32 = 11

///|
/// Thread wait states, `n(int)` @ d.java:3045.
pub let ws_trigger : Int32 = -1

///|
pub let ws_run : Int32 = 0

///|
pub let ws_timer : Int32 = 1

///|
pub let ws_sprite_field : Int32 = 2

///|
pub let ws_dialog : Int32 = 3

///|
pub let ws_key : Int32 = 4

///|
pub let ws_parked : Int32 = 6

///|
pub let ws_watch : Int32 = 7

///|
/// Thread classes -- the bundle's `aX` column.  `l(int n)` @ d.java:2975 only
/// switches on 0/1/2 and returns false for anything else, so class 4 is never
/// ready by itself; the title driver starts it by hand (@ d.java:12286).
pub let thread_plain : Int32 = 0

///|
pub let thread_auto_talk : Int32 = 1

///|
pub let thread_proximity : Int32 = 2

///|
pub let thread_boot : Int32 = 4

///|
/// `o(int n)` @ d.java:3138 maps these group numbers onto J2ME game-key masks
/// (1 -> 2080, 2 -> 262144, 3 -> 524288, 4 -> 258, 5 -> 4112, 6 -> 16388,
/// 7 -> 1032).  op71 waits on a group, which is why it is not a proximity trigger.
pub let key_confirm : Int32 = 1

///|
pub let key_back : Int32 = 2

///|
pub let key_anywhere : Int32 = 3

///|
/// The per-cell 2-bit map flag is a `drawRegion` transform code, not collision:
/// J2ME `Sprite.FALSE`/`TRANSFORM_ROT_90`/`ROT_180`/`ROT_270`.
pub let trans_none : Int32 = 0

///|
pub let trans_rot90_cw : Int32 = 1

///|
pub let trans_rot180 : Int32 = 2

///|
pub let trans_rot90_ccw : Int32 = 3

///|
/// Leading operand indexes that address a string-pool slot, verified from the
/// case bodies (op7 db3 body + db5 name, op16 prompt + 5 options, op24 db0,
/// op66 db0).  op10 takes pixels, not text -- the old note claiming otherwise is
/// falsified at d.java:2226-2235.
pub fn opcode_string_slots(op : Opcode) -> Array[Int32] {
  match op {
    Dialog => [3, 5]
    Choice => [1, 3, 4, 5, 6, 7]
    Title => [0]
    Message => [0]
    _ => []
  }
}
