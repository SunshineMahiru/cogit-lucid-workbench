/** A tappable chip for the quick-entry section of the dashboard. */
@ComponentV2
export struct EntryChip {
  @Param label: string = '';
  @Event onTap: () => void = () => {};

  private iconForLabel(label: string): string {
    const icons: Record<string, string> = {
      '速记': '📝',
      '预测': '🔮',
      '复盘': '🔄',
      '锚点': '⭐',
      '状态': '📊',
      '关系': '🔗'
    };
    return icons[label] ?? '📌';
  }

  build() {
    Row({ space: 4 }) {
      Text(this.iconForLabel(this.label))
        .fontSize(14)
      Text(this.label)
        .fontSize(13)
        .fontColor('#1F2329')
    }
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .backgroundColor(Color.White)
    .borderRadius(16)
    .onClick(() => {
      this.onTap();
    })
  }
}