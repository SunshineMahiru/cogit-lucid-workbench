import { AppTheme } from '../../theme/AppTheme';
import { AgendaItem, AgendaTone } from '../../home/AgendaMapper';
import { SectionCard } from '../../components/SectionCard';

/** Today's practice board: one coloured row per record that still needs handling. */
@ComponentV2
export struct AgendaCard {
  @Param items: AgendaItem[] = [];
  @Event onOpen: (item: AgendaItem) => void = () => {
  };

  build() {
    SectionCard() {
      Column({ space: AppTheme.spacing.s10 }) {
        Row() {
          Text('今日实践台')
            .fontSize(AppTheme.font.subtitle)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.color.text)
          Blank()
          Text(`${this.items.length} 项`)
            .fontSize(AppTheme.font.caption)
            .fontColor(AppTheme.color.textMuted)
        }
        .width('100%')

        if (this.items.length === 0) {
          Text('今天没有待处置的对象')
            .fontSize(AppTheme.font.body)
            .fontColor(AppTheme.color.textMuted)
            .width('100%')
            .padding({ top: AppTheme.spacing.s8, bottom: AppTheme.spacing.s8 })
        } else {
          Column() {
            ForEach(this.items, (item: AgendaItem) => {
              this.agendaRow(item)
            }, (item: AgendaItem) => item.key)
          }
          .width('100%')
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  private toneColor(tone: AgendaTone): string {
    if (tone === AgendaTone.PRACTICE) {
      return AppTheme.color.evPractice;
    }
    if (tone === AgendaTone.TIME) {
      return AppTheme.color.evTime;
    }
    if (tone === AgendaTone.BOOK) {
      return AppTheme.color.evBook;
    }
    if (tone === AgendaTone.PUBLIC) {
      return AppTheme.color.evPublic;
    }
    return AppTheme.color.evOther;
  }

  @Builder
  agendaRow(item: AgendaItem) {
    Row({ space: AppTheme.spacing.s10 }) {
      Circle()
        .width(6)
        .height(6)
        .fill(this.toneColor(item.tone))
      Column({ space: 2 }) {
        Text(item.title)
          .fontSize(AppTheme.font.bodyStrong)
          .fontColor(AppTheme.color.text)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(item.detail)
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.textMuted)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      SymbolGlyph($r('sys.symbol.chevron_forward'))
        .fontSize(14)
        .fontColor([AppTheme.color.textMuted])
    }
    .width('100%')
    .constraintSize({ minHeight: 48 })
    .accessibilityText(`${item.title}，${item.detail}`)
    .onClick(() => {
      this.onOpen(item);
    })
  }
}