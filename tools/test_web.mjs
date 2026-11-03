// End-to-end: real browsers, real WebRTC, real rounds. Usage: node tools/test_web.mjs <baseurl> <ws> <outdir>
import { createRequire } from 'module';
const require=createRequire('/home/maslor/projects/p20v-bugs/');
const {chromium}=require('playwright-core');
const [base,ws,out]=process.argv.slice(2);
const args=['--use-gl=angle','--use-angle=swiftshader','--enable-webgl','--ignore-gpu-blocklist','--enable-unsafe-swiftshader','--disable-features=WebRtcHideLocalIpsWithMdns'];
const launch=()=>chromium.launch({headless:true,executablePath:'/opt/google/chrome/chrome',args});
const logs={host:[],join:[]};let fails=[];
function watch(p,k){p.on('console',m=>{const t=m.text();logs[k].push(t);if(/\[hc\]/.test(t))console.log(k,t);if(m.type()==='error'&&!/t\.myclawn|Failed to load resource/.test(t)){fails.push(k+': '+t);console.log('ERR',k,t.slice(0,300));}});p.on('pageerror',e=>{fails.push(k+': '+e.message);console.log('PAGEERR',k,e.message)});}
const until=async(k,re,ms)=>{const t=Date.now();while(Date.now()-t<ms){if(logs[k].some(l=>re.test(l)))return true;await new Promise(r=>setTimeout(r,500));}return false};
const a=await launch();const b=await launch();
const hp=await a.newPage({viewport:{width:1280,height:720}});watch(hp,'host');
await hp.goto(`${base}?auto=host&bots=3&ai=1&map=${process.env.MAP||0}&lobby=${encodeURIComponent(ws)}`);
const r={};
r.host_world=await until('host',/world ready/,120000);
await hp.screenshot({path:out+'/host_lobby.png'});
// find the code through the lobby service, like a real player
const {WebSocket}=require('/home/maslor/projects/hide-and-clone/server/node_modules/ws');
const code=await new Promise((res,rej)=>{const w=new WebSocket(ws);w.on('open',()=>w.send('{"t":"list"}'));w.on('message',d=>{const m=JSON.parse(d);w.close();res(m.list[0]&&m.list[0].code)});setTimeout(()=>rej(new Error('list timeout')),8000)});
console.log('code',code);r.listed=!!code;
const jp=await b.newPage({viewport:{width:1280,height:720}});watch(jp,'join');
await jp.goto(`${base}?auto=code&code=${code}&ai=1&lobby=${encodeURIComponent(ws)}`);
r.join_world=await until('join',/world ready/,120000);
await new Promise(r=>setTimeout(r,4000));
await jp.screenshot({path:out+'/join_lobby.png'});
await hp.evaluate(()=>0);
console.log('asking host to start');
// click START ROUND button on the host panel (mouse is free in the lobby)
await hp.mouse.click(300,650);await new Promise(r=>setTimeout(r,500));await hp.keyboard.press("Enter");await new Promise(r=>setTimeout(r,500));
await hp.screenshot({path:out+'/host_click.png'});
r.round=await until('host',/round 1 start/,8000);
if(r.round){await new Promise(r=>setTimeout(r,1500));await jp.screenshot({path:out+'/hide_join.png'});await hp.screenshot({path:out+'/hide_host.png'});
 r.seek=await until('host',/seek phase/,20000);await new Promise(r=>setTimeout(r,6000));await hp.screenshot({path:out+'/seek_host.png'});await jp.screenshot({path:out+'/seek_join.png'});
 r.over=await until('host',/round over/,70000);await new Promise(r=>setTimeout(r,800));await jp.screenshot({path:out+'/end_join.png'});await hp.screenshot({path:out+'/end_host.png'});}
console.log(JSON.stringify(r),'fails',fails.length);console.log(fails.slice(0,10).join('\n'));
await a.close();await b.close();
