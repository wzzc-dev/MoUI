import { MoUIRoot } from '../moui/MoUIRoot';

@Entry
@Component
struct Index {
  build() {
    Stack() {
      MoUIRoot()
    }
    .width('100%')
    .height('100%')
  }
}
