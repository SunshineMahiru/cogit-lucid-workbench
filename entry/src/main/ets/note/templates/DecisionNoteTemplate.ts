import { NoteFieldKey } from '../NoteFieldKey';
import { NoteTemplateId } from '../NoteTemplateId';
import { NoteTemplate } from '../NoteTemplate';

/** Decision capture: what I faced, what I chose and what I expect from it. */
export const DECISION_NOTE_TEMPLATE: NoteTemplate = {
  id: NoteTemplateId.DECISION,
  label: '决策',
  hint: '把选择与预期写下来，留给结果检验',
  createsDecision: true,
  fields: [
    {
      key: NoteFieldKey.BACKGROUND,
      label: '背景',
      placeholder: '当时面对什么情况？',
      required: true,
      multiline: true
    },
    {
      key: NoteFieldKey.OPTIONS,
      label: '选项',
      placeholder: '有哪些备选？每行一个',
      required: false,
      multiline: true
    },
    {
      key: NoteFieldKey.CHOICE,
      label: '选择',
      placeholder: '最后选了哪一个？',
      required: false,
      multiline: false
    },
    {
      key: NoteFieldKey.EXPECTED_OUTCOME,
      label: '预期',
      placeholder: '希望它带来什么结果？',
      required: false,
      multiline: true
    }
  ],
  defaultTags: ['决策']
};
