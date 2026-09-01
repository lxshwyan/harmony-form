import { describe, it, expect } from '@ohos/hypium';
import { FormTrigger, v } from '@hmkit/validator';
import { FormController } from '../main/ets/core/FormController';
import { FormFieldSlot, FormFieldSpec, FormFieldType, FormSelectOption,
  FormTextInputType } from '../main/ets/core/FormField';
import { HmFormRendererRegistry } from '../main/ets/core/FormRenderer';
import { HmFormLayout } from '../main/ets/core/FormLayout';
import { inferFormFields } from '../main/ets/core/FormFieldInference';
import { getFormValue, setFormValue } from '../main/ets/core/FormPath';
import { FormArrayController } from '../main/ets/core/FormArray';
import { FormSectionSpec, FormStepSpec, FormStructureController } from '../main/ets/core/FormStructure';
import { buildFormErrorSummaryItems, HmFormErrorSummaryContext,
  HmFormErrorSummaryItem } from '../main/ets/core/FormErrors';
import { HmFormTheme } from '../main/ets/theme/HmFormTheme';

function createFields(): FormFieldSpec[] {
  return [
    new FormFieldSpec('name', FormFieldType.TEXT, '姓名', v.string().required('请输入姓名')),
    new FormFieldSpec('age', FormFieldType.NUMBER, '年龄', v.number().min(18, '年龄不能小于 18 岁'))
  ];
}

function expectConfigurationError(action: () => void, message: string): void {
  let thrown = false;
  try {
    action();
  } catch (error) {
    thrown = `${error}`.includes(message);
  }
  expect(thrown).assertTrue();
}

function arrayRecord(id: string, name: string): Record<string, Object> {
  return { 'id': id, 'name': name };
}

export default function formControllerTest(): void {
  describe('FormController state synchronization', (): void => {
    it('validates section and step ownership without hiding fields', 0, (): void => {
      const sections = [
        new FormSectionSpec('basic', '基础资料', ['name'], { 'collapsible': true }),
        new FormSectionSpec('detail', '详细资料', ['age'])
      ];
      const structure = new FormStructureController(sections, [
        new FormStepSpec('identity', '身份', ['basic']),
        new FormStepSpec('profile', '资料', ['detail'])
      ]);
      structure.assertFields(createFields());
      expectConfigurationError((): void => {
        new FormStructureController(sections, [
          new FormStepSpec('only', '单步', ['basic'])
        ]);
      }, 'Form section is not assigned to a step: detail');
      expectConfigurationError((): void => {
        new FormStructureController([
          new FormSectionSpec('partial', '缺字段', ['name'])
        ]).assertFields(createFields());
      }, 'Form field is not assigned to a section: age');
    });

    it('navigates steps and reveals collapsed error sections', 0, (): void => {
      const structure = new FormStructureController([
        new FormSectionSpec('basic', '基础资料', ['name'], {
          'collapsible': true,
          'defaultExpanded': false
        }),
        new FormSectionSpec('detail', '详细资料', ['age'])
      ], [
        new FormStepSpec('first', '第一步', ['basic']),
        new FormStepSpec('second', '第二步', ['detail'])
      ]);
      expect(structure.isExpanded('basic')).assertFalse();
      expect(structure.currentStepId()).assertEqual('first');
      expect(structure.beginStepValidation()).assertTrue();
      expect(structure.next()).assertFalse();
      structure.endStepValidation();
      expect(structure.revealField('name')).assertTrue();
      expect(structure.isExpanded('basic')).assertTrue();
      expect(structure.next()).assertTrue();
      expect(structure.currentStepId()).assertEqual('second');
      expect(structure.revealField('name')).assertTrue();
      expect(structure.currentStepId()).assertEqual('first');
      structure.reset();
      expect(structure.isExpanded('basic')).assertFalse();
      structure.dispose();
      expect(structure.next()).assertFalse();
    });

    it('builds error summaries in field order with section and step locations', 0, (): void => {
      const fields = createFields();
      const structure = new FormStructureController([
        new FormSectionSpec('basic', '基础资料', ['name']),
        new FormSectionSpec('detail', '详细资料', ['age'])
      ], [
        new FormStepSpec('identity', '身份步骤', ['basic']),
        new FormStepSpec('profile', '资料步骤', ['detail'])
      ]);
      const items = buildFormErrorSummaryItems(fields, {
        'age': '年龄错误',
        'unknown': '未知错误',
        'name': '姓名错误'
      }, structure);
      expect(items.length).assertEqual(2);
      expect(items[0].name).assertEqual('name');
      expect(items[0].location()).assertEqual('身份步骤 / 基础资料');
      expect(items[1].name).assertEqual('age');
      expect(items[1].sectionId).assertEqual('detail');
      expect(items[1].stepId).assertEqual('profile');
      expect(structure.sectionForField('age')?.title).assertEqual('详细资料');
      expect(structure.stepForField('age')?.title).assertEqual('资料步骤');
    });

    it('builds unstructured summaries without location metadata', 0, (): void => {
      const items = buildFormErrorSummaryItems(createFields(), { 'age': '年龄错误' });
      expect(items.length).assertEqual(1);
      expect(items[0].label).assertEqual('年龄');
      expect(items[0].message).assertEqual('年龄错误');
      expect(items[0].location()).assertEqual('');
    });

    it('defensively snapshots custom error summary context and keeps its action', 0, (): void => {
      const source: HmFormErrorSummaryItem[] = [
        new HmFormErrorSummaryItem('name', '姓名', '请输入姓名')
      ];
      let activated = '';
      const context = new HmFormErrorSummaryContext(source, '请检查以下 1 项', '选择错误可定位',
        HmFormTheme.light(), (name: string): void => {
          activated = name;
        });
      source.push(new HmFormErrorSummaryItem('age', '年龄', '年龄错误'));
      expect(context.items.length).assertEqual(1);
      context.activate(context.items[0].name);
      expect(activated).assertEqual('name');
    });

    it('validates only the current step field subset and preserves other errors', 0, async (): Promise<void> => {
      const controller = new FormController(createFields(), { 'age': 16 }, { 'debounceMs': 0 });
      expect((await controller.validateFields(['name']))['name']).assertEqual('请输入姓名');
      expect(controller.errors['age']).assertUndefined();
      await controller.validateFields(['age']);
      expect(controller.errors['name']).assertEqual('请输入姓名');
      expect(controller.errors['age']).assertEqual('年龄不能小于 18 岁');
      await controller.onChange('name', '鸿蒙');
      expect(controller.errors['name']).assertUndefined();
      expect(controller.errors['age']).assertEqual('年龄不能小于 18 岁');
    });

    it('keeps generated FormArray keys stable across insert remove and move', 0, (): void => {
      const controller = new FormArrayController(['A', 'B']);
      const firstKey = controller.entries[0].key;
      const secondKey = controller.entries[1].key;
      expect(controller.insert(1, 'X')).assertTrue();
      expect(controller.entries[0].key).assertEqual(firstKey);
      expect(controller.entries[2].key).assertEqual(secondKey);
      expect(controller.move(2, 0)).assertTrue();
      expect(controller.entries[0].key).assertEqual(secondKey);
      expect(controller.remove(1)).assertTrue();
      expect(controller.entries[0].key).assertEqual(secondKey);
      expect(controller.getValues()[0] as string).assertEqual('B');
    });

    it('preserves identity keys across controlled reorder and edits', 0, (): void => {
      const identity = (value: Object, _index: number): string =>
        (value as Record<string, Object>)['id'] as string;
      const initial: Object[] = [arrayRecord('a', '甲'), arrayRecord('b', '乙')];
      const controller = new FormArrayController(initial, { 'identity': identity });
      const aKey = controller.entries[0].key;
      const bKey = controller.entries[1].key;
      const reordered: Object[] = [arrayRecord('b', '乙（更新）'), arrayRecord('a', '甲')];
      expect(controller.syncValues(reordered)).assertTrue();
      expect(controller.entries[0].key).assertEqual(bKey);
      expect(controller.entries[1].key).assertEqual(aKey);
      expect((controller.getValues()[0] as Record<string, Object>)['name'] as string).assertEqual('乙（更新）');
    });

    it('returns defensive FormArray snapshots and preserves an updated item key', 0, (): void => {
      const initial: Record<string, Object> = { 'name': '原值' };
      const controller = new FormArrayController([initial]);
      const key = controller.entries[0].key;
      initial['name'] = '外部修改';
      expect((controller.getValues()[0] as Record<string, Object>)['name'] as string).assertEqual('原值');
      const updated: Record<string, Object> = { 'name': '新值' };
      expect(controller.update(0, updated)).assertTrue();
      expect(controller.entries[0].key).assertEqual(key);
      const snapshot = controller.getValues()[0] as Record<string, Object>;
      snapshot['name'] = '快照修改';
      expect((controller.getValues()[0] as Record<string, Object>)['name'] as string).assertEqual('新值');
    });

    it('enforces FormArray limits and identity uniqueness', 0, (): void => {
      const identity = (value: Object, _index: number): string => value as string;
      const controller = new FormArrayController(['a'], { 'minItems': 1, 'maxItems': 2, 'identity': identity });
      expect(controller.remove(0)).assertFalse();
      expect(controller.append('b')).assertTrue();
      expect(controller.append('c')).assertFalse();
      expectConfigurationError((): void => {
        controller.update(1, 'a');
      }, 'Duplicate FormArray item identity: a');
      expectConfigurationError((): void => {
        new FormArrayController(['same', 'same'], { 'identity': identity });
      }, 'Duplicate FormArray item identity: same');
    });

    it('isolates FormArray after dispose and reactivates it on reset', 0, (): void => {
      const controller = new FormArrayController(['a']);
      controller.dispose();
      expect(controller.append('b')).assertFalse();
      expect(controller.update(0, 'changed')).assertFalse();
      expect(controller.getValues().length).assertEqual(1);
      controller.reset(['reset']);
      expect(controller.append('next')).assertTrue();
      expect(controller.getValues().length).assertEqual(2);
    });

    it('validates a FormArray value through the existing validator field boundary', 0,
      async (): Promise<void> => {
        const field = new FormFieldSpec('contacts', FormFieldType.custom('form-array'), '联系人',
          v.array(v.object({ 'name': v.string().required('请输入联系人姓名') })).min(1, '至少一个联系人'));
        const controller = new FormController([field], { 'contacts': [] }, { 'debounceMs': 0 });
        await controller.onChange('contacts', []);
        expect(controller.errors['contacts']).assertEqual('至少一个联系人');
        const invalid: Object[] = [{ 'name': '' } as Record<string, Object>];
        await controller.onChange('contacts', invalid);
        expect(controller.errors['contacts']).assertEqual('请输入联系人姓名');
        const valid: Object[] = [{ 'name': '张三' } as Record<string, Object>];
        await controller.onChange('contacts', valid);
        expect(controller.errors['contacts']).assertUndefined();
      });
    it('copies initial values and returned snapshots', 0, (): void => {
      const initial: Record<string, Object> = { 'name': '鸿蒙', 'age': 20 };
      const controller = new FormController(createFields(), initial, { 'debounceMs': 0 });
      initial['name'] = '外部修改';
      expect(controller.getValue('name') as string).assertEqual('鸿蒙');

      const snapshot = controller.getValues();
      snapshot['name'] = '快照修改';
      expect(controller.getValue('name') as string).assertEqual('鸿蒙');
    });

    it('rejects duplicate field names before building validator state', 0, (): void => {
      expectConfigurationError((): void => {
        new FormController([
          new FormFieldSpec('name', FormFieldType.TEXT, '姓名', v.string()),
          new FormFieldSpec('name', FormFieldType.TEXT, '别名', v.string())
        ]);
      }, 'Duplicate form field name: name');
    });

    it('rejects empty names and unsupported field types', 0, (): void => {
      expectConfigurationError((): void => {
        new FormFieldSpec(' ', FormFieldType.TEXT, '空字段', v.string());
      }, 'name must not be empty');
      expectConfigurationError((): void => {
        new FormFieldSpec('unknown', 'custom', '未知字段', v.string());
      }, 'Unsupported form field type: custom');
    });

    it('namespaces custom types and rejects invalid custom names', 0, (): void => {
      expect(FormFieldType.custom('segmented')).assertEqual('custom:segmented');
      expect(FormFieldType.isCustom('custom:segmented')).assertTrue();
      expect(FormFieldType.isCustom(FormFieldType.TEXT)).assertFalse();
      expectConfigurationError((): void => {
        FormFieldType.custom(' ');
      }, 'Invalid custom form field type');
      expectConfigurationError((): void => {
        FormFieldType.custom('bad/type');
      }, 'Invalid custom form field type');
    });

    it('requires a registered renderer while preserving controller validation', 0, async (): Promise<void> => {
      const type = FormFieldType.custom('segmented');
      const field = new FormFieldSpec('level', type, '服务等级', v.string().required('请选择服务等级'));
      const registry = new HmFormRendererRegistry();
      expectConfigurationError((): void => {
        registry.assertFields([field]);
      }, 'Missing custom form renderer: custom:segmented');

      const controller = new FormController([field], {}, { 'debounceMs': 0 });
      await controller.onChange('level', 'priority');
      expect(controller.getValue('level') as string).assertEqual('priority');
      expect(controller.errors['level']).assertUndefined();
    });

    it('rejects empty or ambiguous select and radio options', 0, (): void => {
      expectConfigurationError((): void => {
        new FormFieldSpec('city', FormFieldType.SELECT, '城市', v.string());
      }, 'options must not be empty: city');
      expectConfigurationError((): void => {
        new FormFieldSpec('contact', FormFieldType.RADIO, '联系方式', v.string(), '', undefined, {
          'options': [new FormSelectOption('手机', 'mobile'), new FormSelectOption('电话', 'mobile')]
        });
      }, "Duplicate form option value 'mobile'");
    });

    it('accepts async choice options and rejects loaders on non-choice fields', 0, (): void => {
      const field = new FormFieldSpec('city', FormFieldType.SELECT, '城市', v.string(), '', undefined, {
        'optionsLoader': (): Promise<FormSelectOption[]> => new Promise<FormSelectOption[]>(
          (resolve: (options: FormSelectOption[]) => void): void => {
            resolve([new FormSelectOption('上海市', 'shanghai')]);
          })
      });
      expect(field.loadsOptions()).assertTrue();
      expect(field.options.length).assertEqual(0);
      expectConfigurationError((): void => {
        new FormFieldSpec('name', FormFieldType.TEXT, '姓名', v.string(), '', undefined, {
          'optionsLoader': field.optionsLoader
        });
      }, 'Async options are only supported for choice fields: name');
    });

    it('rejects invalid maxLength and date ranges', 0, (): void => {
      expectConfigurationError((): void => {
        new FormFieldSpec('bio', FormFieldType.TEXTAREA, '简介', v.string(), '', undefined, { 'maxLength': 0 });
      }, 'maxLength must be positive: bio');
      expectConfigurationError((): void => {
        new FormFieldSpec('date', FormFieldType.DATE, '日期', v.date(), '', undefined, {
          'startDate': new Date(2030, 0, 1), 'endDate': new Date(2029, 11, 31)
        });
      }, 'startDate must not be after endDate: date');
    });

    it('copies field slot declarations and exposes exact matching', 0, (): void => {
      const slots = [FormFieldSlot.PREFIX, FormFieldSlot.ERROR];
      const field = new FormFieldSpec('name', FormFieldType.TEXT, '姓名', v.string(), '', undefined, { 'slots': slots });
      slots.push(FormFieldSlot.SUFFIX);
      expect(field.slots.length).assertEqual(2);
      expect(field.usesSlot(FormFieldSlot.PREFIX)).assertTrue();
      expect(field.usesSlot(FormFieldSlot.SUFFIX)).assertFalse();
    });

    it('rejects unsupported and duplicate field slots', 0, (): void => {
      expectConfigurationError((): void => {
        new FormFieldSpec('name', FormFieldType.TEXT, '姓名', v.string(), '', undefined,
          { 'slots': ['unknown'] });
      }, "Unsupported form field slot 'unknown'");
      expectConfigurationError((): void => {
        new FormFieldSpec('name', FormFieldType.TEXT, '姓名', v.string(), '', undefined,
          { 'slots': [FormFieldSlot.LABEL, FormFieldSlot.LABEL] });
      }, "Duplicate form field slot 'label'");
    });

    it('uses a defensive 12-column field span contract', 0, (): void => {
      const full = new FormFieldSpec('full', FormFieldType.TEXT, '全宽', v.string());
      const half = new FormFieldSpec('half', FormFieldType.TEXT, '半宽', v.string(), '', undefined, { 'span': 6 });
      expect(full.span).assertEqual(12);
      expect(half.span).assertEqual(6);
      expectConfigurationError((): void => {
        new FormFieldSpec('zero', FormFieldType.TEXT, '非法', v.string(), '', undefined, { 'span': 0 });
      }, 'span must be an integer from 1 to 12');
      expectConfigurationError((): void => {
        new FormFieldSpec('decimal', FormFieldType.TEXT, '非法', v.string(), '', undefined, { 'span': 6.5 });
      }, 'span must be an integer from 1 to 12');
    });

    it('keeps field subtrees only when explicitly requested', 0, (): void => {
      const normal = new FormFieldSpec('normal', FormFieldType.TEXT, '普通字段', v.string());
      const retained = new FormFieldSpec('retained', FormFieldType.TEXT, '保活字段', v.string(), '', undefined, {
        'keepAlive': true
      });
      expect(normal.keepAlive).assertFalse();
      expect(retained.keepAlive).assertTrue();
    });

    it('uses portable text keyboard options without changing the string model', 0, (): void => {
      const normal = new FormFieldSpec('name', FormFieldType.TEXT, '姓名', v.string());
      const phone = new FormFieldSpec('phone', FormFieldType.TEXT, '手机号', v.string(), '', undefined, {
        'inputType': FormTextInputType.PHONE
      });
      const age = new FormFieldSpec('age', FormFieldType.NUMBER, '年龄', v.number());
      expect(normal.inputType).assertEqual(FormTextInputType.NORMAL);
      expect(phone.inputType).assertEqual(FormTextInputType.PHONE);
      expect(age.inputType).assertEqual(FormTextInputType.NUMBER);
      expectConfigurationError((): void => {
        new FormFieldSpec('bad', FormFieldType.TEXT, '非法', v.string(), '', undefined, { 'inputType': 'tel' });
      }, "Unsupported form text input type 'tel'");
      expectConfigurationError((): void => {
        new FormFieldSpec('city', FormFieldType.SELECT, '城市', v.string(), '', undefined, {
          'options': [new FormSelectOption('上海', 'sh')], 'inputType': FormTextInputType.PHONE
        });
      }, 'Text input type is only supported for text/number fields');
    });

    it('validates immutable responsive layout options', 0, (): void => {
      const defaults = HmFormLayout.responsive();
      expect(defaults.breakpoint).assertEqual('600vp');
      expect(defaults.columnGap).assertEqual(16);
      expect(defaults.rowGap).assertEqual(16);
      const compact = new HmFormLayout({ 'breakpoint': '480vp', 'columnGap': 8, 'rowGap': 12 });
      expect(compact.breakpoint).assertEqual('480vp');
      expect(compact.columnGap).assertEqual(8);
      expectConfigurationError((): void => {
        new HmFormLayout({ 'breakpoint': '600px' });
      }, 'breakpoint must be a positive vp length');
      expectConfigurationError((): void => {
        new HmFormLayout({ 'rowGap': -1 });
      }, 'gaps must not be negative');
    });

    it('synchronizes change errors and clears them after correction', 0, async (): Promise<void> => {
      const controller = new FormController(createFields(), {}, { 'debounceMs': 0 });
      await controller.onChange('name', '');
      expect(controller.displayValue('name')).assertEqual('');
      expect(controller.errors['name']).assertEqual('请输入姓名');
      await controller.onBlur('name');
      expect(controller.errors['name']).assertEqual('请输入姓名');

      await controller.onChange('name', 'OpenHarmony');
      expect(controller.getValue('name') as string).assertEqual('OpenHarmony');
      expect(controller.errors['name']).assertUndefined();
    });

    it('synchronizes blur validation into the observable error map', 0, async (): Promise<void> => {
      const fields = [
        new FormFieldSpec('name', FormFieldType.TEXT, '姓名', v.string().required('请输入姓名'), '', {
          'triggers': [FormTrigger.BLUR]
        })
      ];
      const controller = new FormController(fields, { 'name': '' }, { 'debounceMs': 0 });
      await controller.onBlur('name');
      expect(controller.errors['name']).assertEqual('请输入姓名');
    });

    it('validates the whole form on submit and follows field order', 0, async (): Promise<void> => {
      const controller = new FormController(createFields(), { 'name': '', 'age': 16 }, { 'debounceMs': 0 });
      const errors = await controller.submit();
      expect(errors['name']).assertEqual('请输入姓名');
      expect(errors['age']).assertEqual('年龄不能小于 18 岁');
      expect(controller.firstErrorName() as string).assertEqual('name');
      expect(controller.submitting).assertFalse();
    });

    it('reset cancels pending validation and establishes a clean value set', 0, async (): Promise<void> => {
      const controller = new FormController(createFields(), {}, { 'debounceMs': 30 });
      const pending = controller.onChange('name', '');
      controller.reset({ 'name': '重置值', 'age': 20 });
      await pending;
      expect(controller.getValue('name') as string).assertEqual('重置值');
      expect(Object.keys(controller.errors).length).assertEqual(0);
      expect(controller.submitting).assertFalse();
    });

    it('dispose ignores late and subsequent UI events', 0, async (): Promise<void> => {
      const controller = new FormController(createFields(), { 'name': '原值' }, { 'debounceMs': 30 });
      const pending = controller.onChange('name', '');
      controller.dispose();
      await pending;
      await controller.onChange('name', '退出后的事件');
      await controller.onBlur('name');
      expect(controller.getValue('name') as string).assertEqual('');
      expect(Object.keys(controller.errors).length).assertEqual(0);
      expect(Object.keys(await controller.submit()).length).assertEqual(0);
    });

    it('reset reactivates a disposed controller for deliberate reuse', 0, async (): Promise<void> => {
      const controller = new FormController(createFields(), { 'name': '旧值' }, { 'debounceMs': 0 });
      controller.dispose();
      controller.reset({ 'name': '新值' });
      await controller.onChange('name', '可复用');
      expect(controller.getValue('name') as string).assertEqual('可复用');
      expect(Object.keys(controller.errors).length).assertEqual(0);
    });

    it('syncs external values as a clean controlled replacement', 0, async (): Promise<void> => {
      const controller = new FormController(createFields(), { 'name': '旧值', 'age': 16 }, { 'debounceMs': 0 });
      await controller.onChange('name', '');
      await controller.onBlur('name');
      expect(controller.getFieldState('name').dirty).assertTrue();
      expect(controller.getFieldState('name').touched).assertTrue();
      expect(controller.errors['name']).assertEqual('请输入姓名');

      const changed = controller.syncValues({ 'name': '外部回填', 'age': 20 });
      expect(changed).assertTrue();
      expect(controller.getValue('name') as string).assertEqual('外部回填');
      expect(controller.getValue('age') as number).assertEqual(20);
      expect(controller.getFieldState('name').dirty).assertFalse();
      expect(controller.getFieldState('name').touched).assertFalse();
      expect(Object.keys(controller.errors).length).assertEqual(0);
    });

    it('preserves interaction state for the parent echo of an internal change', 0, async (): Promise<void> => {
      const controller = new FormController(createFields(), {}, { 'debounceMs': 0 });
      await controller.onChange('name', '');
      const changed = controller.syncValues(controller.getValues());
      expect(changed).assertFalse();
      expect(controller.getFieldState('name').dirty).assertTrue();
      expect(controller.errors['name']).assertEqual('请输入姓名');
    });

    it('external sync cancels pending validation without stale error writeback', 0, async (): Promise<void> => {
      const controller = new FormController(createFields(), {}, { 'debounceMs': 30 });
      const pending = controller.onChange('name', '');
      controller.syncValues({ 'name': '服务端回填', 'age': 21 });
      await pending;
      expect(controller.getValue('name') as string).assertEqual('服务端回填');
      expect(controller.getFieldState('name').dirty).assertFalse();
      expect(Object.keys(controller.errors).length).assertEqual(0);
    });

    it('ignores matching TextInput echoes after a clean external replacement', 0, async (): Promise<void> => {
      const controller = new FormController(createFields(), { 'name': '旧值', 'age': 20 }, { 'debounceMs': 0 });
      controller.syncValues({});
      await controller.onChange('name', '');
      await controller.onChange('age', undefined);
      expect(Object.keys(controller.getValues()).length).assertEqual(0);
      expect(controller.getFieldState('name').dirty).assertFalse();
      expect(controller.getFieldState('age').dirty).assertFalse();
      expect(Object.keys(controller.errors).length).assertEqual(0);
    });

    it('maps select labels and model values by stable option index', 0, (): void => {
      const source = [new FormSelectOption('上海市', 'shanghai'), new FormSelectOption('深圳市', 'shenzhen')];
      const field = new FormFieldSpec('city', FormFieldType.SELECT, '城市', v.string(), '请选择城市',
        undefined, { 'help': '用于安排线下服务', 'disabled': true, 'maxLength': 20, 'options': source });
      source.push(new FormSelectOption('杭州市', 'hangzhou'));

      expect(field.options.length).assertEqual(2);
      expect(field.selectIndex('shenzhen')).assertEqual(1);
      expect(field.selectLabel('shanghai')).assertEqual('上海市');
      expect(field.selectValue(1) as string).assertEqual('shenzhen');
      expect(field.selectIndex('unknown')).assertEqual(-1);
      expect(field.selectValue(9)).assertUndefined();
      expect(field.help).assertEqual('用于安排线下服务');
      expect(field.disabled).assertTrue();
      expect(field.maxLength as number).assertEqual(20);
    });

    it('maps checkbox values to a stable unique option-ordered string array', 0, (): void => {
      const field = new FormFieldSpec('interests', FormFieldType.CHECKBOX, '兴趣', v.array(v.string()), '',
        undefined, {
          'options': [
            new FormSelectOption('阅读', 'reading'),
            new FormSelectOption('运动', 'sports'),
            new FormSelectOption('音乐', 'music')
          ]
        });
      const normalized = field.checkboxValues(['music', 'reading', 'music', 'unknown']);
      expect(normalized.length).assertEqual(2);
      expect(normalized[0]).assertEqual('reading');
      expect(normalized[1]).assertEqual('music');
      const selected = field.toggleOptionValue(normalized, 'sports', true);
      expect(selected.length).assertEqual(3);
      expect(selected[1]).assertEqual('sports');
      const removed = field.toggleOptionValue(selected, 'reading', false);
      expect(removed.length).assertEqual(2);
      expect(removed[0]).assertEqual('sports');
      expect(field.isOptionSelected(removed, 'music')).assertTrue();
    });

    it('copies array values and preserves state for an equal parent echo', 0, async (): Promise<void> => {
      const field = new FormFieldSpec('interests', FormFieldType.CHECKBOX, '兴趣',
        v.array(v.string()).min(1, '至少选择一项'), '', undefined, {
          'options': [new FormSelectOption('阅读', 'reading'), new FormSelectOption('运动', 'sports')]
        });
      const initial: string[] = ['reading'];
      const controller = new FormController([field], { 'interests': initial }, { 'debounceMs': 0 });
      initial.push('sports');
      expect((controller.getValue('interests') as string[]).length).assertEqual(1);
      const snapshot = controller.getValue('interests') as string[];
      snapshot.push('sports');
      expect((controller.getValue('interests') as string[]).length).assertEqual(1);

      await controller.onChange('interests', ['reading', 'sports']);
      expect(controller.getFieldState('interests').dirty).assertTrue();
      const changed = controller.syncValues(controller.getValues());
      expect(changed).assertFalse();
      expect(controller.getFieldState('interests').dirty).assertTrue();
    });

    it('validates checkbox array length through validator', 0, async (): Promise<void> => {
      const field = new FormFieldSpec('interests', FormFieldType.CHECKBOX, '兴趣',
        v.array(v.string()).min(1, '至少选择一项'), '', undefined, {
          'options': [new FormSelectOption('阅读', 'reading'), new FormSelectOption('运动', 'sports')]
        });
      const controller = new FormController([field], { 'interests': [] }, { 'debounceMs': 0 });
      await controller.onChange('interests', []);
      expect(controller.errors['interests']).assertEqual('至少选择一项');
      await controller.onChange('interests', ['sports']);
      expect(controller.errors['interests']).assertUndefined();
    });

    it('mirrors pending field validation for the unified shell', 0, async (): Promise<void> => {
      const controller = new FormController(createFields(), {}, { 'debounceMs': 30 });
      const pending = controller.onChange('name', 'OpenHarmony');
      expect(controller.validating['name']).assertTrue();
      await pending;
      expect(controller.validating['name']).assertUndefined();
    });

    it('loads and defensively caches asynchronous options across reset', 0, async (): Promise<void> => {
      let resolveOptions: (options: FormSelectOption[]) => void = (_options: FormSelectOption[]): void => {};
      const field = new FormFieldSpec('city', FormFieldType.SELECT, '城市', v.string(), '', undefined, {
        'optionsLoader': (): Promise<FormSelectOption[]> => new Promise<FormSelectOption[]>(
          (resolve: (options: FormSelectOption[]) => void): void => {
            resolveOptions = resolve;
          })
      });
      const controller = new FormController([field], {}, { 'debounceMs': 0 });

      const pending = controller.loadOptions('city');
      expect(controller.optionsLoading['city']).assertTrue();
      resolveOptions([
        new FormSelectOption('上海市', 'shanghai'),
        new FormSelectOption('深圳市', 'shenzhen')
      ]);
      await pending;

      expect(controller.optionsLoading['city']).assertUndefined();
      expect(controller.optionErrors['city']).assertUndefined();
      const snapshot = controller.getOptions('city');
      expect(snapshot.length).assertEqual(2);
      snapshot.pop();
      expect(controller.getOptions('city').length).assertEqual(2);
      controller.reset();
      expect(controller.getOptions('city').length).assertEqual(2);
      expect(Object.keys(controller.optionErrors).length).assertEqual(0);
      controller.loadAllOptions();
      expect(controller.optionsLoading['city']).assertUndefined();
    });

    it('exposes loader failures and clears them after a valid retry', 0, async (): Promise<void> => {
      let attempt = 0;
      const field = new FormFieldSpec('city', FormFieldType.RADIO, '城市', v.string(), '', undefined, {
        'optionsLoader': async (): Promise<FormSelectOption[]> => {
          attempt++;
          if (attempt === 1) {
            throw new Error('城市服务暂不可用');
          }
          if (attempt === 2) {
            return [new FormSelectOption('重复 A', 'same'), new FormSelectOption('重复 B', 'same')];
          }
          return [new FormSelectOption('杭州市', 'hangzhou')];
        }
      });
      const controller = new FormController([field], {}, { 'debounceMs': 0 });

      await controller.loadOptions('city');
      expect(controller.optionErrors['city']).assertEqual('城市服务暂不可用');
      await controller.loadOptions('city');
      expect(controller.optionErrors['city']).assertEqual("Duplicate loaded option value 'same' in field: city");
      await controller.loadOptions('city');
      expect(controller.optionErrors['city']).assertUndefined();
      expect(controller.getOptions('city')[0].value).assertEqual('hangzhou');
    });

    it('keeps the newest option request and suppresses late results after dispose', 0, async (): Promise<void> => {
      let resolveFirst: (options: FormSelectOption[]) => void = (_options: FormSelectOption[]): void => {};
      let resolveSecond: (options: FormSelectOption[]) => void = (_options: FormSelectOption[]): void => {};
      let resolveThird: (options: FormSelectOption[]) => void = (_options: FormSelectOption[]): void => {};
      let request = 0;
      const field = new FormFieldSpec('city', FormFieldType.CHECKBOX, '城市', v.array(v.string()), '', undefined, {
        'optionsLoader': (): Promise<FormSelectOption[]> => new Promise<FormSelectOption[]>(
          (resolve: (options: FormSelectOption[]) => void): void => {
            request++;
            if (request === 1) {
              resolveFirst = resolve;
            } else if (request === 2) {
              resolveSecond = resolve;
            } else {
              resolveThird = resolve;
            }
          })
      });
      const controller = new FormController([field], {}, { 'debounceMs': 0 });

      const first = controller.loadOptions('city');
      const second = controller.loadOptions('city');
      resolveSecond([new FormSelectOption('新选项', 'new')]);
      await second;
      resolveFirst([new FormSelectOption('旧选项', 'old')]);
      await first;
      expect(controller.getOptions('city')[0].value).assertEqual('new');

      const third = controller.loadOptions('city');
      controller.dispose();
      resolveThird([new FormSelectOption('迟到选项', 'late')]);
      await third;
      expect(controller.getOptions('city')[0].value).assertEqual('new');
      expect(Object.keys(controller.optionsLoading).length).assertEqual(0);
      expect(Object.keys(controller.optionErrors).length).assertEqual(0);
    });

    it('keeps the newest value when async validation resolves out of order', 0, async (): Promise<void> => {
      let resolveFirst: (value: boolean) => void = (_value: boolean): void => {};
      let resolveSecond: (value: boolean) => void = (_value: boolean): void => {};
      const fields = [
        new FormFieldSpec('account', FormFieldType.TEXT, '账号', v.string().customAsync(
          (value: string): Promise<boolean> => new Promise<boolean>((resolve: (result: boolean) => void): void => {
            if (value === 'first') {
              resolveFirst = resolve;
            } else {
              resolveSecond = resolve;
            }
          }), '账号不可用'))
      ];
      const controller = new FormController(fields, {}, { 'debounceMs': 0 });

      const first = controller.onChange('account', 'first');
      const second = controller.onChange('account', 'second');
      resolveSecond(true);
      await second;
      resolveFirst(false);
      await first;

      expect(controller.getValue('account') as string).assertEqual('second');
      expect(controller.errors['account']).assertUndefined();
      expect(controller.validating['account']).assertUndefined();
    });

    it('reset isolates a late customAsync result from the new lifecycle', 0, async (): Promise<void> => {
      let resolvePending: (value: boolean) => void = (_value: boolean): void => {};
      const fields = [
        new FormFieldSpec('account', FormFieldType.TEXT, '账号', v.string().customAsync(
          (_value: string): Promise<boolean> => new Promise<boolean>((resolve: (result: boolean) => void): void => {
            resolvePending = resolve;
          }), '账号不可用'))
      ];
      const controller = new FormController(fields, {}, { 'debounceMs': 0 });

      const pending = controller.onChange('account', 'old');
      expect(controller.validating['account']).assertTrue();
      controller.reset({ 'account': 'reset-value' });
      resolvePending(false);
      await pending;

      expect(controller.getValue('account') as string).assertEqual('reset-value');
      expect(Object.keys(controller.errors).length).assertEqual(0);
      expect(Object.keys(controller.validating).length).assertEqual(0);
    });

    it('dispose suppresses a late customAsync error and loading state', 0, async (): Promise<void> => {
      let resolvePending: (value: boolean) => void = (_value: boolean): void => {};
      const fields = [
        new FormFieldSpec('account', FormFieldType.TEXT, '账号', v.string().customAsync(
          (_value: string): Promise<boolean> => new Promise<boolean>((resolve: (result: boolean) => void): void => {
            resolvePending = resolve;
          }), '账号不可用'))
      ];
      const controller = new FormController(fields, {}, { 'debounceMs': 0 });

      const pending = controller.onChange('account', 'pending');
      expect(controller.validating['account']).assertTrue();
      controller.dispose();
      resolvePending(false);
      await pending;

      expect(Object.keys(controller.errors).length).assertEqual(0);
      expect(Object.keys(controller.validating).length).assertEqual(0);
      expect(controller.submitting).assertFalse();
    });

    it('converts DatePicker dates to stable local calendar values', 0, (): void => {
      const start = new Date(2020, 0, 1);
      const field = new FormFieldSpec('date', FormFieldType.DATE, '日期', v.date().strict(), '请选择日期',
        undefined, { 'startDate': start, 'endDate': new Date(2030, 11, 31) });
      start.setFullYear(1990);

      expect(field.dateModelValue(new Date(2026, 8, 3))).assertEqual('2026-09-03');
      expect(field.dateDisplayValue('2026-09-03')).assertEqual('2026-09-03');
      expect(field.dateDisplayValue('not-a-date')).assertEqual('');
      expect(field.dateDisplayValue('2026-02-30')).assertEqual('');
      expect(field.dateSelected('2026-09-03').getFullYear()).assertEqual(2026);
      expect(field.dateSelected('2026-09-03').getMonth()).assertEqual(8);
      expect(field.startDate.getFullYear()).assertEqual(2020);
    });

    it('revalidates one-level dependencies and excludes hidden or disabled errors', 0,
      async (): Promise<void> => {
        const fields = [
          new FormFieldSpec('enabled', FormFieldType.SWITCH, '启用详情', v.boolean()),
          new FormFieldSpec('details', FormFieldType.TEXT, '详情', v.string().required('请输入详情'), '',
            undefined, {
              'dependencies': ['enabled'],
              'visibleWhen': (values: Record<string, Object>): boolean => values['enabled'] === true
            }),
          new FormFieldSpec('locked', FormFieldType.TEXT, '锁定项', v.string().required('锁定项不能为空'), '',
            undefined, { 'disabled': true })
        ];
        const controller = new FormController(fields, { 'enabled': false }, { 'debounceMs': 0 });

        const hiddenErrors = await controller.submit();
        expect(hiddenErrors['details']).assertUndefined();
        expect(hiddenErrors['locked']).assertUndefined();
        await controller.onChange('locked', '迟到事件');
        expect(controller.getValue('locked')).assertUndefined();

        await controller.onChange('enabled', true);
        expect(controller.errors['details']).assertEqual('请输入详情');
        expect(fields[1].isVisible(controller.getValues())).assertTrue();

        await controller.onChange('enabled', false);
        expect(controller.errors['details']).assertUndefined();
        expect(fields[1].isVisible(controller.getValues())).assertFalse();
      });

    it('combines static and conditional disabled state', 0, (): void => {
      const field = new FormFieldSpec('approval', FormFieldType.SWITCH, '审批', v.boolean(), '', undefined, {
        'dependencies': ['role'],
        'disabledWhen': (values: Record<string, Object>): boolean => values['role'] !== 'admin'
      });
      expect(field.isDisabled({ 'role': 'member' })).assertTrue();
      expect(field.isDisabled({ 'role': 'admin' })).assertFalse();
      expect(field.dependencies[0]).assertEqual('role');
    });

    it('infers scalar fields and descriptor UI metadata', 0, (): void => {
      const result = inferFormFields({
        'name': v.string().label('用户名').describe('用于登录').max(20),
        'age': v.number(),
        'enabled': v.boolean(),
        'birthday': v.date().min(new Date(2000, 0, 1)).max(new Date(2030, 11, 31))
      });
      expect(result.fields.length).assertEqual(4);
      expect(result.fields[0].type).assertEqual(FormFieldType.TEXT);
      expect(result.fields[0].label).assertEqual('用户名');
      expect(result.fields[0].help).assertEqual('用于登录');
      expect(result.fields[0].placeholder).assertEqual('请输入用户名');
      expect(result.fields[0].maxLength as number).assertEqual(20);
      expect(result.fields[1].type).assertEqual(FormFieldType.NUMBER);
      expect(result.fields[2].type).assertEqual(FormFieldType.SWITCH);
      expect(result.fields[3].type).assertEqual(FormFieldType.DATE);
      expect(result.fields[3].startDate.getFullYear()).assertEqual(2000);
      expect(result.fields[3].endDate.getFullYear()).assertEqual(2030);
      expect(result.fields[0].schema.validate('valid-name').valid).assertTrue();
    });

    it('infers string enum, enum array and literal union options', 0, (): void => {
      const result = inferFormFields({
        'status': v.enumOf(['draft', 'done']),
        'roles': v.array(v.enumOf(['reader', 'editor'])),
        'mode': v.union<string>([v.literal('simple'), v.literal('advanced')])
      });
      expect(result.fields[0].type).assertEqual(FormFieldType.SELECT);
      expect(result.fields[0].options[1].value).assertEqual('done');
      expect(result.fields[1].type).assertEqual(FormFieldType.CHECKBOX);
      expect(result.fields[1].options[0].label).assertEqual('reader');
      expect(result.fields[2].type).assertEqual(FormFieldType.SELECT);
      expect(result.fields[2].options[1].value).assertEqual('advanced');
    });

    it('returns defensive schema default snapshots through wrappers', 0, (): void => {
      const defaults: string[] = ['reader'];
      const result = inferFormFields({
        'nickname': v.string().nullable().default('访客').label('昵称'),
        'roles': v.array(v.enumOf(['reader', 'editor'])).default(defaults)
      });
      defaults.push('editor');
      const first = result.getInitialValues();
      expect(first['nickname'] as string).assertEqual('访客');
      expect((first['roles'] as string[]).length).assertEqual(1);
      (first['roles'] as string[]).push('editor');
      expect((result.getInitialValues()['roles'] as string[]).length).assertEqual(1);
    });

    it('merges explicit field and UI overrides without changing validation', 0, (): void => {
      const transformed = v.string().required('请输入原值').transform<number>((value: string): number => value.length);
      const result = inferFormFields({ 'summary': transformed }, {
        'summary': {
          'type': FormFieldType.TEXTAREA,
          'label': '摘要',
          'placeholder': '填写摘要',
          'uiOptions': { 'help': '最多一段', 'maxLength': 80, 'span': 6 }
        }
      });
      const field = result.fields[0];
      expect(field.type).assertEqual(FormFieldType.TEXTAREA);
      expect(field.label).assertEqual('摘要');
      expect(field.placeholder).assertEqual('填写摘要');
      expect(field.help).assertEqual('最多一段');
      expect(field.maxLength as number).assertEqual(80);
      expect(field.span).assertEqual(6);
      expect(field.schema.validate('').valid).assertFalse();
    });

    it('fails fast for ambiguous schemas and misspelled overrides', 0, (): void => {
      expectConfigurationError((): void => {
        inferFormFields({ 'profile': v.object({ 'name': v.string() }) });
      }, "Cannot infer form field 'profile'");
      expectConfigurationError((): void => {
        inferFormFields({ 'priority': v.enumOf([1, 2]) });
      }, 'non-string enum');
      expectConfigurationError((): void => {
        inferFormFields({ 'name': v.string() }, { 'naem': { 'type': FormFieldType.TEXT } });
      }, 'Unknown form field inference override: naem');
    });

    it('reads and immutably writes nested form value paths', 0, (): void => {
      const original: Record<string, Object> = {
        'profile': { 'name': '旧名称', 'tags': ['reader'] } as Record<string, Object>
      };
      const changed = setFormValue(original, 'profile.name', '新名称');
      expect(getFormValue(original, 'profile.name') as string).assertEqual('旧名称');
      expect(getFormValue(changed, 'profile.name') as string).assertEqual('新名称');
      const tags = getFormValue(changed, 'profile.tags') as string[];
      tags.push('editor');
      expect((getFormValue(changed, 'profile.tags') as string[]).length).assertEqual(1);

      const removed = setFormValue(changed, 'profile.name', undefined);
      expect(getFormValue(removed, 'profile.name')).assertUndefined();
      expect((getFormValue(removed, 'profile.tags') as string[])[0]).assertEqual('reader');
    });

    it('keeps nested public values while validating full field paths', 0, async (): Promise<void> => {
      const fields = [
        new FormFieldSpec('profile.name', FormFieldType.TEXT, '姓名', v.string().required('请输入姓名')),
        new FormFieldSpec('profile.age', FormFieldType.NUMBER, '年龄', v.number().min(18, '年龄不足'))
      ];
      const controller = new FormController(fields, {
        'profile': { 'name': '初始', 'age': 20 } as Record<string, Object>
      }, { 'debounceMs': 0 });
      expect(controller.getValue('profile.name') as string).assertEqual('初始');
      await controller.onChange('profile.name', '更新');
      expect(getFormValue(controller.getValues(), 'profile.name') as string).assertEqual('更新');
      expect(controller.getValues()['profile.name']).assertUndefined();

      await controller.onChange('profile.age', 16);
      expect(controller.errors['profile.age']).assertEqual('年龄不足');
      expect((await controller.submit())['profile.age']).assertEqual('年龄不足');
      expect(controller.firstErrorName()).assertEqual('profile.age');
    });

    it('deeply snapshots nested values and preserves equal controlled echoes', 0, async (): Promise<void> => {
      const field = new FormFieldSpec('profile.roles', FormFieldType.CHECKBOX, '角色',
        v.array(v.string()), '', undefined, {
          'options': [new FormSelectOption('读者', 'reader'), new FormSelectOption('编辑', 'editor')]
        });
      const controller = new FormController([field], {
        'profile': { 'roles': ['reader'] } as Record<string, Object>
      }, { 'debounceMs': 0 });
      const snapshot = controller.getValues();
      (getFormValue(snapshot, 'profile.roles') as string[]).push('editor');
      expect((controller.getValue('profile.roles') as string[]).length).assertEqual(1);
      expect(controller.syncValues({
        'profile': { 'roles': ['reader'] } as Record<string, Object>
      })).assertFalse();

      expect(controller.syncValues({
        'profile': { 'roles': ['reader', 'editor'] } as Record<string, Object>
      })).assertTrue();
      await controller.onChange('profile.roles', ['reader', 'editor']);
      expect(controller.getFieldState('profile.roles').dirty).assertFalse();
    });

    it('revalidates nested full-path dependencies with projected siblings', 0, async (): Promise<void> => {
      const fields = [
        new FormFieldSpec('address.country', FormFieldType.TEXT, '国家', v.string()),
        new FormFieldSpec('address.postcode', FormFieldType.TEXT, '邮编',
          v.string().requiredWhen('address.country',
            (country: Object | null | undefined): boolean => country === 'CN', '请输入邮编'), '', undefined, {
            'dependencies': ['address.country'],
            'visibleWhen': (values: Record<string, Object>): boolean =>
              getFormValue(values, 'address.country') === 'CN'
          })
      ];
      const controller = new FormController(fields, {}, { 'debounceMs': 0 });
      await controller.onChange('address.country', 'CN');
      expect(controller.errors['address.postcode']).assertEqual('请输入邮编');
      expect(fields[1].isVisible(controller.getValues())).assertTrue();
      await controller.onChange('address.postcode', '200000');
      expect(controller.errors['address.postcode']).assertUndefined();
    });

    it('rejects invalid, indexed and conflicting field paths', 0, (): void => {
      const invalid = ['.name', 'profile..name', 'items[0].name', 'items.0.name', '__proto__.name'];
      for (const name of invalid) {
        expectConfigurationError((): void => {
          new FormFieldSpec(name, FormFieldType.TEXT, '非法路径', v.string());
        }, 'Invalid form field path');
      }
      expectConfigurationError((): void => {
        new FormController([
          new FormFieldSpec('profile', FormFieldType.TEXT, '资料', v.string()),
          new FormFieldSpec('profile.name', FormFieldType.TEXT, '姓名', v.string())
        ]);
      }, 'Conflicting form field paths: profile and profile.name');
      expectConfigurationError((): void => {
        new FormFieldSpec('name', FormFieldType.TEXT, '姓名', v.string(), '', undefined, {
          'dependencies': ['items.0.name']
        });
      }, 'Invalid form field path: items.0.name');
    });

    it('creates nested initial values for inferred dotted fields', 0, (): void => {
      const inferred = inferFormFields({
        'profile.name': v.string().default('访客').label('姓名'),
        'profile.roles': v.array(v.enumOf(['reader', 'editor'])).default(['reader']).label('角色')
      });
      const initial = inferred.getInitialValues();
      expect(getFormValue(initial, 'profile.name') as string).assertEqual('访客');
      expect((getFormValue(initial, 'profile.roles') as string[])[0]).assertEqual('reader');
      expect(initial['profile.name']).assertUndefined();
    });
  });
}
