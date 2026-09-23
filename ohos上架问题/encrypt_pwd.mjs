import fs from 'fs';
import path from 'path';
import crypto from 'crypto';

// ---------------------------------------------------------------------------
// Mirror of DevEco hvigor DecipherUtil (decipher-util.js) — exact same logic.
// Material dir structure: <materialDir>/material/{fd/*/file, ac/file, ce/file}
// ---------------------------------------------------------------------------
const component = new Int8Array([49,243,9,115,214,175,91,184,211,190,177,88,101,131,192,119]);

function readDirBytes(dir){
  // readDirBytes: dir contains exactly 1 file, return its bytes as Int8Array
  if(!fs.existsSync(dir) || !fs.statSync(dir).isDirectory()) throw new Error('not a dir: '+dir);
  const entries = fs.readdirSync(dir);
  if(entries.length!==1) throw new Error('expect 1 file in '+dir+', got '+entries.length);
  const b = fs.readFileSync(path.resolve(dir, entries[0]));
  return new Int8Array(b);
}

// readFd: dir contains exactly 3 subdirs (each with 1 file) -> array of 3 Int8Arrays
function readFd(t){
  const subs = fs.readdirSync(t);
  if(subs.length!==3) throw new Error('fd expect 3 subdirs, got '+subs.length);
  return subs.map(it => readDirBytes(path.resolve(t, it)));
}

function xor(t, r){
  if(t.byteLength!==r.byteLength) throw new Error('xor len: '+t.byteLength+' vs '+r.byteLength);
  const o = new Int8Array(t.byteLength);
  for(let i=0;i<t.byteLength;i++) o[i]=t[i]^r[i];
  return o;
}

// xorComponents: all elements must be 16 bytes; xor them together
function xorComponents(parts){
  parts.forEach(p => { if(p.length!==16) throw new Error('component len!=16: '+p.length); });
  let e = xor(parts[0], parts[1]);
  for(let i=2;i<parts.length;i++) e = xor(e, parts[i]);
  return Buffer.from(e);
}

// DecipherUtil.getKey
function getKey(materialDir){
  const e = path.resolve(materialDir, 'material');
  if(!fs.statSync(e).isDirectory()) throw new Error('not a dir: '+e);
  const fdArr = readFd(path.resolve(e, 'fd'));
  const ac    = readDirBytes(path.resolve(e, 'ac'));
  const ce    = readDirBytes(path.resolve(e, 'ce'));
  // getRootKey: fd.concat(component) -> 4 parts (each 16B) xor together
  const concat = fdArr.concat(component); // array of 4 Int8Arrays, 16 bytes each
  const s = xorComponents(concat);        // Buffer(16)
  const rootKey = crypto.pbkdf2Sync(s.toString(), Buffer.from(ac), 1e4, 16, 'sha256');
  // key = decrypt(rootKey, ce)
  return decrypt(new Int8Array([...rootKey]), ce);
}

// DecipherUtil.decrypt : format = [4-byte BE e=ctLen+16][iv((total-4-e) bytes)][ct][16-byte tag]
function decrypt(keyBytes, r){
  const e = (255&r[0])<<24 | (255&r[1])<<16 | (255&r[2])<<8 | (255&r[3]);
  const ivLen = r.length - 4 - e;
  const iv = Buffer.from(r.slice(4, 4+ivLen));
  const tag = Buffer.from(r.slice(r.length-16));
  const ct = Buffer.from(r.subarray(4+ivLen, r.length-16));
  const d = crypto.createDecipheriv('aes-128-gcm', Buffer.from(keyBytes), iv);
  d.setAuthTag(tag);
  return Buffer.concat([d.update(ct), d.final()]);
}

// Encrypt a utf8 string -> obfuscated hex (mirror of decrypt format)
function encryptString(keyBytes, str){
  const plain = Buffer.from(str, 'utf8');
  const iv = crypto.randomBytes(12);
  const c = crypto.createCipheriv('aes-128-gcm', Buffer.from(keyBytes), iv);
  const ct = Buffer.concat([c.update(plain), c.final()]);
  const tag = c.getAuthTag();
  const head = Buffer.alloc(4);
  head.writeUInt32BE(ct.length + 16);
  return Buffer.concat([head, iv, ct, tag]).toString('hex');
}

const materialDir = 'd:/app/projects/photo_post/packagefile/harmony';
const key = getKey(materialDir);
console.log('KEY(hex)        =', Buffer.from(key).toString('hex'));

// --- Verify by decrypting DevEco's existing debug passwords (should be public123) ---
const debugStorePwd = '00000019704B88809C3F9AC23A67C5DA9FEB5A9B61E6002DF6FCFE3FABD86B23E16FB0437D31645666';
const debugKeyPwd   = '00000019CB68298EFDE55FB88294DAAAF0992B17791F01D8E1132A4C04AE7A15328F3213047D00A188';
const deStore = decrypt(key, new Int8Array([...Buffer.from(debugStorePwd,'hex')]));
const deKey   = decrypt(key, new Int8Array([...Buffer.from(debugKeyPwd,'hex')]));
console.log('decrypt debug storePwd =', JSON.stringify(deStore.toString('utf8')));
console.log('decrypt debug keyPwd   =', JSON.stringify(deKey.toString('utf8')));

// --- Generate obfuscated passwords for release "public123" ---
console.log('enc storePassword     =', encryptString(key, 'public123'));
console.log('enc keyPassword       =', encryptString(key, 'public123'));