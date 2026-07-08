import { computed } from 'vue'
import { INSPIRATION_POOL, type Inspiration } from '@/data/inspirations'

/** 简单日期哈希：返回 0 ~ max-1 的整数 */
function dateHash(max: number): number {
  const now = new Date()
  const dateNum = now.getFullYear() * 10000 + (now.getMonth() + 1) * 100 + now.getDate()
  return dateNum % max
}

export function useDailyInspiration() {
  const inspiration = computed<Inspiration>(() => {
    const index = dateHash(INSPIRATION_POOL.length)
    return INSPIRATION_POOL[index]
  })

  return { inspiration }
}
