// Native export <-> web build over the lobby with real WebRTC. Usage: DISPLAY=:77 node tools/test_native.mjs <exe> <baseurl> <ws> <outdir> [host|join]
import { createRequire } from 'module';
import { spawn } from 'child_process';
const require=createRequire('/home/maslor/projects/p20v-bugs/');
const {chromium}=require('playwright-core');
const {WebSocket}=require('/home/maslor/projects/hide-and-clone/server/node_modules/ws');
const [exe,base,ws,out,mode='host']=process.argv.slice(2);
const W=ms=>new Promise(r=>setTimeout(r,ms));
const args=['--use-gl=angle','--use-angle=swiftshader','--enable-webgl','--ignore-gpu-blocklist','--enable-unsafe-swiftshader','--disable-features=WebRtcHideLocalIpsWithMdns'];
const logs={native:[],web:[]};
const until=async(k,re,ms)=>{const t=Date.now();while(Date.now()-t<ms){if(logs[k].some(l=>re.test(l)))return true;await W(400)}return false};
const list=()=>new Promise((res,rej)=>{const w=new WebSocket(ws);w.on('open',()=>w.send('{"t":"list"}'));w.on('message',d=>{const m=JSON.parse(d);w.close();res(m.list[0]&&m.list[0].code)});setTimeout(()=>rej(new Error('list timeout')),8000)});
const native=extra=>{const p=spawn('stdbuf',['-oL',exe,'--',`--lobby=${ws}`,...extra],{env:{...process.env,HC_NO_TRACK:'1'}});const f=d=>{for(const l of String(d).split('\n')){if(!l.trim())continue;logs.native.push(l);if(/\[hc\]|ERROR/.test(l))console.log('native',l.slice(0,200))}};p.stdout.on('data',f);p.stderr.on('data',f);return p};
const br=await chromium.launch({headless:true,executablePath:'/opt/google/chrome/chrome',args});
const pg=await br.newPage({viewport:{width:1280,height:720}});
pg.on('console',m=>{const t=m.text();logs.web.push(t);if(/\[hc\]/.test(t))console.log('web',t.slice(0,200))});
const r={};let n;
const seq=async(hostK,joinK)=>{r.host_world=await until(hostK,/world ready/,120000);const code=await list();r.code=code;console.log('code',code);return code};
if(mode==='host'){
 n=native(['--auto=host','--bots=2','--ai=1','--start=auto','--hide=4','--map=0']);
 const code=await seq('native','web');
 await pg.goto(`${base}?auto=code&code=${code}&ai=1&lobby=${encodeURIComponent(ws)}`);
 r.join_world=await until('web',/world ready/,120000);
 r.round=await until('native',/round \d+ start players=[2-9]/,60000);
}else{
 await pg.goto(`${base}?auto=host&bots=2&ai=1&start=auto&hide=4&map=0&lobby=${encodeURIComponent(ws)}`);
 const code=await seq('web','native');
 n=native(['--auto=code',`--code=${code}`,'--ai=1']);
 r.join_world=await until('native',/world ready/,120000);
 r.round=await until('web',/round \d+ start players=[2-9]/,60000);
}
await pg.screenshot({path:`${out}/${mode}_web.png`});
await W(9000);await pg.screenshot({path:`${out}/${mode}_web2.png`});
console.log(JSON.stringify(r),'native errors',logs.native.filter(l=>/ERROR|SCRIPT/.test(l)).length);
n.kill();await br.close();process.exit(0);
