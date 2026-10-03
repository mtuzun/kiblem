// Usage: node apply_patch.js <target> <patchfile>
// Patch format: blocks of  <<<<\nold\n====\nnew\n>>>>
const fs = require('fs');
const [target, patchFile] = process.argv.slice(2);
let s = fs.readFileSync(target, 'utf8');
const crlf = s.includes('\r\n');
s = s.replace(/\r\n/g, '\n');
const patch = fs.readFileSync(patchFile, 'utf8').replace(/\r\n/g, '\n');
const re = /<<<<\n([\s\S]*?)\n====\n([\s\S]*?)\n>>>>/g;
let m, n = 0, fail = 0;
while ((m = re.exec(patch))) {
  const [, a, b] = m;
  const count = s.split(a).length - 1;
  if (count !== 1) {
    console.error(count === 0 ? 'MISSING:' : 'AMBIGUOUS(' + count + '):', a.slice(0, 90).replace(/\n/g, '⏎'));
    fail++;
    continue;
  }
  s = s.replace(a, () => b);
  n++;
}
if (fail) { console.error('aborted, nothing written'); process.exit(1); }
fs.writeFileSync(target, crlf ? s.replace(/\n/g, '\r\n') : s);
console.log('applied', n);
