const fs = require('fs');
const readline = require('readline');

async function main() {
  const file = process.argv[2] || 'load_test_result.json';
  const counts = new Map();
  const byEndpoint = new Map();
  let failedTotal = 0;
  let httpErrors = 0;

  const rl = readline.createInterface({ input: fs.createReadStream(file) });
  for await (const line of rl) {
    if (!line.startsWith('{')) continue;
    let obj;
    try { obj = JSON.parse(line); } catch { continue; }
    if (obj.type !== 'Point' || obj.metric !== 'http_req_failed') continue;
    if (obj.data.value !== 1) continue;
    failedTotal++;
    const errors = (obj.data.tags && obj.data.tags.error) ? obj.data.tags.error : 'NO_ERROR_TAG';
    const errorsCode = (obj.data.tags && obj.data.tags.error_code) ? obj.data.tags.error_code : 'NO_CODE_TAG';
    const httpStatus = (obj.data.tags && obj.data.tags.status) ? String(obj.data.tags.status) : '-';
    const code = Number(obj.data.tags && obj.data.tags.error_code);
    if (code && code >= 100 && code < 1000) httpErrors++;
    const name = (obj.data.tags && obj.data.tags.name) || 'unknown';
    const group = (obj.data.tags && obj.data.tags.group) || '';

    const key = code ? `HTTP ${code}` : errors;
    counts.set(key, (counts.get(key) || 0) + 1);

    const ek = `${name} | ${group} | ${errors || 'http:' + httpStatus}`;
    byEndpoint.set(ek, (byEndpoint.get(ek) || 0) + 1);
  }

  console.log('===== 错误类型分布 =====');
  for (const [k, v] of [...counts.entries()].sort((a, b) => b[1] - a[1])) {
    console.log(`${String(v).padStart(5)}  ${k}`);
  }
  console.log(`\n失败总数: ${failedTotal}  其中 HTTP 状态码型错误: ${httpErrors}`);

  console.log('\n===== 失败请求按接口分布 =====');
  for (const [k, v] of [...byEndpoint.entries()].sort((a, b) => b[1] - a[1])) {
    console.log(`${String(v).padStart(5)}  ${k}`);
  }
}

main();