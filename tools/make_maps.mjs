// Writes the four built-in maps from real catalog models.
import fs from 'fs';
const cat=JSON.parse(fs.readFileSync('catalog.json'));
let seed=7;const R=(a,b)=>{seed=(seed*16807)%2147483647;return a+(seed/2147483647)*(b-a)};const pick=a=>a[Math.floor(R(0,a.length))];
const has=id=>{const[p,n]=id.split('/');if(!cat[p]||!cat[p].n.includes(n))throw new Error('missing '+id);return id};
const S=id=>cat[id.split('/')[0]].s;
const O=(id,x,z,yaw=0,s=1,y=0)=>[has(id),+x.toFixed(2),+y.toFixed(2),+z.toFixed(2),+yaw.toFixed(3),+(S(id)*s).toFixed(3)];
function scatter(list,n,half,avoid=4){const o=[];for(let i=0;i<n;i++){let x,z;do{x=R(-half,half);z=R(-half,half)}while(Math.hypot(x,z)<avoid);o.push(O(pick(list),x,z,R(0,6.28)))}return o}
const f=n=>'furniture-kit/'+n, sk=n=>'survival-kit/'+n, fa=n=>'factory-kit/'+n, sp=n=>'space-station-kit/'+n, na=n=>'nature-kit/'+n, sb=n=>'city-kit-suburban/'+n, cm=n=>'city-kit-commercial/'+n;
const natureTrees=cat['nature-kit'].n.filter(n=>/^tree_/.test(n)).slice(0,30).map(na),rocks=cat['nature-kit'].n.filter(n=>/^(rock_|stone_)/.test(n)).slice(0,20).map(na),plants=cat['nature-kit'].n.filter(n=>/^(plant_|flower_|mushroom_)/.test(n)).slice(0,16).map(na);
const lab=[...scatter([sp('container'),sp('container-tall'),sp('container-wide'),sp('computer-system'),sp('table-large'),sp('table-display'),sp('chair-armrest'),sp('computer-wide'),sp('bed-single'),sp('rocks'),fa('box-large'),fa('box-wide'),fa('box-small'),fa('hopper-high-round'),fa('hopper-square'),fa('crane'),fa('cone')],70,19,5)];
const town=[];for(let gx=-1;gx<=1;gx++)for(let gz=-1;gz<=1;gz++){if(gx===0&&gz===0)continue;town.push(O(pick(cat['city-kit-suburban'].n.filter(n=>n.startsWith('building-type')).map(sb)),gx*18,gz*18,[0,1.571,3.142,4.712][Math.floor(R(0,4))],1.2));}
town.push(...scatter([sb('tree-large'),sb('tree-small'),sb('planter'),sb('fence-2x2'),sb('fence-1x3'),sb('fence-low'),'car-kit/sedan','car-kit/suv','car-kit/van',cm('detail-parasol-a'),cm('detail-parasol-b')],80,29,5));
const house=[];const w=f('wallHalf');
house.push(...scatter([f('loungeSofa'),f('loungeSofaLong'),f('chair'),f('chairCushion'),f('desk'),f('bedDouble'),f('bedSingle'),f('bookcaseClosedWide'),f('bookcaseOpen'),f('kitchenFridgeLarge'),f('kitchenCabinet'),f('kitchenStove'),f('bathtub'),f('pottedPlant'),f('lampRoundFloor'),f('sideTable'),f('cardboardBoxClosed'),f('cardboardBoxOpen'),f('coatRackStanding'),f('rugRound'),f('rugRectangle'),f('cabinetTelevision'),f('dryer'),f('shower')],85,14,3.5));
const forest=[...scatter(natureTrees,70,28,4),...scatter(rocks,30,28,4),...scatter(plants,35,28,3),...scatter([sk('tent'),sk('tent-canvas'),sk('barrel'),sk('chest'),sk('box-large'),sk('campfire-pit'),sk('workbench'),sk('tree-log'),sk('bedroll')],22,20,4)];
const id=m=>m; for(const [file,name,floor,size,o] of [['clone_lab','Clone Lab','lab',44,lab],['tiny_town','Tiny Town','grass',64,town],['cozy_house','Cozy House','wood',34,house],['forest_camp','Forest Camp','grass',64,forest]]){
 fs.writeFileSync(`maps/${file}.json`,JSON.stringify({id:file,name,floor,size,o}));console.log(file,o.length);}
