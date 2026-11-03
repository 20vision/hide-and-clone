// Models the robot clone as six solid parts (head, torso, arms, legs) with soft baked shadows.
// usage: node bake_robot.mjs <cell size> <output file>
import fs from 'fs';
const CELL=+process.argv[2]||0.02,OUT=process.argv[3]||'robot.bin';
const clamp=(x,a,b)=>Math.min(b,Math.max(a,x)),ss=(a,b,x)=>{const t=clamp((x-a)/(b-a),0,1);return t*t*(3-2*t)};
const smin=(a,b,k)=>{const h=Math.max(k-Math.abs(a-b),0)/k;return Math.min(a,b)-h*h*k*0.25};
const sub=(a,b)=>[a[0]-b[0],a[1]-b[1],a[2]-b[2]],dot=(a,b)=>a[0]*b[0]+a[1]*b[1]+a[2]*b[2],len=a=>Math.hypot(a[0],a[1],a[2]);
function cone(p,a,b,r1,r2){const ba=sub(b,a),pa=sub(p,a);const t=clamp(dot(pa,ba)/dot(ba,ba),0,1);return len([pa[0]-ba[0]*t,pa[1]-ba[1]*t,pa[2]-ba[2]*t])-(r1+(r2-r1)*t)}
function sup(p,c,r,n){const q=sub(p,c);const v=Math.pow(Math.pow(Math.abs(q[0]/r[0]),n)+Math.pow(Math.abs(q[1]/r[1]),n)+Math.pow(Math.abs(q[2]/r[2]),n),1/n);return (v-1)*Math.min(r[0],r[1],r[2])}
const HC=[0,1.34,0];
function ear(p,s){const x=p[0]*s-0.56,r=Math.hypot(p[1]-1.33,p[2]);const a=r-0.165,b=Math.abs(x)-0.052;return Math.min(Math.max(a,b),0)+Math.hypot(Math.max(a,0),Math.max(b,0))-0.042}
function head(p){let d=sup(p,HC,[0.565,0.43,0.47],2.7);
 const q=sub(p,HC);if(q[2]<0){const r=Math.pow(Math.pow(Math.abs(q[0]/0.425),3)+Math.pow(Math.abs((q[1]+0.012)/0.3),3),1/3);d+=0.012*ss(1.14,0.92,r)}
 d=smin(d,ear(p,1),0.03);d=smin(d,ear(p,-1),0.03);return d}
function torso(p){const q=[p[0],p[1],p[2]/0.86];let d=cone(q,[0,0.58,0],[0,0.69,0],0.345,0.285);
 d=smin(d,cone(p,[0,0.92,0],[0,0.95,0],0.14,0.13),0.02);
 d=smin(d,sup(p,[0,0.385,0],[0.24,0.085,0.2],2.3),0.02);return d}
function arm(p,s){const q=[p[0]*s,p[1],p[2]];const S=[0.36,0.86,0],E=[0.52,0.62,-0.01];let d=cone(q,S,E,0.13,0.112);
 const ba=sub(E,S),t=clamp(dot(sub(q,S),ba)/dot(ba,ba),0,1);d+=0.012*ss(0.5,0.56,t)*ss(0.82,0.76,t);
 d=smin(d,sup(q,[0.585,0.5,-0.025],[0.175,0.185,0.175],2.2),0.025);return d}
function leg(p,s){const q=[p[0]*s,p[1],p[2]];let d=cone(q,[0.175,0.4,0],[0.195,0.22,0],0.165,0.145);
 const groove=ss(0.275,0.285,q[1])*ss(0.33,0.32,q[1]);d+=0.012*groove;
 const foot=Math.max(sup(q,[0.205,0.105,-0.08],[0.205,0.115,0.29],2.3),-q[1]);return smin(d,foot,0.04)}
const PARTS=[['head',head,[-0.74,0.82,-0.56],[0.74,1.84,0.56],[0,0.98,0]],['torso',torso,[-0.46,0.25,-0.38],[0.46,1.12,0.38],[0,0.48,0]],
['armL',p=>arm(p,-1),[-0.84,0.26,-0.28],[-0.18,1.04,0.24],[-0.36,0.86,0]],['armR',p=>arm(p,1),[0.18,0.26,-0.28],[0.84,1.04,0.24],[0.36,0.86,0]],
['legL',p=>leg(p,-1),[-0.5,-0.03,-0.44],[0.0,0.6,0.28],[-0.175,0.4,0]],['legR',p=>leg(p,1),[0.0,-0.03,-0.44],[0.5,0.6,0.28],[0.175,0.4,0]]];
const all=p=>Math.min(head(p),torso(p),arm(p,1),arm(p,-1),leg(p,1),leg(p,-1));
const buffers=[];const head32=Buffer.alloc(4);head32.writeUInt32LE(PARTS.length,0);buffers.push(head32);let tot=0;
for(const [name,f,mn,mx,piv] of PARTS){
 const NX=Math.ceil((mx[0]-mn[0])/CELL),NY=Math.ceil((mx[1]-mn[1])/CELL),NZ=Math.ceil((mx[2]-mn[2])/CELL);const id=(x,y,z)=>x+(NX+1)*(y+(NY+1)*z);
 const F=new Float32Array((NX+1)*(NY+1)*(NZ+1));for(let z=0;z<=NZ;z++)for(let y=0;y<=NY;y++)for(let x=0;x<=NX;x++)F[id(x,y,z)]=f([mn[0]+x*CELL,mn[1]+y*CELL,mn[2]+z*CELL]);
 const vid=new Int32Array(F.length).fill(-1),P=[];const C=[[0,0,0],[1,0,0],[0,1,0],[1,1,0],[0,0,1],[1,0,1],[0,1,1],[1,1,1]],E=[[0,1],[2,3],[4,5],[6,7],[0,2],[1,3],[4,6],[5,7],[0,4],[1,5],[2,6],[3,7]];
 for(let z=0;z<NZ;z++)for(let y=0;y<NY;y++)for(let x=0;x<NX;x++){const v=C.map(c=>F[id(x+c[0],y+c[1],z+c[2])]);let s=[0,0,0],n=0;for(const[a,b]of E)if((v[a]<0)!==(v[b]<0)){const t=v[a]/(v[a]-v[b]);for(let i=0;i<3;i++)s[i]+=C[a][i]+(C[b][i]-C[a][i])*t;n++}if(!n)continue;vid[id(x,y,z)]=P.length/3;P.push(mn[0]+(x+s[0]/n)*CELL,mn[1]+(y+s[1]/n)*CELL,mn[2]+(z+s[2]/n)*CELL)}
 const I=[];const quad=(a,b,c,d,fl)=>{if(a<0||b<0||c<0||d<0)return;if(fl)I.push(a,c,b,a,d,c);else I.push(a,b,c,a,c,d)};
 for(let z=1;z<NZ;z++)for(let y=1;y<NY;y++)for(let x=1;x<NX;x++){const f0=F[id(x,y,z)]<0;
  if(f0!==(F[id(x+1,y,z)]<0))quad(vid[id(x,y-1,z-1)],vid[id(x,y,z-1)],vid[id(x,y,z)],vid[id(x,y-1,z)],f0);
  if(f0!==(F[id(x,y+1,z)]<0))quad(vid[id(x-1,y,z-1)],vid[id(x-1,y,z)],vid[id(x,y,z)],vid[id(x,y,z-1)],f0);
  if(f0!==(F[id(x,y,z+1)]<0))quad(vid[id(x-1,y-1,z)],vid[id(x,y-1,z)],vid[id(x,y,z)],vid[id(x-1,y,z)],f0);}
 const nv=P.length/3,out=new Float32Array(nv*7);
 const nrm=p=>{const e=0.004;const n=[f([p[0]+e,p[1],p[2]])-f([p[0]-e,p[1],p[2]]),f([p[0],p[1]+e,p[2]])-f([p[0],p[1]-e,p[2]]),f([p[0],p[1],p[2]+e])-f([p[0],p[1],p[2]-e])];const l=len(n)||1;return [n[0]/l,n[1]/l,n[2]/l]};
 for(let i=0;i<nv;i++){let p=[P[i*3],P[i*3+1],P[i*3+2]];for(let k=0;k<3;k++){const n=nrm(p),d=f(p);p=[p[0]-n[0]*d,p[1]-n[1]*d,p[2]-n[2]*d]}
  const n=nrm(p);let s=0,w=1;for(let j=1;j<=6;j++){const h=0.04*j;const q=[p[0]+n[0]*h,p[1]+n[1]*h,p[2]+n[2]*h];s+=(h-Math.min(all(q),q[1]))*w;w*=0.74}
  out.set([p[0],p[1],p[2],n[0],n[1],n[2],clamp(1-s*1.7,0,1)],i*7)}
 const h=Buffer.alloc(8);h.writeUInt32LE(nv,0);h.writeUInt32LE(I.length,4);buffers.push(h,Buffer.from(out.buffer),Buffer.from(new Uint32Array(I).buffer));tot+=I.length/3;console.log(name,nv,'verts');}
fs.writeFileSync(OUT,Buffer.concat(buffers));console.log({tris:tot,KB:Math.round(fs.statSync(OUT).size/1024)});
