/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*/

import HiLog from '@ohos.hilog';
import BuildProfile from '../../../../BuildProfile';

const DOMAIN: number = 0x00FF;
const TAG = "Flutter";
const SYMBOL = " --> ";
// const FILTER_KEYS = [
//   new RegExp('hide', "gi")
// ]

// export function filterKey(target: any, propKey: string, descriptor: PropertyDescriptor) {
//   const original = descriptor.value;
//   descriptor.value = function (...args: string[]) {
//     let filterResult = args.map((str) => {
//       let tempStr = str
//       FILTER_KEYS.forEach((filterKey) => tempStr = tempStr.replace(filterKey, "**"))
//       return tempStr
//     });
//     const result = original.call(this, ...filterResult);
//     return result;
//   };
// }

/**
 * Basic log class
 */
export default class Log {
  private static _logLevel = HiLog.LogLevel.WARN;

  /**
   * Set log level.
   *
   * @param level Indecated the log level.
   */
  public static setLogLevel(level: HiLog.LogLevel) {
    Log._logLevel = level;
  }

  /**
   * Outputs debug-level logs.
   *
   * @param tag Identifies the log tag.
   * @param format Indicates the log format string.
   * @param args Indicates the log parameters.
   * @since 7
   */
  static d(tag: string, format: string, ...args: Object[]) {
    if (Log.isLoggable(HiLog.LogLevel.DEBUG)) {
      HiLog.debug(DOMAIN, TAG, tag + SYMBOL + format, args);
    }
  }

  /**
   * Outputs info-level logs.
   *
   * @param tag Identifies the log tag.
   * @param format Indicates the log format string.
   * @param args Indicates the log parameters.
   * @since 7
   */
  static i(tag: string, format: string, ...args: Object[]) {
    if (Log.isLoggable(HiLog.LogLevel.INFO)) {
      HiLog.info(DOMAIN, TAG, tag + SYMBOL + format, args);
    }
  }

  /**
   * Outputs warning-level logs.
   *
   * @param tag Identifies the log tag.
   * @param format Indicates the log format string.
   * @param args Indicates the log parameters.
   * @since 7
   */
  static w(tag: string, format: string, ...args: Object[]) {
    if (Log.isLoggable(HiLog.LogLevel.WARN)) {
      HiLog.warn(DOMAIN, TAG, tag + SYMBOL + format, args);
    }
  }

  /**
   * Outputs error-level logs.
   *
   * @param tag Identifies the log tag.
   * @param format Indicates the log format string.
   * @param args Indicates the log parameters.
   * @since 7
   */
  static e(tag: string, format: string, ...args: Object[]) {
    if (Log.isLoggable(HiLog.LogLevel.ERROR)) {
      args.forEach((item: Object, index: number) => {
        if (item instanceof Error) {
          args[index] = item.message + item.stack;
        }
        format+="%{public}s";
      })
      HiLog.error(DOMAIN, TAG, tag + SYMBOL + format, args);
    }
  }

  /**
   * Outputs fatal-level logs.
   *
   * @param tag Identifies the log tag.
   * @param format Indicates the log format string.
   * @param args Indicates the log parameters.
   * @since 7
   */
  static f(tag: string, format: string, ...args: Object[]) {
    if (Log.isLoggable(HiLog.LogLevel.FATAL)) {
      HiLog.fatal(DOMAIN, TAG, tag + SYMBOL + format, args);
    }
  }

  /**
   * Checks whether logs of the specified tag, and level can be printed.
   *
   * @param tag Identifies the log tag.
   * @param level log level
   * @since 7
   */
  private static isLoggable(level: HiLog.LogLevel): boolean {
    let buildModeName: string = BuildProfile.BUILD_MODE_NAME.toLowerCase();
    if (buildModeName == 'release' || buildModeName == 'profile') {
      return level >= Log._logLevel && HiLog.isLoggable(DOMAIN, TAG, level);
    }
    return HiLog.isLoggable(DOMAIN, TAG, level);
  }
}
