import { FormArrayController, HmFormArrayItemContext, HmFormArrayView, HmFormTheme,
  setFormValue } from '@hmkit/form';

function contact(id: string, name: string, phone: string): Record<string, Object> {
  return { 'id': id, 'name': name, 'phone': phone };
}

function contactIdentity(value: Object, _index: number): string {
  return (value as Record<string, Object>)['id'] as string;
}

function contactValue(context: HmFormArrayItemContext, name: string): string {
  const value = (context.value as Record<string, Object>)[name];
  return value === undefined ? '' : `${value}`;
}

@Builder
function ContactArrayItem(context: HmFormArrayItemContext): void {
  Column({ space: 8 }) {
    Row() {
      Text(`联系人 ${context.index + 1}`)
        .fontSize('14fp')
        .fontWeight(FontWeight.Medium)
      Blank()
      Button('上移')
        .id(`hmkit_array_${contactValue(context, 'id')}_up`)
        .type(ButtonType.Normal)
        .enabled(context.canMoveUp)
        .onClick((): void => { context.moveUp(); })
      Button('下移')
        .id(`hmkit_array_${contactValue(context, 'id')}_down`)
        .type(ButtonType.Normal)
        .enabled(context.canMoveDown)
        .onClick((): void => { context.moveDown(); })
      Button('删除')
        .id(`hmkit_array_${contactValue(context, 'id')}_remove`)
        .type(ButtonType.Normal)
        .enabled(context.canRemove)
        .onClick((): void => { context.remove(); })
    }
    .width('100%')

    TextInput({ text: contactValue(context, 'name'), placeholder: '姓名' })
      .id(`hmkit_array_${contactValue(context, 'id')}_name`)
      .width('100%')
      .onChange((text: string): void => {
        context.change(setFormValue(context.value as Record<string, Object>, 'name', text));
      })
    TextInput({ text: contactValue(context, 'phone'), placeholder: '手机号' })
      .id(`hmkit_array_${contactValue(context, 'id')}_phone`)
      .width('100%')
      .type(InputType.PhoneNumber)
      .onChange((text: string): void => {
        context.change(setFormValue(context.value as Record<string, Object>, 'phone', text));
      })
  }
  .id(`hmkit_array_item_${contactValue(context, 'id')}`)
  .width('100%')
  .padding(12)
  .backgroundColor('#FFFFFFFF')
  .borderRadius(10)
  .borderWidth(1)
  .borderColor('#FFD8DCE5')
}

@ComponentV2
export struct FormArrayDemo {
  @Require @Param theme: HmFormTheme;
  @Local values: Object[] = [
    contact('contact-a', '张三', '13800000001'),
    contact('contact-b', '李四', '13800000002')
  ];
  @Local status: string = '2 个联系人';
  private nextId: number = 3;
  private controller: FormArrayController = new FormArrayController(this.values, {
    'minItems': 1,
    'maxItems': 4,
    'identity': contactIdentity
  });

  private commit(): void {
    this.values = this.controller.getValues();
    this.status = `${this.values.length} 个联系人`;
  }

  private append(): void {
    if (this.controller.append(contact(`contact-${this.nextId}`, '', ''))) {
      this.nextId++;
      this.commit();
    }
  }

  aboutToDisappear(): void {
    this.controller.dispose();
  }

  build(): void {
    Column({ space: 16 }) {
      Text('动态联系人')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.textColor)
      Text('受控数组 · 增删排序 · 业务 identity 稳定 key')
        .fontSize('13fp')
        .fontColor(this.theme.secondaryTextColor)
      Row({ space: 8 }) {
        Button('添加联系人')
          .id('hmkit_array_add')
          .enabled(this.controller.canAppend())
          .onClick((): void => { this.append(); })
        Button('服务端重排')
          .id('hmkit_array_refill')
          .onClick((): void => {
            this.values = [
              contact('contact-b', '李四（已回填）', '13800000002'),
              contact('contact-a', '张三', '13800000001')
            ];
            this.status = '服务端已重排';
          })
      }
      .width('100%')
      HmFormArrayView({
        values: this.values!!,
        controller: this.controller,
        item: ContactArrayItem,
        emptyText: '请添加联系人'
      })
      Text(this.status)
        .id('hmkit_array_status')
        .fontSize('12fp')
        .fontColor(this.theme.secondaryTextColor)
      Text(`数组值：${JSON.stringify(this.values)}`)
        .id('hmkit_array_values')
        .fontSize('12fp')
        .fontColor(this.theme.secondaryTextColor)
    }
    .width('100%')
  }
}
