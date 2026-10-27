/** Tag chips with a small inline input for adding a custom tag. */
@ComponentV2
export struct NoteTagEditor {
  @Param tags: string[] = [];
  @Event onAdd: (tag: string) => void = () => {};
  @Event onRemove: (tag: string) => void = () => {};
  @Local draftTag: string = '';

  private submit(): void {
    const value = this.draftTag.trim();
    if (value.length === 0) {
      return;
    }
    this.onAdd(value);
    this.draftTag = '';
  }

  build() {
    Column({ space: 8 }) {
      Text('标签')
        .fontSize(12)
        .fontColor('#8A8F99')
        .width('100%')
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.tags, (tag: string) => {
          Text(`${tag} ×`)
            .fontSize(11)
            .fontColor('#185FA5')
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .backgroundColor('#E8EFF7')
            .borderRadius(10)
            .margin({ right: 6, bottom: 6 })
            .onClick(() => {
              this.onRemove(tag);
            })
        }, (tag: string) => tag)
        Row({ space: 4 }) {
          TextInput({ text: this.draftTag, placeholder: '新增标签' })
            .width(96)
            .height(28)
            .fontSize(12)
            .padding({ left: 8, right: 8 })
            .backgroundColor('#F7F9FC')
            .borderRadius(10)
            .border({ width: 0.5, color: '#E0E0E0' })
            .onChange((value: string) => {
              this.draftTag = value;
            })
            .onSubmit(() => {
              this.submit();
            })
          Text('＋')
            .fontSize(16)
            .fontColor('#4A6FA5')
            .padding({ left: 4, right: 4 })
            .onClick(() => {
              this.submit();
            })
        }
        .margin({ bottom: 6 })
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
