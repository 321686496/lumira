/*
 * Copyright (C) 2024 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// 防抖 在一段时间内函数被多次触发，防抖让函数在一段时间后最终只执行一次
import { detectBarcode } from '@kit.ScanKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { image } from '@kit.ImageKit';

export function debounce(func: () => void, delay?: number) {
  let timer: number;
  return () => {
    clearTimeout(timer);
    timer = setTimeout(() => {
      func();
    }, delay ? delay : 1000);
  };
}

export function throttle(func: (detectBarcode: detectBarcode.DetectResult) => void, delay?: number) {
  let inThrottle: boolean;
  return (detectBarcode: detectBarcode.DetectResult) => {
    if (!inThrottle) {
      func(detectBarcode);
      inThrottle = true;
      setTimeout(() => inThrottle = false, delay ? delay : 1000);
    }
  }
}

// 防抖
export class MyDebounceSingletonUtil {
  private static instance: MyDebounceSingletonUtil;
  private static methodsMap: Map<string, number> = new Map();

  public static getInstance(): MyDebounceSingletonUtil {
    if (!MyDebounceSingletonUtil.instance) {
      MyDebounceSingletonUtil.instance = new MyDebounceSingletonUtil();
    }
    return MyDebounceSingletonUtil.instance;
  }

  public isDebounced(methodName: string, milliseconds: number): boolean {
    const now = Date.now();
    const lastExecutionTime = MyDebounceSingletonUtil.methodsMap.get(methodName);
    if (lastExecutionTime && (now - lastExecutionTime) < milliseconds) {
      console.info(`${methodName}方法在指定时间${milliseconds}内已执行过`)
      return true; // 方法在指定时间内已执行过
    } else {
      MyDebounceSingletonUtil.methodsMap.set(methodName, now);
      return false; // 方法在指定时间内未执行过
    }
  }
}