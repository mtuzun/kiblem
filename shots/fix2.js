const fs = require('fs');
const p = 'lib/main.dart';
let s = fs.readFileSync(p, 'utf8');
const crlf = s.includes('\r\n'); s = s.replace(/\r\n/g, '\n');
function rep(a, b) {
  const n = s.split(a).length - 1;
  if (n !== 1) { console.error('count', n, a.slice(0, 60)); process.exit(1); }
  s = s.replace(a, () => b);
}
// bozuk artıkları temizle
rep("    _loadAzanReminderSetting();\n>>>>\n<<<<\n            _buildOfflineDownloadButton(onDark: true),\n====\n            _buildOfflineDownloadIcon(onDark: true),\n  }\n", "    _loadAzanReminderSetting();\n  }\n");
// kalan yamalar
rep("            _buildOfflineDownloadButton(onDark: true),\n          ],\n        ),\n      );", "            _buildOfflineDownloadIcon(onDark: true),\n          ],\n        ),\n      );");
fs.writeFileSync(p, crlf ? s.replace(/\n/g, '\r\n') : s);
console.log('ok');
