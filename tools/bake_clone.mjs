// Sculpts the clone figure as one smooth mesh (signed distance field + surface nets).
// Bakes soft shadows in the creases and limb weights into clone_mesh.bin.
import fs from 'fs';
const CELL=+process.argv[2]||0.02;const OUT=process.argv[3]||'clone_mesh.bin';
const v=(x,y,z)=>[x,y,z],sub=(a,b)=>[a[0]-b[0],a[1]-b[1],a[2]-b[2]],dot=(a,b)=>a[0]*b[0]+a[1]*b[1]+a[2]*b[2],len=a=>Math.hypot(a[0],a[1],a[2]);
const clamp=(x,a,b)=>Math.min(b,Math.max(a,x)),ss=(a,b,x)=>{const t=clamp((x-a)/(b-a),0,1);return t*t*(3-2*t)};
const smin=(a,b,k)=>{const h=Math.max(k-Math.abs(a-b),0)/k;return Math.min(a,b)-h*h*k*0.25};
function cone(p,a,b,r1,r2){const ba=sub(b,a),pa=sub(p,a);const t=clamp(dot(pa,ba)/dot(ba,ba),0,1);return len([pa[0]-ba[0]*t,pa[1]-ba[1]*t,pa[2]-ba[2]*t])-(r1+(r2-r1)*t)}
const sph=(p,c,r)=>len(sub(p,c))-r;
const bodyRaw=p=>cone([p[0],p[1],p[2]/0.92],v(0,0.66,0),v(0,1.3,0),0.47,0.43);
function arm(p,s){const q=[p[0]*s,p[1],p[2]];
 let d=cone(q,v(0.4,1.0,0),v(0.6,0.7,-0.05),0.068,0.066);
 d=smin(d,sph(q,v(0.635,0.6,-0.07),0.135),0.05);
 d=smin(d,sph(q,v(0.56,0.66,-0.15),0.052),0.035); // thumb
 return d}
function leg(p,s){const q=[p[0]*s,p[1],p[2]];
 let d=cone(q,v(0.2,0.36,0),v(0.21,0.16,-0.01),0.17,0.135);
 const boot=Math.max(cone(q,v(0.215,0.1,0.03),v(0.225,0.095,-0.13),0.135,0.125),-q[1]);
 return smin(d,boot,0.05)}
function faceE(p){return Math.hypot(p[0]/0.3,(p[1]-1.24)/0.25)}
function torso(p){let b=bodyRaw(p);if(p[2]<0){b+=0.03*ss(1.08,0.9,faceE(p));}
 if(p[2]<-0.05){const ring=Math.hypot((faceE(p)-1.06)*0.27,bodyRaw(p))-0.036;b=smin(b,ring,0.035);}
 return b}
function sdf(p){let d=torso(p);d=smin(d,leg(p,1),0.07);d=smin(d,leg(p,-1),0.07);d=smin(d,arm(p,1),0.05);d=smin(d,arm(p,-1),0.05);return d}
const nrm=p=>{const e=0.005;const n=[sdf([p[0]+e,p[1],p[2]])-sdf([p[0]-e,p[1],p[2]]),sdf([p[0],p[1]+e,p[2]])-sdf([p[0],p[1]-e,p[2]]),sdf([p[0],p[1],p[2]+e])-sdf([p[0],p[1],p[2]-e])];const l=len(n)||1;return [n[0]/l,n[1]/l,n[2]/l]};
const X0=-0.85,Y0=-0.04,Z0=-0.62,NX=Math.ceil(1.7/CELL),NY=Math.ceil(1.86/CELL),NZ=Math.ceil(1.24/CELL);
const id=(x,y,z)=>x+(NX+1)*(y+(NY+1)*z);const F=new Float32Array((NX+1)*(NY+1)*(NZ+1));
for(let z=0;z<=NZ;z++)for(let y=0;y<=NY;y++)for(let x=0;x<=NX;x++)F[id(x,y,z)]=sdf([X0+x*CELL,Y0+y*CELL,Z0+z*CELL]);
const vid=new Int32Array(F.length).fill(-1),P=[];
const C=[[0,0,0],[1,0,0],[0,1,0],[1,1,0],[0,0,1],[1,0,1],[0,1,1],[1,1,1]],E=[[0,1],[2,3],[4,5],[6,7],[0,2],[1,3],[4,6],[5,7],[0,4],[1,5],[2,6],[3,7]];
for(let z=0;z<NZ;z++)for(let y=0;y<NY;y++)for(let x=0;x<NX;x++){const f=C.map(c=>F[id(x+c[0],y+c[1],z+c[2])]);let s=[0,0,0],n=0;for(const[a,b]of E){if((f[a]<0)!==(f[b]<0)){const t=f[a]/(f[a]-f[b]);for(let i=0;i<3;i++)s[i]+=C[a][i]+(C[b][i]-C[a][i])*t;n++}}if(!n)continue;vid[id(x,y,z)]=P.length/3;P.push(X0+(x+s[0]/n)*CELL,Y0+(y+s[1]/n)*CELL,Z0+(z+s[2]/n)*CELL)}
const I=[];const quad=(a,b,c,d,flip)=>{if(a<0||b<0||c<0||d<0)return;if(flip)I.push(a,c,b,a,d,c);else I.push(a,b,c,a,c,d)};
for(let z=1;z<NZ;z++)for(let y=1;y<NY;y++)for(let x=1;x<NX;x++){const f0=F[id(x,y,z)]<0;
 if(f0!==(F[id(x+1,y,z)]<0))quad(vid[id(x,y-1,z-1)],vid[id(x,y,z-1)],vid[id(x,y,z)],vid[id(x,y-1,z)],f0);
 if(f0!==(F[id(x,y+1,z)]<0))quad(vid[id(x-1,y,z-1)],vid[id(x-1,y,z)],vid[id(x,y,z)],vid[id(x,y,z-1)],f0);
 if(f0!==(F[id(x,y,z+1)]<0))quad(vid[id(x-1,y-1,z)],vid[id(x,y-1,z)],vid[id(x,y,z)],vid[id(x-1,y,z)],f0);}
const nv=P.length/3,stride=11,out=new Float32Array(nv*stride);
const ao=(p,n)=>{let s=0,w=1;for(let i=1;i<=6;i++){const h=0.035*i;const q=[p[0]+n[0]*h,p[1]+n[1]*h,p[2]+n[2]*h];const d=Math.min(sdf(q),q[1]);s+=(h-d)*w;w*=0.72}return clamp(1-s*2.3,0,1)};
for(let i=0;i<nv;i++){let p=[P[i*3],P[i*3+1],P[i*3+2]];for(let k=0;k<3;k++){const n=nrm(p),d=sdf(p);p=[p[0]-n[0]*d,p[1]-n[1]*d,p[2]-n[2]*d]}
 const n=nrm(p);const dB=torso(p),aL=arm(p,-1),aR=arm(p,1),lL=leg(p,-1),lR=leg(p,1);
 const w=(d)=>ss(0.07,-0.03,d-dB);
 out.set([p[0],p[1],p[2],n[0],n[1],n[2],w(aL),w(aR),w(lL),w(lR),ao(p,n)],i*stride)}
const head=Buffer.alloc(8);head.writeUInt32LE(nv,0);head.writeUInt32LE(I.length,4);
fs.writeFileSync(OUT,Buffer.concat([head,Buffer.from(out.buffer),Buffer.from(new Uint32Array(I).buffer)]));
console.log({verts:nv,tris:I.length/3,KB:Math.round(fs.statSync(OUT).size/1024)});
