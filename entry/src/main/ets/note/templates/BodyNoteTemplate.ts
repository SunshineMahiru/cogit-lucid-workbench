import { NoteFieldKey } from '../NoteFieldKey';
import { NoteTemplateId } from '../NoteTemplateId';
import { NoteTemplate } from '../NoteTemplate';

/** Body capture: physical signal first, explanation second. */
export const BODY_NOTE_TEMPLATE: NoteTemplate = {
  id: NoteTemplateId.BODY,
  label: '身体',
  hint: '记录身体信号，先于解释',
  createsDecision: false,
  fields: [
    {
      key: NoteFieldKey.BODY_SIGNAL,
      label: '信号',
      placeholder: '身体有什么变化或不适？',
      required: true,
      multiline: true
    },
    {
      key: NoteFieldKey.CAUSE,
      label: '可能原因',
      placeholder: '睡眠、饮食或运动上的可能原因',
      required: false,
      multiline: true
    },
    {
      key: NoteFieldKey.ACTION,
      label: '处置',
      placeholder: '已经做了什么，或打算做什么？',
      required: false,
      multiline: true
    }
  ],
  defaultTags: ['身体']
};
