// Live site, live lobby: find the game in the list, join by invite link, map lands in history, host leaves.
import { createRequire } from 'module';
const require=createRequire('/home/maslor/projects/p20v-bugs/');
const {chromium}=require('playwright-core');
const [base,out]=process.argv.slice(2);
const args=['--use-gl=angle','--use-angle=swiftshader','--enable-webgl','--ignore-gpu-blocklist','--enable-unsafe-swiftshader','--disable-features=WebRtcHideLocalIpsWithMdns'];
const launch=()=>chromium.launch({headless:true,executablePath:'/opt/google/chrome/chrome',args});
const W=ms=>new Promise(r=>setTimeout(r,ms));const errs=[];const logs={h:[],j:[],k:[]};
const page=async(b,k)=>{const p=await b.newPage({viewport:{width:1280,height:720}});p.on('console',m=>{const t=m.text();logs[k].push(t);if(/\[hc\]/.test(t)&&!/pos /.test(t))console.log(k,t);if(m.type()==='error'&&!/t\.myclawn|Failed to load resource/.test(t)){errs.push(k+':'+t);console.log('ERR',k,t.slice(0,250))}});p.on('pageerror',e=>{errs.push(k+':'+e.message);console.log('PAGEERR',k,e.message)});return p};
const until=async(k,re,ms)=>{const t=Date.now();while(Date.now()-t<ms){if(logs[k].some(l=>re.test(l)))return true;await W(400)}return false};
const a=await launch(),b=await launch(),c=await launch();
const t0=Date.now();const h=await page(a,'h');await h.goto(base+'?auto=host&bots=2&ai=1&hide=3&map=3');const r={};r.t='';
r.host=await until('h',/world ready/,120000);console.log('host load s',(Date.now()-t0)/1000);
// third player browses the public list, like a stranger
const k=await page(c,'k');await k.goto(base);await W(25000);await k.mouse.click(280,372);await W(3500);await k.screenshot({path:out+'/live_public_list.png'});console.log('list shot');
await k.mouse.click(965,172);await W(300);
// click JOIN on first row
r.stranger=await until('k',/world ready/,60000);await k.screenshot({path:out+'/live_stranger.png'});
// friend comes in through the invite link
const code=await (async()=>{const {WebSocket}=require(process.cwd()+'/server/node_modules/ws');return new Promise(res=>{const w=new WebSocket('wss://lobby.desk.myclawn.com');w.on('open',()=>w.send('{"t":"list"}'));w.on('message',d=>{const m=JSON.parse(d);w.close();res(m.list[0]&&m.list[0].code)})})})();console.log('code',code);
const j=await page(b,'j');await j.goto(base+'?join='+code);r.friend=await until('j',/world ready/,90000);await W(2500);await j.screenshot({path:out+'/live_friend.png'});
await h.screenshot({path:out+"/live_host_panel.png"});await h.mouse.click(300,650);await W(500);await h.keyboard.press("Enter");r.round=await until('h',/round 1 start/,8000);r.seek=await until('h',/seek phase/,15000);await W(3000);await j.screenshot({path:out+'/live_friend_seek.png'});await k.keyboard.down('Tab');await W(500);await k.screenshot({path:out+'/live_tab.png'});await k.keyboard.up('Tab');
r.over=await until('h',/round over/,70000);await W(4000);
// host leaves: others must land back at the menu, and the map stays in their history
await a.close();await W(5000);await j.screenshot({path:out+'/live_host_left.png'});
await j.goto(base);await W(22000);await j.mouse.click(280,443);await W(1000);await j.mouse.click(562,147);await W(800);await j.screenshot({path:out+'/live_history.png'});
console.log(JSON.stringify(r),'errors',errs.length);await b.close();await c.close();
