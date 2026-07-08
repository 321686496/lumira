export interface Inspiration {
  id: number
  text: string
  emoji: string
  relatedCategory: string
}

export const INSPIRATION_POOL: Inspiration[] = [
  { id: 1, text: '侧身站立+回头看镜头，显瘦又自然', emoji: '🌿', relatedCategory: '人像' },
  { id: 2, text: '逆光下让头发发光，脸部用反光板补光', emoji: '☀️', relatedCategory: '日落' },
  { id: 3, text: '坐在咖啡馆窗边，自然光从侧面打来', emoji: '☕', relatedCategory: '咖啡馆' },
  { id: 4, text: '蹲下拍花卉特写，背景自然虚化', emoji: '🌸', relatedCategory: '花店' },
  { id: 5, text: '海边奔跑抓拍，快门速度调至 1/500s 以上', emoji: '🏖️', relatedCategory: '海边' },
  { id: 6, text: '街拍用长焦压缩街景，人物更突出', emoji: '🏙️', relatedCategory: '街拍' },
  { id: 7, text: '探店拍美食，45°俯拍+大光圈虚化背景', emoji: '🛍️', relatedCategory: '探店' },
  { id: 8, text: '居家窗前自然光，白色窗帘做柔光罩', emoji: '🏠', relatedCategory: '居家' },
  { id: 9, text: '纪念日手捧花束，用引导线构图聚焦表情', emoji: '🎂', relatedCategory: '纪念日' },
  { id: 10, text: '合照错落站位，前后各半步更有层次', emoji: '👭', relatedCategory: '合照' },
  { id: 11, text: '低头微笑，让风吹动发丝更自然', emoji: '🍃', relatedCategory: '人像' },
  { id: 12, text: '黄昏时段拍摄剪影，降低 EV -0.7', emoji: '🌅', relatedCategory: '日落' },
  { id: 13, text: '用手挡住半边脸，神秘又显瘦', emoji: '👋', relatedCategory: '人像' },
  { id: 14, text: '图书馆里翻书侧拍，安静文艺感', emoji: '📚', relatedCategory: '探店' },
  { id: 15, text: '雨后街面倒影，低角度蹲拍', emoji: '🌧️', relatedCategory: '街拍' },
  { id: 16, text: '靠墙站立，一脚微曲更放松', emoji: '🧱', relatedCategory: '人像' },
  { id: 17, text: '日落前 30 分钟是黄金时段', emoji: '⏰', relatedCategory: '日落' },
  { id: 18, text: '居家沙发上的慵懒姿势，用毯子做道具', emoji: '🛋️', relatedCategory: '居家' },
  { id: 19, text: '合照时不要所有人看镜头，有人看别处更生动', emoji: '👀', relatedCategory: '合照' },
  { id: 20, text: '花束放胸前，微微仰头看花', emoji: '💐', relatedCategory: '纪念日' },
]
