import { NoteFieldKey } from '../NoteFieldKey';
import { NoteTemplateId } from '../NoteTemplateId';
import { NoteTemplate } from '../NoteTemplate';

/** Interpersonal capture: one interaction and what it left behind. */
export const INTERPERSONAL_NOTE_TEMPLATE: NoteTemplate = {
  id: NoteTemplateId.INTERPERSONAL,
  label: '人际',
  hint: '记下一次互动，以及它带来的感受',
  createsDecision: false,
  fields: [
    {
      key: NoteFieldKey.PERSON,
      label: '对象',
      placeholder: '用代称，不写真实姓名',
      required: false,
      multiline: false
    },
    {
      key: NoteFieldKey.INTERACTION,
      label: '互动',
      placeholder: '发生了什么？',
      required: true,
      multiline: true
    },
    {
      key: NoteFieldKey.FEELING,
      label: '感受',
      placeholder: '这次互动让我感觉如何？',
      required: false,
      multiline: true
    }
  ],
  defaultTags: ['人际']
};
