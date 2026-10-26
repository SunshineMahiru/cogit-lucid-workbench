import { NoteFieldKey } from '../NoteFieldKey';
import { NoteTemplateId } from '../NoteTemplateId';
import { NoteTemplate } from '../NoteTemplate';

/** Emotion capture: the trigger first, then the emotion and how strong it was. */
export const EMOTION_NOTE_TEMPLATE: NoteTemplate = {
  id: NoteTemplateId.EMOTION,
  label: '情绪',
  hint: '先写触发，再写情绪本身',
  createsDecision: false,
  fields: [
    {
      key: NoteFieldKey.TRIGGER,
      label: '触发',
      placeholder: '发生了什么？',
      required: true,
      multiline: true
    },
    {
      key: NoteFieldKey.EMOTION,
      label: '情绪',
      placeholder: '这是什么情绪？',
      required: false,
      multiline: false
    },
    {
      key: NoteFieldKey.INTENSITY,
      label: '强度',
      placeholder: '1 到 10 之间填一个数',
      required: false,
      multiline: false
    }
  ],
  defaultTags: ['情绪']
};
