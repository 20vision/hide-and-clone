// Embeds external textures into each CC0 GLB and writes the catalog the game loads.
import fs from 'fs';import path from 'path';
const SRC=process.argv[2],OUT=process.argv[3];
const SKIP=new Set(['blocky-characters','brick-kit','blaster-kit','mini-characters']);
const SCALE={'furniture-kit':2.4,'nature-kit':2,'food-kit':2,'city-kit-commercial':3,'city-kit-industrial':3,'city-kit-suburban':3,'city-kit-roads':3,'building-kit':2,'modular-buildings':3,'castle-kit':3,'graveyard-kit':2,'survival-kit':3,'fantasy-town-kit':3,'factory-kit':2,'holiday-kit':2,'mini-arcade':2,'mini-arena':2,'mini-dungeon':3,'mini-forest':2,'mini-market':2,'mini-skate':2,'retro-urban-kit':3,'retro-fantasy-kit':3,'platformer-kit':2,'prototype-kit':2,'space-kit':2,'space-station-kit':3,'hexagon-kit':2,'minigolf-kit':2,'tower-defense-kit':2,'car-kit':1.4,'racing-kit':2,'cube-pets':1,'marble-kit':1};
function align(n){return (n+3)&~3}
function embed(file){const b=fs.readFileSync(file);const jl=b.readUInt32LE(12);const j=JSON.parse(b.slice(20,20+jl));
 let bin=Buffer.alloc(0);const off=20+jl;if(off<b.length){const bl=b.readUInt32LE(off);bin=b.slice(off+8,off+8+bl);}
 let missing=0;
 for(const im of j.images||[]){if(!im.uri||im.uri.startsWith('data:'))continue;
  const p=path.join(path.dirname(file),decodeURI(im.uri));
  if(!fs.existsSync(p)){missing++;delete im.uri;continue;}
  const d=fs.readFileSync(p);const start=align(bin.length);
  bin=Buffer.concat([bin,Buffer.alloc(start-bin.length),d]);
  j.bufferViews=j.bufferViews||[];j.bufferViews.push({buffer:0,byteOffset:start,byteLength:d.length});
  im.bufferView=j.bufferViews.length-1;im.mimeType=p.endsWith('.jpg')?'image/jpeg':'image/png';delete im.uri;}
 if(missing){return null;}
 if(j.buffers&&j.buffers[0])j.buffers[0].byteLength=bin.length;
 const js=Buffer.from(JSON.stringify(j));const jp=Buffer.concat([js,Buffer.alloc(align(js.length)-js.length,0x20)]);
 const bp=Buffer.concat([bin,Buffer.alloc(align(bin.length)-bin.length)]);
 const h=Buffer.alloc(12);h.writeUInt32LE(0x46546C67,0);h.writeUInt32LE(2,4);h.writeUInt32LE(12+8+jp.length+8+bp.length,8);
 const c1=Buffer.alloc(8);c1.writeUInt32LE(jp.length,0);c1.writeUInt32LE(0x4E4F534A,4);
 const c2=Buffer.alloc(8);c2.writeUInt32LE(bp.length,0);c2.writeUInt32LE(0x004E4942,4);
 return Buffer.concat([h,c1,jp,c2,bp]);}
const cat={};let n=0,bytes=0,bad=0;
for(const k of fs.readdirSync(SRC)){if(SKIP.has(k))continue;const names=[];const seen=new Set();
 (function w(d){for(const e of fs.readdirSync(d,{withFileTypes:true})){const p=path.join(d,e.name);if(e.isDirectory())w(p);else if(e.name.endsWith('.glb')){const nm=e.name.slice(0,-4).replace(/[^A-Za-z0-9_-]/g,'_');if(seen.has(nm))continue;const o=embed(p);if(!o){bad++;continue;}seen.add(nm);fs.mkdirSync(path.join(OUT,'a',k),{recursive:true});fs.writeFileSync(path.join(OUT,'a',k,nm+'.glb'),o);names.push(nm);n++;bytes+=o.length;}}})(path.join(SRC,k));
 if(names.length)cat[k]={s:SCALE[k]||1,n:names.sort()};}
fs.writeFileSync(process.argv[4],JSON.stringify(cat));console.log({models:n,MB:(bytes/1e6).toFixed(0),bad,packs:Object.keys(cat).length});
