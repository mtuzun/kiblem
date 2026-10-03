const fs = require('fs');
const raw = fs.readFileSync(__dirname + '/hadis100u.txt', 'utf8');
const lines = raw.split(/\r?\n/);

const hasArabic = (s) => /[֐-ۿ‏‫ﭐ-﷿ﹰ-﻿]/.test(s);
const headRe = /^[\s:]*(\d+)\.\s*Hadis-i Şerif\s*$/;

const blocks = [];
let cur = null;
for (const line of lines) {
  const m = line.match(headRe);
  if (m) {
    cur = { n: parseInt(m[1], 10), lines: [] };
    blocks.push(cur);
  } else if (cur) {
    cur.lines.push(line);
  }
}

const out = [];
for (const b of blocks) {
  let ana = '', alt = '';
  const body = [];
  let srcParts = [];
  let inSrc = false;
  for (let raw of b.lines) {
    const line = raw.replace(/\f/g, '').trim();
    if (!line) continue;
    if (/^\d+$/.test(line)) continue;
    if (hasArabic(line)) continue;
    let m;
    if ((m = line.match(/^Ana Konu\s*:\s*(.*)$/))) { ana = m[1].trim(); continue; }
    if ((m = line.match(/^Alt Konu\s*:\s*(.*)$/))) { alt = m[1].trim(); continue; }
    if (inSrc) { srcParts.push(line); if (line.includes(')')) inSrc = false; continue; }
    if (/^\(.*\)$/.test(line)) { srcParts = [line]; continue; }
    if (/^\([A-Z]{1,3}\d+/.test(line)) {
      srcParts = [line];
      if (!line.includes(')')) inSrc = true;
      continue;
    }
    body.push(line);
  }
  let text = '';
  for (const l of body) {
    if (text.endsWith('-')) {
      text = text.slice(0, -1) + l;
    } else {
      text += (text ? ' ' : '') + l;
    }
  }
  text = text.replace('damlasıylabirlikte', 'damlasıyla- birlikte');
  text = text.replace(/\s*Din Hizmetleri Genel Müdürlüğü Cami Hizmetleri Daire Başkanlığı\s*$/, '').trim();
  ana = ana.trim();
  alt = alt.trim();
  let source = srcParts.join(' ').replace(/^\(/, '').replace(/\)$/, '');
  source = source.replace(/\b[A-Z]{1,3}\d+\s+/g, '').replace(/\s+/g, ' ').trim();
  out.push({ n: b.n, ana, alt, text, source });
}

fs.writeFileSync(__dirname + '/hadis100.json', JSON.stringify(out, null, 2), 'utf8');

const esc = (s) => s.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\$/g, '\\$');
const en = [...require('./hadis_en_part1.json'), ...require('./hadis_en_part2.json')];
const enBy = new Map(en.map((e) => [e.n, e]));
let dart = `class Hadith {
  final String text;
  final String source;
  final String topic;
  final String textEn;
  final String sourceEn;
  final String topicEn;

  const Hadith(this.text, this.source, this.topic, this.textEn, this.sourceEn, this.topicEn);
}

// Kaynak: T.C. Diyanet İşleri Başkanlığı, Din Hizmetleri Genel Müdürlüğü,
// "Hadis-i Şerif Metinleri" (2022).
const List<Hadith> hadiths = [
`;
for (const h of out) {
  const topic = h.alt ? `${h.ana} · ${h.alt}` : h.ana;
  const e = enBy.get(h.n);
  if (!e) throw new Error('missing en ' + h.n);
  dart += `  Hadith(\n    "${esc(h.text)}",\n    "${esc(h.source)}",\n    "${esc(topic)}",\n    "${esc(e.text)}",\n    "${esc(e.source)}",\n    "${esc(e.topic)}",\n  ),\n`;
}
dart += '];\n';
fs.writeFileSync(__dirname + '/hadith_data.dart', dart, 'utf8');

console.log('count', out.length);
const bad = out.filter((h) => !h.text || !h.source);
console.log('missing text/source:', bad.map((h) => h.n));
console.log(JSON.stringify(out[0], null, 1));
console.log(JSON.stringify(out[3], null, 1));
console.log(JSON.stringify(out[99], null, 1));
