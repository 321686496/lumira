export interface SceneDef {
  key: string
  label: string
  emoji: string
  category: string
}

export const SCENES: SceneDef[] = [
  { key: 'cafe', label: '咖啡馆', emoji: '☕', category: '咖啡馆' },
  { key: 'flower', label: '花店', emoji: '🌸', category: '花店' },
  { key: 'beach', label: '海边', emoji: '🏖️', category: '海边' },
  { key: 'street', label: '街拍', emoji: '🏙️', category: '街拍' },
  { key: 'shop', label: '探店', emoji: '🛍️', category: '探店' },
  { key: 'home', label: '居家', emoji: '🏠', category: '居家' },
  { key: 'anniversary', label: '纪念日', emoji: '🎂', category: '纪念日' },
  { key: 'group', label: '合照', emoji: '👭', category: '合照' },
]
