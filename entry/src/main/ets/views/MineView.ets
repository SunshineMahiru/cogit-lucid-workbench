import { AppTheme } from '../theme/AppTheme';
import { TabHeader } from '../components/TabHeader';
import { IdentityCard } from '../components/IdentityCard';
import { SectionCard } from '../components/SectionCard';
import { ROUTES } from '../navigation/Routes';

/**
 * Mine tab: the identity card moved here from the old home page, plus the profile, settings and
 * background entries. Every entry pushes a full-screen page and returns to this tab.
 */
@ComponentV2
export struct MineView {
  @Require @Param pathStack: NavPathStack;
  @Local identityVersion: number = 0;
  private lastPushAt: number = 0;

  private push(route: string, reloadIdentity: boolean): void {
    const now = Date.now();
    if (now - this.lastPushAt < 600) {
      return;
    }
    this.lastPushAt = now;
    this.pathStack.pushPathByName(route, null, () => {
      if (reloadIdentity) {
        this.identityVersion += 1;
      }
    });
  }

  @Builder
  entryRow(rowId: string, label: string, hint: string, route: string, reloadIdentity: boolean, divider: boolean) {
    Row({ space: AppTheme.spacing.s12 }) {
      Column({ space: AppTheme.spacing.s2 }) {
        Text(label)
          .fontSize(AppTheme.font.bodyStrong)
          .fontColor(AppTheme.color.text)
          .width('100%')
        Text(hint)
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.textMuted)
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      SymbolGlyph($r('sys.symbol.chevron_forward'))
        .fontSize(16)
        .fontColor([AppTheme.color.textSecondary])
    }
    .id(rowId)
    .width('100%')
    .constraintSize({ minHeight: 56 })
    .padding({ left: AppTheme.spacing.s16, right: AppTheme.spacing.s16 })
    .alignItems(VerticalAlign.Center)
    .border({ width: divider ? { bottom: 0.5 } : { bottom: 0 }, color: AppTheme.color.border })
    .accessibilityText(label)
    .onClick(() => {
      this.push(route, reloadIdentity);
    })
  }

  build() {
    Column() {
      TabHeader({ title: '我的' })

      Scroll() {
        Column({ space: AppTheme.spacing.s12 }) {
          SectionCard() {
            IdentityCard({
              showAvatar: true,
              refreshToken: this.identityVersion,
              onEdit: () => {
                this.push(ROUTES.IDENTITY_EDIT, true);
              }
            })
          }

          SectionCard({ contentPadding: 0 }) {
            Column() {
              this.entryRow('mine_entry_identity', '身份编辑', '头像、昵称与签名', ROUTES.IDENTITY_EDIT, true, true)
              this.entryRow('mine_entry_settings', '设置', '模型、密级与数据导出', ROUTES.SETTINGS, false, true)
              this.entryRow('mine_entry_background', '页面背景', '按页面分组设置本机图片', ROUTES.BACKGROUND_APPLY, false, false)
            }
            .width('100%')
          }
        }
        .width('100%')
        .padding({
          left: AppTheme.spacing.s16,
          right: AppTheme.spacing.s16,
          top: AppTheme.spacing.s4,
          bottom: AppTheme.spacing.s24
        })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
  }
}