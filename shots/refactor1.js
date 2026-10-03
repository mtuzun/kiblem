const fs = require('fs');
const p = 'lib/main.dart';
let s = fs.readFileSync(p, 'utf8');
const crlf = s.includes('\r\n'); s = s.replace(/\r\n/g, '\n');
function cut(startMarker, endMarker, replacement) {
  const a = s.indexOf(startMarker), b = s.indexOf(endMarker);
  if (a < 0 || b < 0 || b < a) { console.error('marker problem', startMarker.slice(0, 40)); process.exit(1); }
  s = s.slice(0, a) + replacement + s.slice(b);
}
// 1) açılır öneri penceresini kaldır
cut('  // Uygulamayı kurduktan sonraki ilk turdan sonra, internet varken bir kez önerir.', '  /// Ayet kartındaki "çevrimdışı için indir" düğmesi', '');
// 2) eski metin düğmesini simge düğmesiyle değiştir
cut('  /// Ayet kartındaki "çevrimdışı için indir" düğmesi', '  Widget _buildOfflineTile() {', fs.readFileSync('shots/new_icon.txt', 'utf8') + '\n');
fs.writeFileSync(p, crlf ? s.replace(/\n/g, '\r\n') : s);
console.log('ok');
