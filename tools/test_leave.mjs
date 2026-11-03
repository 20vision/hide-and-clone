import { createRequire } from 'module';
const require=createRequire('/home/maslor/projects/p20v-bugs/');
const {chromium}=require('playwright-core');
const [base,ws,out]=process.argv.slice(2);
const args=['--use-gl=angle','--use-angle=swiftshader','--enable-webgl','--ignore-gpu-blocklist','--enable-unsafe-swiftshader','--disable-features=WebRtcHideLocalIpsWithMdns'];
const W=ms=>new Promise(r=>setTimeout(r,ms));const errs=[];const a=await chromium.launch({headless:true,executablePath:'/opt/google/chrome/chrome',args});const b=await chromium.launch({headless:true,executablePath:'/opt/google/chrome/chrome',args});
const h=await a.newPage({viewport:{width:1280,height:720}});const j=await b.newPage({viewport:{width:1280,height:720}});
for(const [p,k] of [[h,'h'],[j,'j']]){p.on('pageerror',e=>{errs.push(k+':'+e.message);console.log('PAGEERR',k,e.message)});p.on('console',m=>{if(m.type()==='error'&&!/t\.myclawn|Failed to load/.test(m.text()))console.log('ERR',k,m.text().slice(0,200))})}
const q=encodeURIComponent(ws);await h.goto(`${base}?auto=host&bots=1&ai=1&map=0&lobby=${q}`);await W(9000);
const {WebSocket}=require(process.cwd()+'/server/node_modules/ws');const code=await new Promise(res=>{const w=new WebSocket(ws);w.on('open',()=>w.send('{"t":"list"}'));w.on('message',d=>{const m=JSON.parse(d);w.close();res(m.list[0]&&m.list[0].code)})});
await j.goto(`${base}?auto=code&code=${code}&ai=1&lobby=${q}`);await W(10000);await j.screenshot({path:out+'/leave_0.png'});
// client presses LEAVE GAME on panel, is back at menu, rejoins, then the host leaves
await j.mouse.click(1060,460);await W(2500);await j.screenshot({path:out+'/leave_1.png'});
await j.goto(`${base}?auto=code&code=${code}&ai=1&lobby=${q}`);await W(10000);
await a.close();await W(26000);await j.screenshot({path:out+'/leave_2.png'});
await j.mouse.click(290,420);await W(1200);await j.screenshot({path:out+'/leave_3.png'});
console.log('page errors',errs.length);await b.close();
