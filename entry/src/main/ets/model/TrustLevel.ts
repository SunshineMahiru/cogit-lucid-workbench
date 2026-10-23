/**
 * 关系信任分层三级：对应「对所有人友善，对少数人真诚，对极少数人完全透明」。
 */
export enum TrustLevel {
  /** 友善：对所有人 */
  FRIENDLY = 'friendly',
  /** 真诚：对少数人 */
  SINCERE = 'sincere',
  /** 透明：对极少数人 */
  TRANSPARENT = 'transparent'
}
