// Writes the four built-in maps from real catalog models, laid out by hand.
import fs from 'fs';
const cat=JSON.parse(fs.readFileSync('catalog.json'));
let seed=11;const R=(a,b)=>{seed=(seed*16807)%2147483647;return a+(seed/2147483647)*(b-a)};const pick=a=>a[Math.floor(R(0,a.length))];
const has=id=>{const[p,n]=id.split('/');if(!cat[p]||!cat[p].n.includes(n))throw new Error('missing '+id);return id};
const S=id=>cat[id.split('/')[0]].s;
const O=(id,x,z,yaw=0,s=1,y=0)=>[has(id),+x.toFixed(2),+y.toFixed(2),+z.toFixed(2),+yaw.toFixed(3),+(S(id)*s).toFixed(3)];
const Q=[0,Math.PI/2,Math.PI,-Math.PI/2];
const f=n=>'furniture-kit/'+n, sk=n=>'survival-kit/'+n, fa=n=>'factory-kit/'+n, sp=n=>'space-station-kit/'+n, na=n=>'nature-kit/'+n, sb=n=>'city-kit-suburban/'+n, ro=n=>'city-kit-roads/'+n, cm=n=>'city-kit-commercial/'+n, ca=n=>'car-kit/'+n;
// ---- Cozy House: one shared wall grid, four rooms in a ring (no dead ends), front and back door
const house=[];const U=2.4,N=10;
const hw=(z,doors)=>{for(let i=0;i<N;i++)house.push(O(f(doors.includes(i)?'wallDoorwayWide':(z!==0&&i%3==1?'wallWindow':'wall')),-12+i*U,z,0));};
const vw=(x,doors)=>{for(let j=0;j<N;j++)house.push(O(f(doors.includes(j)?'wallDoorwayWide':(x!==0&&j%3==1?'wallWindow':'wall')),x,-12+j*U,-Math.PI/2));};
hw(-12,[4]);hw(0,[2,7]);hw(12,[2]);vw(-12,[]);vw(0,[2,7]);vw(12,[]);
const put=(l)=>l.forEach(a=>house.push(O(f(a[0]),a[1],a[2],a[3]||0,a[4]||1)));
put([['rugRectangle',-8,-8],['loungeSofaLong',-10.5,-10.8],['tableCoffee',-8.5,-8.4],['cabinetTelevision',-10,-1.2,Math.PI],['televisionModern',-10,-1.2,Math.PI],['lampRoundFloor',-11.4,-3],['bookcaseClosedWide',-6,-11.5],['pottedPlant',-1.2,-1.2],['loungeChair',-3.6,-9,-Math.PI/2],['cardboardBoxClosed',-11,-6.5],
['kitchenCabinet',1,-11.2],['kitchenCabinet',3.4,-11.2],['kitchenStove',5.8,-11.2],['kitchenSink',8.2,-11.2],['kitchenFridgeLarge',10.3,-11.2],['tableRound',6.6,-6.5],['chair',5,-6.5,-Math.PI/2],['chair',8.4,-6.5,Math.PI/2],['chair',6.6,-4.7,Math.PI],['kitchenBar',1.2,-2.4,Math.PI/2],['coatRackStanding',11,-1.4],
['bedDouble',-10.8,3.6],['sideTableDrawers',-11.2,1.1],['lampRoundTable',-11.2,1.1],['rugRound',-6,7.4],['bookcaseOpen',-2.4,.8],['deskCorner',-11,9.9,Math.PI/2],['chairDesk',-9,9.4],['computerScreen',-10.8,9.8],['cardboardBoxOpen',-1.6,11],['bear',-5.8,7.2],
['bathtub',1,1],['shower',10,1],['bathroomSink',9,.8],['bathroomCabinet',3,.8],['rugSquare',5.5,5.4],['washer',1.2,10.9],['dryer',3.6,10.9],['plantSmall1',11,11],['loungeDesignSofa',7,10.6,Math.PI],['benchCushion',10.6,6,Math.PI/2]]);
// ---- Tiny Town: two streets, houses facing them, gardens and parked cars
const town=[];const T=8;
for(let i=-4;i<=4;i++){if(i===0)continue;town.push(O(ro('road-straight'),i*T,0,Math.PI/2,2.67));town.push(O(ro('road-straight'),0,i*T,0,2.67));}
town.push(O(ro('road-crossroad'),0,0,0,2.67));
const hs=cat['city-kit-suburban'].n.filter(n=>n.startsWith('building-type')).map(sb);
[[-1,-1],[1,-1],[-1,1],[1,1]].forEach(([sx,sz])=>{
 for(const d of [13,26]){const hx=sx*d,hz=sz*11;town.push(O(pick(hs),hx,hz,sz<0?Math.PI:0,2));
  town.push(O(sb('tree-large'),hx+sx*5.5,hz+sz*6,R(0,6)),O(sb('planter'),hx-4,hz-sz*5,0,1.2),O(sb('fence-2x2'),hx,hz+sz*9,0,1.6));}
 for(const d of [11,24]){const hx=sx*11,hz=sz*(d+8);if(d>11){town.push(O(pick(hs),hx,hz,sx<0?Math.PI/2:-Math.PI/2,2));town.push(O(sb('tree-small'),hx+sx*6,hz+5,0,1.5));}}
 town.push(O(pick([ca('sedan'),ca('suv'),ca('van'),ca('taxi'),ca('hatchback-sports')]),sx*5.6,sz*16,sz>0?0:Math.PI),O(pick([ca('sedan'),ca('suv'),ca('delivery')]),sx*18,sz*5.6,Math.PI/2*sx));
 town.push(O(ro('light-curved'),sx*5,sz*7,0,1.6),O(cm('detail-parasol-a'),sx*30,sz*5,0,2),O(ro('dumpster'),sx*5,sz*28,0,1.5),O(ro('construction-cone'),sx*7,sz*5.2,0,1.5));
});
// ---- Clone Lab: aisles of machines and crates with open work areas
const lab=[];
const mach=[fa('hopper-high-round'),fa('hopper-square'),fa('hopper-round'),sp('computer-system'),sp('container-tall'),sp('container-wide'),sp('container')];
for(const x of [-15,-7.5,7.5,15])for(let z=-17;z<=17;z+=5.5){if(Math.abs(z)<4&&Math.abs(x)<9)continue;lab.push(O(pick(mach),x+R(-.3,.3),z,pick(Q)));if(R(0,1)>.5)lab.push(O(pick([fa('box-small'),fa('box-large'),fa('box-wide')]),x+2.4,z+1.4,pick(Q)));}
for(const x of [-11,11])for(const z of [-10,0,10]){lab.push(O(sp('table-large'),x,z,0));lab.push(O(sp('chair-armrest'),x,z+2.4,Math.PI),O(sp('computer-wide'),x,z,0,1,1.6));}
for(let z=-18;z<=18;z+=6)lab.push(O(fa('cone'),-3.5,z),O(fa('cone'),3.5,z));
lab.push(O(sp('table-display'),0,0),O(sp('bed-single'),0,-13),O(sp('bed-single'),0,13,Math.PI),O(fa('crane'),0,-20,0,.8),O(fa('crane'),0,20,Math.PI,.8));
// ---- Forest Camp: tents and a fire in a clearing, thick woods around it
const trees=cat['nature-kit'].n.filter(n=>/^tree_(default|oak|fat|detailed|pineDefault|pineRound|cone)/.test(n)&&!/fall/.test(n)).map(na);
const rocks=cat['nature-kit'].n.filter(n=>/^rock_(large|tall|small)/.test(n)).map(na),bush=cat['nature-kit'].n.filter(n=>/^(plant_bush|grass_large|flower_|mushroom_)/.test(n)).map(na);
const forest=[];
for(let i=0;i<78;i++){const a=R(0,6.28),r=R(13,30);const x=Math.cos(a)*r,z=Math.sin(a)*r;forest.push(O(pick(trees),x,z,R(0,6.28),R(1.8,3.1)));if(R(0,1)>.55)forest.push(O(pick(bush),x+R(-2.5,2.5),z+R(-2.5,2.5),R(0,6.28),R(1.4,2.2)));}
for(let i=0;i<28;i++){const a=R(0,6.28),r=R(9,30);forest.push(O(pick(rocks),Math.cos(a)*r,Math.sin(a)*r,R(0,6.28),R(1.6,3.4)));}
for(let i=0;i<34;i++){const a=R(0,6.28),r=R(5,20);forest.push(O(pick(bush),Math.cos(a)*r,Math.sin(a)*r,R(0,6.28),R(1.2,2)));}
[[0,-8,0],[8,-3,-1.2],[-8,-3,1.2],[5,7,-2.4],[-5,7,2.4]].forEach(([x,z,y],i)=>forest.push(O(sk(i%2?'tent-canvas':'tent'),x,z,y,.9)));
forest.push(O(sk('campfire-pit'),0,0,0,.9),O(sk('tree-log'),2.8,1.4,1),O(sk('tree-log'),-2.8,1.4,-1),O(sk('chest'),8,3),O(sk('barrel'),-8,3),O(sk('box-large'),-10.5,0),O(sk('workbench'),10.5,0,-1.5),O(sk('bedroll'),1.5,-5));
for(const [file,name,floor,size,o] of [['clone_lab','Clone Lab','lab',46,lab],['tiny_town','Tiny Town','grass',72,town],['cozy_house','Cozy House','wood',30,house],['forest_camp','Forest Camp','grass',64,forest]]){
 fs.writeFileSync(`maps/${file}.json`,JSON.stringify({id:file,name,floor,size,o}));console.log(file,o.length);}
