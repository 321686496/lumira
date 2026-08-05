/**
 * HTTP 请求封装
 *
 * 统一 baseUrl 与 Bearer JWT 注入。Token 持久化于 localStorage，
 * 由登录/设备激活流程写入（key: lumira_auth_token）。
 */

/** 后端 API 基础地址 */
export const API_BASE_URL = 'https://lumira.iwtle.top/api/v1'

/** Token 存储 key */
const TOKEN_KEY = 'lumira_auth_token'

/** 设备 ID 存储 key（后端按 deviceId 颁发 JWT） */
const DEVICE_ID_KEY = 'lumira_device_id'

/** 读取本地 JWT */
export function getAuthToken(): string {
  return uni.getStorageSync(TOKEN_KEY) || ''
}

/** 写入本地 JWT */
export function setAuthToken(token: string): void {
  uni.setStorageSync(TOKEN_KEY, token)
}

/** 读取本地 deviceId */
export function getDeviceId(): string {
  return uni.getStorageSync(DEVICE_ID_KEY) || ''
}

/** 写入本地 deviceId */
export function setDeviceId(deviceId: string): void {
  uni.setStorageSync(DEVICE_ID_KEY, deviceId)
}

/** 通用后端错误 */
export class ApiError extends Error {
  statusCode: number
  constructor(message: string, statusCode: number) {
    super(message)
    this.name = 'ApiError'
    this.statusCode = statusCode
  }
}

interface RequestOptions {
  /** 查询参数 */
  query?: Record<string, string | number | boolean | undefined>
  /** 请求体 */
  data?: Record<string, unknown>
  /** 是否跳过 Authorization 头（默认 false） */
  skipAuth?: boolean
}

/** 拼接 query string */
function buildQueryString(query: Record<string, string | number | boolean | undefined>): string {
  const parts: string[] = []
  Object.keys(query).forEach(key => {
    const value = query[key]
    if (value === undefined || value === null) return
    parts.push(`${encodeURIComponent(key)}=${encodeURIComponent(String(value))}`)
  })
  return parts.length ? `?${parts.join('&')}` : ''
}

/**
 * 发起 GET 请求
 * @param path 路径（以 / 开头，将拼接到 API_BASE_URL 后）
 * @param options 选项
 */
export async function get<T = unknown>(path: string, options: RequestOptions = {}): Promise<T> {
  return request<T>('GET', path, options)
}

/**
 * 发起 POST 请求
 * @param path 路径
 * @param options 选项
 */
export async function post<T = unknown>(path: string, options: RequestOptions = {}): Promise<T> {
  return request<T>('POST', path, options)
}

/** 底层请求实现 */
function request<T>(
  method: 'GET' | 'POST',
  path: string,
  options: RequestOptions
): Promise<T> {
  const url = `${API_BASE_URL}${path}${buildQueryString(options.query || {})}`

  const header: Record<string, string> = {
    'Content-Type': 'application/json',
  }
  if (!options.skipAuth) {
    const token = getAuthToken()
    if (token) {
      header['Authorization'] = `Bearer ${token}`
    }
  }

  return new Promise<T>((resolve, reject) => {
    uni.request({
      url,
      method,
      data: options.data,
      header,
      success: (res) => {
        const status = res.statusCode || 0
        const body = res.data as T & { message?: string; error?: string }

        if (status >= 200 && status < 300) {
          resolve(body)
          return
        }

        if (status === 401) {
          // 未授权：清空 token，提示
          setAuthToken('')
        }

        const message =
          (body && typeof body === 'object' && (body as { message?: string }).message) ||
          (body && typeof body === 'object' && (body as { error?: string }).error) ||
          `请求失败 (${status})`
        reject(new ApiError(message, status))
      },
      fail: (err) => {
        reject(new ApiError(err.errMsg || '网络异常', 0))
      },
    })
  })
}
