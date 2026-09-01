import { FormArrayController, FormArrayEntry, HmFormArrayItemContext } from '../core/FormArray';

/** Controlled ArkUI renderer for dynamic arrays with stable item keys. */
@ComponentV2
export struct HmFormArrayView {
  @Require @Param values: Object[];
  @Event $values: (values: Object[]) => void = (_values: Object[]): void => {};
  @Require @Param controller: FormArrayController;
  @Param space: number = 12;
  @Param emptyText: string = '暂无条目';
  @BuilderParam item: (context: HmFormArrayItemContext) => void = this.defaultItem;

  @Builder
  private defaultItem(context: HmFormArrayItemContext): void {
    Text(`第 ${context.index + 1} 项`)
      .fontSize('14fp')
  }

  aboutToAppear(): void {
    this.controller.syncValues(this.values);
  }

  @Monitor('values')
  private syncControlledValues(_monitor: IMonitor): void {
    this.controller.syncValues(this.values);
  }

  private emitValues(): void {
    this.$values(this.controller.getValues());
  }

  private itemContext(entry: FormArrayEntry, index: number): HmFormArrayItemContext {
    return new HmFormArrayItemContext(
      entry,
      (value: Object): void => {
        const current = this.indexOfKey(entry.key);
        if (current >= 0 && this.controller.update(current, value)) this.emitValues();
      },
      (): void => {
        if (this.controller.removeByKey(entry.key)) this.emitValues();
      },
      (): void => {
        const current = this.indexOfKey(entry.key);
        if (current > 0 && this.controller.move(current, current - 1)) this.emitValues();
      },
      (): void => {
        const current = this.indexOfKey(entry.key);
        if (current >= 0 && current < this.controller.entries.length - 1 &&
          this.controller.move(current, current + 1)) this.emitValues();
      }
    );
  }

  private indexOfKey(key: string): number {
    for (let index = 0; index < this.controller.entries.length; index++) {
      if (this.controller.entries[index].key === key) return index;
    }
    return -1;
  }

  build(): void {
    Column({ space: this.space }) {
      if (this.controller.entries.length === 0) {
        Text(this.emptyText)
          .id('hmkit_form_array_empty')
          .fontSize('14fp')
          .accessibilityText(this.emptyText)
      } else {
        ForEach(this.controller.entries, (entry: FormArrayEntry, index: number): void => {
          this.item(this.itemContext(entry, index))
        }, (entry: FormArrayEntry): string => entry.key)
      }
    }
    .width('100%')
  }
}
