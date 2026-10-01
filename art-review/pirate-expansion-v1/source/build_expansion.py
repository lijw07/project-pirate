"""Original supplementary meshes, styled to match Kenney Pirate Kit. Review only."""
import bpy,math,random,json,hashlib
from pathlib import Path
from mathutils import Vector
OUT=Path('/Users/jaili/projects/godot/project-pirate/art-review/pirate-expansion-v1')
random.seed(33)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
CAT=bpy.context.scene;CAT.name='01 • Expansion Catalog'
M={};assets={};records=[]
def mat(name,h,rough=.8,metal=0,emit=0):
 m=bpy.data.materials.new(name);m.use_nodes=True
 rgb=[int(h[i:i+2],16)/255 for i in (0,2,4)];rgb=[c/12.92 if c<.04045 else ((c+.055)/1.055)**2.4 for c in rgb]
 m.diffuse_color=(*rgb,1);p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*rgb,1);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
 if emit:p.inputs['Emission Color'].default_value=(*rgb,1);p.inputs['Emission Strength'].default_value=emit
 M[name]=m;return m
for args in [('wood','B56740'),('endgrain','DBA065'),('darkwood','7C482F'),('sand','EAC79B'),('cream','EEE0BA'),('teal','258E88'),('red','BC554C'),('stone','77829F'),('stone-light','A6B1CA'),('roof','5978AE'),('iron','39485D',.55,.25),('steel','8FA9BC',.55,.2),('gold','EBBD4D',.5,.3),('black','1F2B3A'),('leaf','63AD76'),('fruit','E69D50'),('embers','FFB14F',.5,0,1.2),('sea','167889',.3),('foam','C0E7D8'),('board','153545')]:mat(*args)

def asset(name,title,category):
 c=bpy.data.collections.new(title);r=bpy.data.objects.new(name,None);c.objects.link(r);r['asset_id']=name;r['category']=category
 assets[name]=(c,r);records.append({'id':name,'title':title,'category':category});return r

def adopt(o,r,name,material):
 for c in list(o.users_collection):c.objects.unlink(o)
 r.users_collection[0].objects.link(o);o.parent=r;o.name=name
 if material:o.data.materials.append(M[material])
 return o

def box(r,name,at,size,material='wood',bevel=.03):
 bpy.ops.mesh.primitive_cube_add(size=1);o=adopt(bpy.context.object,r,name,material);o.location=at;o.scale=size
 if bevel:
  bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);m=o.modifiers.new('Rounded corners','BEVEL');m.width=bevel;m.segments=1;o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
 return o

def cyl(r,name,at,rad,depth,material='wood',n=12,top=None):
 bpy.ops.mesh.primitive_cone_add(vertices=n,radius1=rad,radius2=rad if top is None else top,depth=depth)
 o=adopt(bpy.context.object,r,name,material);o.location=at;return o

def ball(r,name,at,scale,material,sub=1):
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub,radius=1);o=adopt(bpy.context.object,r,name,material);o.location=at;o.scale=(scale,)*3 if isinstance(scale,(int,float)) else scale;return o

def beam(r,name,a,b,w,material='wood'):
 a,b=Vector(a),Vector(b);o=box(r,name,(a+b)/2,(w,w,(b-a).length),material,.01);o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o

def line(r,name,pts,w=.035,material='cream',closed=False):
 cu=bpy.data.curves.new(name,'CURVE');cu.dimensions='3D';cu.bevel_depth=w;cu.bevel_resolution=0
 sp=cu.splines.new('POLY');sp.points.add(len(pts)-1)
 for p,xyz in zip(sp.points,pts):p.co=(*xyz,1)
 sp.use_cyclic_u=closed;ob=bpy.data.objects.new(name,cu);r.users_collection[0].objects.link(ob);ob.parent=r;cu.materials.append(M[material]);return ob

def torus(r,name,at,major,minor,material='iron',rotation=(0,0,0)):
 bpy.ops.mesh.primitive_torus_add(major_segments=16,minor_segments=6,location=(0,0,0),major_radius=major,minor_radius=minor)
 o=adopt(bpy.context.object,r,name,material);o.location=at;o.rotation_euler=rotation;return o

def text(r,body,at,size=.3):
 c=bpy.data.curves.new(body,'FONT');c.body=body;c.align_x='CENTER';c.size=size
 o=bpy.data.objects.new(body,c);r.users_collection[0].objects.link(o);o.parent=r;o.location=at;c.materials.append(M['cream']);return o

def crate(r,at,size=.7,fill=None):
 x,y,z=at
 box(r,'Crate base',(x,y,z+.07),(size,size,.14),'darkwood')
 for side in [-1,1]:
  for h in [.24,.47]:
   box(r,'Slatted crate',(x+side*(size/2-.045),y,z+h),(.09,size,.17),'wood')
   box(r,'Slatted crate',(x,y+side*(size/2-.045),z+h),(size,.09,.17),'wood')
 if fill:
  for i in range(4):ball(r,'Crate contents',(x+(i%2-.5)*size*.4,y+(i//2-.5)*size*.4,z+.48),size*.21,fill,2 if fill=='fruit' else 1)

def barrel(r,at,scale=1):
 x,y,z=at
 cyl(r,'Barrel staves',(x,y,z+.44*scale),.37*scale,.88*scale,'wood',10,top=.32*scale)
 for h in [.16,.68]:torus(r,'Barrel hoop',(x,y,z+h*scale),.355*scale,.042*scale,'iron')
 cyl(r,'Barrel lid',(x,y,z+.89*scale),.30*scale,.05*scale,'endgrain',10)

def roof(r,at,size,material='roof'):
 x,y,z=at;w,d,h=size
 verts=[(x-w/2,y-d/2,z),(x+w/2,y-d/2,z),(x,y-d/2,z+h),(x-w/2,y+d/2,z),(x+w/2,y+d/2,z),(x,y+d/2,z+h)]
 mesh=bpy.data.meshes.new('Pitched roof');mesh.from_pydata(verts,[],[(0,1,2),(3,5,4),(0,3,4,1),(0,2,5,3),(1,4,5,2)]);mesh.materials.append(M[material]);o=bpy.data.objects.new('Pitched roof',mesh);r.users_collection[0].objects.link(o);o.parent=r
 for y0 in [y-d/2,y+d/2]:
  beam(r,'Roof trim',(x-w/2,y0,z),(x,y0,z+h),.14,'endgrain');beam(r,'Roof trim',(x+w/2,y0,z),(x,y0,z+h),.14,'endgrain')

def cabin(r,w=3.2,d=2.6):
 box(r,'Foundation',(0,0,.18),(w+.4,d+.4,.36),'stone')
 for x in [-w/2,w/2]:
  for y in [-d/2,d/2]:box(r,'Corner timber',(x,y,1.42),(.20,.20,2.5),'darkwood')
 for i in range(6):box(r,'Rear planking',(0,d/2,.52+i*.34),(w,.13,.30),'wood')
 for side in [-1,1]:
  for i in range(6):box(r,'Side planking',(side*w/2,0,.52+i*.34),(.13,d,.30),'wood')
 roof(r,(0,0,2.7),(w+.5,d+.45,.95))

# Four resource buildings.
r=asset('provision-store','Provision Store','resource');cabin(r)
for x in [-1.55,1.55]:beam(r,'Awning post',(x,-2.3,.1),(x,-2.3,2.25),.14)
for i in range(6):
 o=box(r,'Striped canvas awning',(-1.4+i*.56,-1.85,2.40),(.56,1.4,.06),'cream' if i%2==0 else 'teal',0);o.rotation_euler.x=.17
box(r,'Market counter',(0,-1.6,.82),(2.8,.64,.20),'endgrain')
for x in [-1.1,0,1.1]:crate(r,(x,-1.6,.95),.70,'fruit' if x==0 else 'leaf')
barrel(r,(2.15,.1,.0),.8)

r=asset('timber-workshop','Timber Workshop','resource');
for x in [-1.6,1.6]:
 for y in [-1.25,1.25]:beam(r,'Timber-frame post',(x,y,0),(x,y,2.65),.22)
roof(r,(0,0,2.6),(3.8,3.1,1.05),'cream')
box(r,'Saw table',(0,-.35,1.0),(2.7,.65,.17),'endgrain')
for x in [-1,1]:beam(r,'Sawhorse leg',(x,-.35,.05),(x,-.35,.96),.17)
beam(r,'Frame saw blade',(-.9,-.35,1.3),(.9,-.35,1.3),.08,'steel')
for x in [-.95,.95]:beam(r,'Saw handle',(x,-.35,1.15),(x,-.35,1.8),.09,'wood')
beam(r,'Saw frame',(-.95,-.35,1.72),(.95,-.35,1.72),.09,'wood')
for j in range(3):
 for i in range(3-j):
  o=cyl(r,'Stored log',(0,1.9+i*.48+j*.24,.28+j*.38),.23,2.8,'wood',9);o.rotation_euler.y=math.pi/2
  for side in [-1,1]:
   cap=cyl(r,'Cut log end',(side*1.41,1.9+i*.48+j*.24,.28+j*.38),.21,.025,'endgrain',9);cap.rotation_euler.y=math.pi/2

r=asset('iron-foundry','Island Foundry','resource')
box(r,'Stone hearth',(0,0,.48),(2.4,1.8,.96),'stone',.12)
box(r,'Glowing coals',(0,-.45,1.0),(1.2,.9,.12),'embers',.04)
for x in [-.9,.9]:box(r,'Hearth side',(x,0,1.40),(.50,1.8,1.4),'stone',.10)
box(r,'Stone hood',(0,.2,2.05),(2.2,1.45,.40),'stone',.12)
box(r,'Chimney',(0,.48,3.1),(.85,.75,1.8),'stone',.1)
box(r,'Chimney rim',(0,.48,4.02),(1.05,.95,.2),'stone-light',.05)
box(r,'Dark flue',(0,.48,4.13),(.68,.58,.025),'black',0)
cyl(r,'Anvil stump',(-1.95,-.3,.44),.48,.88,'wood',9)
box(r,'Anvil foot',(-1.95,-.3,1.0),(.72,.5,.25),'iron');box(r,'Anvil face',(-1.95,-.3,1.36),(1.1,.47,.20),'steel')
beam(r,'Anvil waist',(-1.95,-.3,1.10),(-1.95,-.3,1.32),.28,'iron')
crate(r,(1.9,-.35,0),.9,'steel')

r=asset('treasury-vault','Treasury Vault','resource')
box(r,'Vault foundation',(0,0,.22),(3.6,2.9,.44),'stone-light',.10)
box(r,'Stone vault',(0,0,1.50),(3.15,2.4,2.7),'stone',.16)
roof(r,(0,0,2.88),(3.8,3.1,1.0),'roof')
box(r,'Door recess',(0,-1.215,1.3),(1.25,.05,2.05),'black',.10)
for i in range(5):box(r,'Iron vault door',(-.50+i*.25,-1.27,1.3),(.18,.06,1.86),'iron',.025)
for z in [.66,1.85]:box(r,'Door strap',(0,-1.32,z),(1.2,.06,.10),'gold',.025)
torus(r,'Vault lock',(0,-1.38,1.25),.18,.055,'gold',(math.pi/2,0,0))
for i in range(5):box(r,'Gold ingot',(-1.1+(i%3)*.45,-1.95,.2+(i//3)*.22),(.4,.7,.2),'gold',.045)

# Harbor infrastructure, built as reusable sections.
r=asset('shipyard-gantry','Shipyard Gantry','harbor')
for x in [-2.5,2.5]:
 for y in [-.65,.65]:beam(r,'Gantry upright',(x,y,0),(x*.85,0,4.8),.25,'wood')
 beam(r,'Gantry sill',(x,-1.1,.12),(x,1.1,.12),.26,'darkwood')
beam(r,'Main lifting beam',(-2.55,0,4.7),(2.55,0,4.7),.40,'wood')
for x in [-2,2]:beam(r,'Gantry knee',(x,0,3.45),(x*.6,0,4.7),.2,'endgrain')
torus(r,'Pulley',(0,-.15,4.32),.35,.10,'iron',(math.pi/2,0,0))
line(r,'Hoist rope',[(0,-.18,4.42),(0,-.18,1.5)],.045,'cream');line(r,'Lifting hook',[(0,-.18,1.5),(-.2,-.18,1.25),(-.18,-.18,1.0),(.12,-.18,.95),(.3,-.18,1.2)],.08,'iron')

r=asset('harbor-lighthouse','Harbor Lighthouse','harbor')
cyl(r,'Octagonal footing',(0,0,.25),1.45,.5,'stone',8)
cyl(r,'Tower lower',(0,0,1.5),1.14,2,'cream',8,top=.94)
cyl(r,'Tower band',(0,0,2.9),.94,.8,'teal',8,top=.87)
cyl(r,'Tower upper',(0,0,3.75),.87,.9,'cream',8,top=.78)
cyl(r,'Lantern balcony',(0,0,4.28),1.2,.2,'stone-light',12)
cyl(r,'Lantern glow',(0,0,4.95),.52,1.15,'embers',8)
for i in range(8):
 a=i*math.tau/8;beam(r,'Lantern frame',(math.cos(a)*.65,math.sin(a)*.65,4.4),(math.cos(a)*.65,math.sin(a)*.65,5.5),.07,'iron')
cyl(r,'Lantern cap',(0,0,5.85),1.07,.72,'roof',8,top=0)
box(r,'Door',(0,-1.09,.98),(.62,.04,1.25),'wood',.08)
for i in range(12):
 a=i*math.tau/12;beam(r,'Balcony rail post',(math.cos(a)*1.05,math.sin(a)*1.05,4.4),(math.cos(a)*1.05,math.sin(a)*1.05,4.88),.05,'iron')
torus(r,'Balcony rail',(0,0,4.87),1.05,.05,'iron')

def dockpiece(r,corner=False):
 pts=[(x,y) for x in range(-2,3) for y in range(-2,3) if (x<=-1 or y>=1 if corner else y>=1 or abs(x)<=1)]
 for x,y in pts:box(r,'Pier plank',(x*.65,y*.65,.55),(.63,.63,.16),'wood',.055)
 positions=[(-1.3,1.3),(1.3,1.3),(0,-1.3)] if not corner else [(-1.3,1.3),(-1.3,0),(0,1.3)]
 for x,y in positions:
  cyl(r,'Dock piling',(x,y,.45),.13,1.4,'darkwood',9)
  torus(r,'Rope collar',(x,y,.90),.15,.037,'cream')
r=asset('dock-t-junction','Dock T Junction','harbor');dockpiece(r)
r=asset('dock-corner','Dock Corner','harbor');dockpiece(r,True)
r=asset('mooring-bollard','Mooring Bollard','harbor')
box(r,'Mounting base',(0,0,.1),(.9,.9,.2),'wood')
cyl(r,'Bollard stem',(0,0,.48),.23,.7,'iron');cyl(r,'Bollard cap',(0,0,.85),.35,.14,'iron')
for i in range(3):torus(r,'Coiled rope',(0,0,.20+i*.10),.36,.046,'cream')
line(r,'Loose rope',[(.4,0,.19),(.7,-.2,.07),(1,-.1,.07),(1.1,.2,.07)],.045,'cream')
r=asset('navigation-buoy','Navigation Buoy','harbor')
cyl(r,'Buoy float',(0,0,.25),.65,.50,'teal',12,top=.43);cyl(r,'Buoy neck',(0,0,.72),.19,.5,'cream',10)
cyl(r,'Marker cap',(0,0,1.12),.35,.5,'red',10,top=0);torus(r,'Buoy eye',(0,0,1.44),.13,.04,'iron',(math.pi/2,0,0))

# Hollow barrels have real muzzle geometry, not a dark disk on a solid cylinder.
def tube(r,name,at,radius,length,direction):
 n=12;verts=[];faces=[]
 for z,rad in [(0,radius*.84),(length,radius),(length,radius*.65),(.14,radius*.56)]:
  verts += [(math.cos(i*math.tau/n)*rad,math.sin(i*math.tau/n)*rad,z) for i in range(n)]
 for ring in range(3):
  for i in range(n):a=ring*n+i;b=ring*n+(i+1)%n;faces.append((a,b,b+n,a+n))
 faces.append(tuple(range(3*n,4*n)))
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.materials.append(M['iron']);ob=bpy.data.objects.new(name,mesh);r.users_collection[0].objects.link(ob);ob.parent=r;ob.location=at;ob.rotation_euler=Vector(direction).to_track_quat('Z','Y').to_euler();return ob
r=asset('swivel-gun','Swivel Gun','equipment')
cyl(r,'Gun pedestal',(0,0,.43),.17,.86,'wood');cyl(r,'Pedestal foot',(0,0,.10),.42,.20,'iron')
for x in [-.23,.23]:beam(r,'Swivel yoke',(x,0,.73),(x,0,1.18),.10,'steel')
tube(r,'Swivel barrel',(0,.26,1.13),.19,.93,(0,-1,.12))
r=asset('deck-mortar','Deck Mortar','equipment')
box(r,'Mortar mounting',(0,0,.15),(1.35,1.25,.3),'wood',.07)
for x in [-.48,.48]:box(r,'Mortar cheeks',(x,0,.5),(.2,.85,.60),'darkwood',.06)
tube(r,'Mortar barrel',(0,.22,.43),.39,1.0,(0,-.65,.76))
for x in [-.58,.58]:cyl(r,'Mount pin',(x,0,.65),.12,.15,'steel',10).rotation_euler.y=math.pi/2
r=asset('harpoon-launcher','Harpoon Launcher','equipment')
box(r,'Launcher foot',(0,0,.10),(1.0,1.2,.20),'wood');cyl(r,'Swivel pivot',(0,0,.52),.18,.65,'iron')
beam(r,'Launcher stock',(0,.75,.97),(0,-.95,1.18),.15,'endgrain')
line(r,'Bow limbs',[(-.85,-.53,1.17),(-.45,-.84,1.19),(0,-.90,1.20),(.45,-.84,1.19),(.85,-.53,1.17)],.07,'wood')
line(r,'Bowstring',[(-.85,-.53,1.17),(0,.35,1.03),(.85,-.53,1.17)],.025,'cream')
beam(r,'Harpoon shaft',(0,.45,1.10),(0,-1.5,1.35),.055,'steel')
head=cyl(r,'Harpoon head',(0,-1.62,1.37),.12,.35,'steel',4,top=0);head.rotation_euler.x=math.pi/2
for i in range(3):torus(r,'Tow rope',(0,.20,.22+i*.055),.30,.035,'cream')
r=asset('repair-bench','Ship Repair Bench','equipment')
box(r,'Workbench',(0,0,.78),(1.5,.8,.16),'endgrain')
for x in [-.6,.6]:
 for y in [-.26,.26]:box(r,'Bench leg',(x,y,.36),(.12,.12,.72),'wood')
beam(r,'Hammer handle',(-.35,0,.9),(.15,.25,.9),.06,'wood');box(r,'Hammer head',(.19,.27,.9),(.22,.12,.12),'iron')
for i in range(3):box(r,'Repair planks',(-.1,.08,.2+i*.09),(1.0,.50,.07),'wood')
line(r,'Spare rope',[(-.5,-.5,.03),(-.6,-.7,.03),(-.2,-.85,.03),(.1,-.65,.03),(-.15,-.48,.03)],.04,'cream',True)
r=asset('cargo-rack','Secured Cargo Rack','equipment')
box(r,'Cargo skid',(0,0,.08),(1.7,1.3,.16),'darkwood')
for x in [-.8,.8]:
 for y in [-.6,.6]:beam(r,'Rack upright',(x,y,.1),(x,y,1.20),.10,'wood')
crate(r,(-.43,0,.15),.65);barrel(r,(.4,0,.15),.8)
for x in [-.8,.8]:line(r,'Cargo lash',[(x,-.6,.2),(x,-.6,1.22),(x,.6,1.22),(x,.6,.2)],.035,'cream')

r=asset('food-crate','Food Crate','props');crate(r,(0,0,0),.9,'fruit')
r=asset('ore-crate','Ore Crate','props');crate(r,(0,0,0),.9,'steel')
r=asset('gold-sacks','Gold Sacks','props')
for x,y,s in [(-.35,0,.45),(.35,.1,.38),(0,.5,.32)]:
 ball(r,'Canvas sack',(x,y,s*.7),(s,s*.8,s*.8),'sand',2);cyl(r,'Sack tie',(x,y,s*1.35),.12,.13,'darkwood',9)
for i in range(7):cyl(r,'Loose gold coin',(-.3+(i%4)*.17,-.52+(i//4)*.14,.055),.085,.045,'gold',10)
r=asset('cannonball-rack','Cannonball Rack','props')
box(r,'Shot tray',(0,0,.075),(1.3,.9,.15),'wood')
for row in range(2):
 for col in range(3):ball(r,'Cannon shot',(-.4+col*.4,-.21+row*.42,.3),.19,'iron',2)
for col in range(2):ball(r,'Upper shot',(-.2+col*.4,0,.55),.19,'iron',2)
r=asset('capture-standard','Capture Standard','props')
cyl(r,'Capture base',(0,0,.15),.52,.3,'stone',8);cyl(r,'Standard pole',(0,0,1.9),.055,3.4,'wood',10)
verts=[(0,0,3.45),(1.2,.12,3.45),(1.0,.08,3.08),(1.2,0,2.70),(0,0,2.70)]
mesh=bpy.data.meshes.new('Pennant');mesh.from_pydata(verts,[],[(0,1,2,3,4)]);mesh.materials.append(M['teal']);ob=bpy.data.objects.new('Faction pennant',mesh);r.users_collection[0].objects.link(ob);ob.parent=r
ball(r,'Flag finial',(0,0,3.65),.10,'gold',2)

# Presentation is separate from the asset origins and exports.
def setup(scene):
 scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
 scene.render.resolution_x=1800;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
 scene.world=bpy.data.worlds.new(scene.name+' world');scene.world.use_nodes=True
 scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.3,.45,.55,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.5
 scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast'
 for name,at,power,size in [('Key',(-25,-35,55),48000,40),('Fill',(30,20,45),28000,45)]:
  d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size;o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=at;o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler()
 c=bpy.data.collections.new(scene.name+' presentation');scene.collection.children.link(c);r=bpy.data.objects.new('Presentation',None);c.objects.link(r)
 box(r,'Backdrop',(0,0,-.3),(250,250,.2),'board',0)
 return r

def instance(scene,name,at):
 ob=bpy.data.objects.new(name+' display',None);scene.collection.objects.link(ob);ob.instance_type='COLLECTION';ob.instance_collection=assets[name][0];ob.location=at;return ob

def camera(scene,name,target,scale,az=-65,el=40):
 a,e=math.radians(az),math.radians(el);d=bpy.data.cameras.new(name);d.type='ORTHO';d.ortho_scale=scale
 o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=Vector(target)+Vector((math.cos(a)*math.cos(e),math.sin(a)*math.cos(e),math.sin(e)))*80;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();scene.camera=o;return o

present=setup(CAT)
for i,rec in enumerate(records):
 x=(i%5-2)*7.2;y=(2-i//5)*9
 instance(CAT,rec['id'],(x,y,.1));box(present,'Asset plinth',(x,y,0),(6.2,5.5,.2),'black',.12);text(present,rec['title'].upper(),(x,y-3.25,.01),.27)
camera(CAT,'Catalog camera',(0,4,1.5),54,-70,53)
scenes=[(CAT,'asset-catalog')]
for n,(category,title,spacing,scale) in enumerate([('resource','Resource Buildings',6.1,29),('harbor','Harbor Scenery',6,43),('equipment','Ship Equipment',3.7,21),('props','Resource Props',2.9,16)]):
 scene=bpy.data.scenes.new('%02d • %s'%(n+2,title));pr=setup(scene)
 group=[rec for rec in records if rec['category']==category]
 for i,rec in enumerate(group):
  x=(i-(len(group)-1)/2)*spacing;instance(scene,rec['id'],(x,0,.1));box(pr,'Display plinth',(x,0,0),(spacing-.35,4.9 if category in ['resource','harbor'] else 2.5,.2),'black',.08)
  text(pr,rec['title'].upper(),(x,-2.9 if category in ['resource','harbor'] else -1.6,.01),.22 if category in ['resource','harbor'] else .16)
 camera(scene,category+' camera',(0,0,1.5 if category in ['resource','harbor'] else .8),scale,-75,32)
 scenes.append((scene,category))
# Use a temporary scene containing just one asset per export.
export_scene=bpy.data.scenes.new('Export scratch')
for name,(collection,r) in assets.items():
 bpy.context.window.scene=export_scene;export_scene.collection.children.link(collection)
 bpy.ops.object.select_all(action='SELECT');bpy.context.view_layer.objects.active=r
 bpy.ops.export_scene.gltf(filepath=str(OUT/'models'/(name+'.glb')),use_selection=True,use_active_scene=True,export_format='GLB',export_animations=False,export_apply=True)
 export_scene.collection.children.unlink(collection)
bpy.context.window.scene=CAT;bpy.data.scenes.remove(export_scene)
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':area.spaces.active.shading.type='MATERIAL';area.spaces.active.overlay.show_overlays=False;area.spaces.active.region_3d.view_perspective='CAMERA'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Pirate_Expansion_Library.blend'))
for scene,name in scenes:
 bpy.context.window.scene=scene;scene.render.resolution_y=1450 if scene==CAT else 1100;scene.render.filepath=str(OUT/'renders'/(name+'.png'));bpy.ops.render.render(write_still=True);print('EXPANSION_RENDER',name,flush=True)
manifest={'status':'Original supplementary art for review; not engine integrated','style_reference':'Kenney Pirate Kit 2.1','geometry':'All twenty supplementary assemblies are newly modeled; no Kenney mesh geometry is copied in this pack. The separate water study uses existing approved review assets.','units':'meters; GLB Y-up; Blender Z-up','assets':records}
for rec in records:
 p=OUT/'models'/(rec['id']+'.glb');rec['bytes']=p.stat().st_size;rec['sha256']=hashlib.sha256(p.read_bytes()).hexdigest()
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2));print('EXPANSION_COMPLETE',len(records),flush=True)
