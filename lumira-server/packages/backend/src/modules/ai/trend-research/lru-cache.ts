// lumira-server/packages/backend/src/modules/ai/trend-research/lru-cache.ts
// 极简进程内 LRU（研究模块共用）：搜索命中缓存与资料整理结果缓存都用它。
// key 访问即刷新顺序；超出 max 淘汰最久未用项。

export class LruCache<T> {
  private map = new Map<string, T>();

  constructor(private readonly max = 200) {}

  get(key: string): T | undefined {
    const v = this.map.get(key);
    if (v === undefined) return undefined;
    // 刷新：删除后重插置末位，保持 LRU 顺序
    this.map.delete(key);
    this.map.set(key, v);
    return v;
  }

  set(key: string, value: T): void {
    if (this.map.has(key)) this.map.delete(key);
    this.map.set(key, value);
    if (this.map.size > this.max) {
      const oldest = this.map.keys().next().value;
      if (oldest !== undefined) this.map.delete(oldest);
    }
  }

  clear(): void {
    this.map.clear();
  }
}