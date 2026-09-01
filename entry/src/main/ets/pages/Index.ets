import { HmFormTheme } from '@hmkit/form';
import { AsyncFormDemo } from './demos/AsyncFormDemo';
import { ConditionalFormDemo } from './demos/ConditionalFormDemo';
import { CoreFormDemo } from './demos/CoreFormDemo';
import { NestedFormDemo } from './demos/NestedFormDemo';
import { FormArrayDemo } from './demos/FormArrayDemo';
import { StructuredFormDemo } from './demos/StructuredFormDemo';

@Entry
@ComponentV2
struct Index {
  @Local scene: number = 0;
  @Local dark: boolean = false;
  @Local theme: HmFormTheme = HmFormTheme.light();

  private switchTheme(): void {
    this.dark = !this.dark;
    this.theme = this.dark ? HmFormTheme.dark() : HmFormTheme.light();
  }

  @Builder
  private sceneButton(label: string, scene: number): void {
    Button(label)
      .id(`hmkit_scene_${scene}`)
      .type(ButtonType.Normal)
      .fontColor(this.scene === scene ? '#FFFFFF' : this.theme.textColor)
      .backgroundColor(this.scene === scene ? this.theme.primaryColor : this.theme.surfaceColor)
      .borderWidth(1)
      .borderColor(this.scene === scene ? this.theme.primaryColor : this.theme.borderColor)
      .constraintSize({ minHeight: this.theme.controlMinHeight })
      .onClick((): void => { this.scene = scene; })
  }

  build(): void {
    Scroll() {
      Column({ space: 20 }) {
        Row() {
          Column({ space: 4 }) {
            Text('@hmkit/form 0.1 MVP')
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme.textColor)
            Text('可访问、可主题化的 ArkUI 表单')
              .fontSize(13)
              .fontColor(this.theme.secondaryTextColor)
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
          Button(this.dark ? '浅色' : '深色')
            .id('hmkit_theme_toggle')
            .type(ButtonType.Normal)
            .constraintSize({ minHeight: this.theme.controlMinHeight })
            .accessibilityText(this.dark ? '切换到浅色主题' : '切换到深色主题')
            .onClick((): void => { this.switchTheme(); })
        }
        .width('100%')

        Column({ space: 8 }) {
          Row({ space: 8 }) {
            this.sceneButton('核心', 0)
            this.sceneButton('条件', 1)
            this.sceneButton('异步', 2)
          }
          .width('100%')
          Row({ space: 8 }) {
            this.sceneButton('嵌套', 3)
            this.sceneButton('数组', 4)
            this.sceneButton('步骤', 5)
          }
          .width('100%')
        }
        .width('100%')

        if (this.scene === 0) {
          CoreFormDemo({ theme: this.theme })
        } else if (this.scene === 1) {
          ConditionalFormDemo({ theme: this.theme })
        } else if (this.scene === 2) {
          AsyncFormDemo({ theme: this.theme })
        } else if (this.scene === 3) {
          NestedFormDemo({ theme: this.theme })
        } else if (this.scene === 4) {
          FormArrayDemo({ theme: this.theme })
        } else {
          StructuredFormDemo({ theme: this.theme })
        }
      }
      .width('100%')
      .padding(20)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.dark ? '#111214' : '#F5F6F8')
  }
}
