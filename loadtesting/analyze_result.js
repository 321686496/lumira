const fs = require('fs');
const readline = require('readline');

const FILE = process.argv[2] || 'load_test_result.json';

const byName = new Map();
const failedCounters = new Map();

function percentile(arr, p) {
  if (!arr.length) return 0;
  const sorted = [...arr].sort((a, b) => a - b);
  const idx = Math.ceil((p / 100) * sorted.length) - 1;
  return sorted[Math.min(idx, sorted.length - 1)];
}

async function main() {
  const rl = readline.createInterface({
    input: fs.createReadStream(FILE, { encoding: 'utf8' }),
    crlfDelay: Infinity,
  });

  for await (const line of rl) {
    const trimmed = line.trim();
    if (!trimmed) continue;
    let obj;
    try {
      obj = JSON.parse(trimmed);
    } catch {
      continue;
    }
    if (obj.type !== 'Point') continue;
    const { metric, data } = obj;
    const name = (data.tags && (data.tags.name || 'unknown')).replace(/\s*\(setup\)/, '');
    if (metric === 'http_req_duration') {
      if (!byName.has(name)) byName.set(name, []);
      byName.get(name).push(data.value);
    } else if (metric === 'http_req_failed') {
      const prev = failedCounters.get(name) || 0;
      failedCounters.set(name, prev + (data.value === 1 ? 1 : 0));
    }
  }

  const rows = [];
  for (const [name, vals] of byName) {
    const count = vals.length;
    const failed = failedCounters.get(name) || 0;
    const sum = vals.reduce((a, b) => a + b, 0);
    rows.push({
      name,
      count,
      failed,
      failRate: (failed / count) * 100,
      avg: sum / count,
      med: percentile(vals, 50),
      p90: percentile(vals, 90),
      p95: percentile(vals, 95),
      p99: percentile(vals, 99),
      max: Math.max(...vals),
    });
  }

  rows.sort((a, b) => b.p95 - a.p95);

  console.log(
    '接口'.padEnd(38) +
      '请求数'.padStart(7) +
      '失败'.padStart(6) +
      '失败率%'.padStart(9) +
      'avg(ms)'.padStart(10) +
      'med(ms)'.padStart(9) +
      'p90(ms)'.padStart(9) +
      'p95(ms)'.padStart(9) +
      'p99(ms)'.padStart(9) +
      'max(s)'.padStart(8),
  );
  console.log('-'.repeat(115));

  let total = 0;
  let totalFail = 0;
  for (const r of rows) {
    total += r.count;
    totalFail += r.failed;
    console.log(
      r.name.padEnd(38) +
        String(r.count).padStart(7) +
        String(r.failed).padStart(6) +
        r.failRate.toFixed(2).padStart(9) +
        r.avg.toFixed(1).padStart(10) +
        r.med.toFixed(1).padStart(9) +
        r.p90.toFixed(1).padStart(9) +
        r.p95.toFixed(1).padStart(9) +
        r.p99.toFixed(1).padStart(9) +
        (r.max / 1000).toFixed(2).padStart(8),
    );
  }
  console.log('-'.repeat(115));
  console.log(
    'TOTAL'.padEnd(38) +
      String(total).padStart(7) +
      String(totalFail).padStart(6) +
      ((totalFail / total) * 100).toFixed(2).padStart(9),
  );
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});