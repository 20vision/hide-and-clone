// Plays through menus, builder, keyboard and player list like a person would.
import { createRequire } from 'module';
const require=createRequire('/home/maslor/projects/p20v-bugs/');
const {chromium}=require('playwright-core');
const [base,ws,out]=process.argv.slice(2);
const args=['--use-gl=angle','--use-angle=swiftshader','--enable-webgl','--ignore-gpu-blocklist','--enable-unsafe-swiftshader'];
const br=await chromium.launch({headless:true,executablePath:'/opt/google/chrome/chrome',args});
const p=await br.newPage({viewport:{width:1280,height:720}});const errs=[];const lg=[];
p.on('console',m=>{const t=m.text();lg.push(t);if(m.type()==='error'&&!/t\.myclawn|Failed to load resource/.test(t)){errs.push(t);console.log('ERR',t.slice(0,250))}if(/\[hc\]/.test(t))console.log(t)});p.on('pageerror',e=>{errs.push(e.message);console.log('PAGEERR',e.message)});
const W=ms=>new Promise(r=>setTimeout(r,ms));const S=n=>p.screenshot({path:`${out}/${n}.png`});
await p.goto(`${base}?lobby=${encodeURIComponent(ws)}`);await W(9000);await S('ui_home');
const f=process.env.FLOW||'home';
const clickAt=async(x,y,w=900)=>{await p.mouse.click(x,y);await W(w)};
await eval(`(async()=>{${process.env.STEPS||''}})()`);
console.log('errors',errs.length);await br.close();
