pub enum NodeKind {
      VIEW; TEXT; BUTTON; INPUT
} derive(Show, Eq)

pub fn NodeKind::ordinal(self : NodeKind) -> Int {
      match self {
            VIEW => 0
            TEXT => 1
            BUTTON => 2
            INPUT => 3
      }
}

pub fn NodeKind::from(self : Int) -> NodeKind {
      match self {
            0 => VIEW
            1 => TEXT
            2 => BUTTON
            3 => INPUT
            _ => panic()
      }
}

pub struct Color {
      r : Byte; g : Byte; b : Byte; a : Byte
} derive(Show, Eq)

pub struct Props {
      width : Float?; height : Float?; padding : Float?; background_color : Color?; text : String?; value : String?; on_click : UInt?; on_input : UInt?
} derive(Show, Eq)

pub struct FlatNode {
      id : UInt; parent_id : UInt?; kind : NodeKind; props : Props
} derive(Show, Eq)

pub struct UiTree {
      nodes : Array[FlatNode]
} derive(Show, Eq)