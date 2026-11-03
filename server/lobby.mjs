// Tiny lobby + WebRTC signalling service. Gameplay traffic never touches it.
import { WebSocketServer } from 'ws';
const PORT=+process.env.PORT||8790, MAX_ROOMS=500, MAX_MSG=16384;
const wss=new WebSocketServer({port:PORT,host:'127.0.0.1',maxPayload:MAX_MSG});
const rooms=new Map(); // code -> {host,peers:Map,info,nextId}
const ABC='ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const send=(ws,o)=>{if(ws.readyState===1)ws.send(JSON.stringify(o))};
const clean=(s,n)=>String(s??'').replace(/[\u0000-\u001f<>]/g,'').slice(0,n);
function newCode(){for(;;){let c='';for(let i=0;i<5;i++)c+=ABC[Math.random()*ABC.length|0];if(!rooms.has(c))return c;}}
function list(){return [...rooms.entries()].filter(([,r])=>r.info.public).slice(0,100).map(([code,r])=>({code,...r.info}))}
function info(m){const num=(v,d,a,b)=>{const x=Number(v);return Number.isFinite(x)?Math.min(b,Math.max(a,x|0)):d};
 return {name:clean(m.name,40),map:clean(m.map,40),players:num(m.players,1,0,64),max:num(m.max,12,2,64),phase:clean(m.phase,10),public:!!m.public,v:num(m.v,1,0,9999)}}
wss.on('connection',ws=>{if(wss.clients.size>3000){ws.close();return}ws.isAlive=true;ws.on('pong',()=>ws.isAlive=true);let count=0;const t0=setInterval(()=>count=0,1000);
 ws.on('close',()=>{clearInterval(t0);
  if(ws.room&&ws.pid===1){const r=rooms.get(ws.room);if(r){for(const p of r.peers.values()){send(p,{t:'host_left'});p.close();}rooms.delete(ws.room);}}
  else if(ws.room){const r=rooms.get(ws.room);if(r){r.peers.delete(ws.pid);send(r.host,{t:'peer_left',id:ws.pid});}}});
 ws.on('message',raw=>{if(++count>120){ws.close();return;}let m;try{m=JSON.parse(raw)}catch{return}
  if(m.t==='ping'){send(ws,{t:'pong'});return}
  if(m.t==='list'){send(ws,{t:'lobbies',list:list()});return}
  if(m.t==='host'&&!ws.room){if(rooms.size>=MAX_ROOMS){send(ws,{t:'error',msg:'full'});return}
   const code=newCode();rooms.set(code,{host:ws,peers:new Map(),info:info(m),nextId:2});ws.room=code;ws.pid=1;send(ws,{t:'hosted',code});return}
  if(m.t==='update'&&ws.pid===1){const r=rooms.get(ws.room);if(r)r.info=info(m);return}
  if(m.t==='join'&&!ws.room){const code=clean(m.code,5).toUpperCase(),r=rooms.get(code);
   if(!r){send(ws,{t:'error',msg:'not_found'});return}
   if(r.peers.size+1>=r.info.max){send(ws,{t:'error',msg:'full'});return}
   const id=r.nextId++;ws.room=code;ws.pid=id;r.peers.set(id,ws);send(ws,{t:'joined',id,code});send(r.host,{t:'peer',id});return}
  if((m.t==='sdp'||m.t==='ice')&&ws.room){const r=rooms.get(ws.room);if(!r)return;
   const to=ws.pid===1?r.peers.get(+m.to):r.host;if(!to)return;
   const o={t:m.t,from:ws.pid};if(m.t==='sdp'){o.type=clean(m.type,10);o.sdp=String(m.sdp??'').slice(0,12000)}else{o.mid=clean(m.mid,20);o.idx=+m.idx||0;o.cand=String(m.cand??'').slice(0,1000)}
   send(to,o);return}
 });});
setInterval(()=>{for(const w of wss.clients){if(!w.isAlive){w.terminate();continue}w.isAlive=false;w.ping()}},30000);
console.log('lobby on',PORT);
