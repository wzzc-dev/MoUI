///|
priv enum ViewNode[Msg] {
  EmptyNode
  TextNode(TextViewSpec)
  ButtonNode(ButtonViewSpec, Msg?)
  TextFieldNode(TextFieldViewSpec, Msg?)
  ControlledTextFieldNode(ControlledTextFieldViewData[Msg])
  RichTextEditorNode(
    RichTextEditorViewSpec,
    ((Int, TextRange?) -> Msg)?,
    ((Int) -> Msg)?
  )
  ControlledRichTextEditorNode(ControlledRichTextEditorViewData[Msg])
  ImageNode(ImageViewSpec)
  CheckboxNode(CheckboxViewSpec)
  ControlledCheckboxNode(ControlledCheckboxViewData[Msg])
  PickerNode(PickerViewSpec)
  ControlledPickerNode(ControlledPickerViewData[Msg])
  DatePickerNode(DatePickerViewSpec)
  ControlledDatePickerNode(ControlledDatePickerViewData[Msg])
  SearchBarNode(SearchBarViewSpec, Msg?, Msg?)
  ControlledSearchBarNode(ControlledSearchBarViewData[Msg])
  WebViewNode(WebViewSpec, ((WebViewEvent) -> Msg)?)
  SheetNode(SheetViewSpec, ViewNode[Msg], Msg?)
  FlexNode(FlexViewSpec, Array[ViewNode[Msg]])
  PaddingNode(PaddingViewSpec, ViewNode[Msg])
  ContainerNode(ContainerViewSpec, ViewNode[Msg]?)
  SpacerNode(SpacerViewSpec)
  FrameNode(FrameViewSpec, ViewNode[Msg])
  StackNode(StackViewSpec, Array[ViewNode[Msg]])
  ScrollNode(ScrollViewSpec, ViewNode[Msg], ScrollState?, ((Point) -> Msg)?)
  GridNode(GridViewSpec, Array[ViewNode[Msg]])
  ListNode(ListViewSpec, Array[ViewNode[Msg]])
  ModifiedNode(ViewModifierNode[Msg], ViewNode[Msg])
  CustomNode(CustomViewSpec)
  CustomLayoutNode(CustomLayoutSpec, Array[ViewNode[Msg]])
  ComponentNode((BuildContext) -> View[Msg])
}
