// include instead of use, so we get the pitch
include <gridfinity_constants.scad>
use <module_gridfinity.scad>

iBaseplateTypeSettings_SupportsMagnets = true;

//This should be a function and should match the cup function
function magnet_position(magnetDiameter, pitch = gf_pitch) = min(pitch/2-8, pitch/2-4-magnetDiameter/2);
  
function lookupKey(dictionary, key, default=undef) = let(results = [
  for (record = dictionary)
  if (record[0] == key)
  record
]) is_undef(results) || !is_list(results) 
  ? default 
  : results[0][1];

function retriveConnectorConfig(connector, default = undef) = lookupKey(connectorSettings,connector,default);
function retriveConnectorSetting(connector, iSetting, default = -1) = let(
  config = retriveConnectorConfig(connector),
  settingValue = config == undef ? default 
    : lookupKey(config, iSetting, default=default)
  ) 
   settingValue == undef 
    ? default 
    : settingValue;
    
function bitwise_and(v1, v2, bv = 1) = 
   assert(is_num(v1), "v1 must be a number")
   assert(is_num(v2), "v2 must be a number")
   assert(is_num(bv), "bv must be a number")
      ((v1 + v2) == 0) ? 0
     : (((v1 % 2) > 0) && ((v2 % 2) > 0)) ?
       bitwise_and(floor(v1/2), floor(v2/2), bv*2) + bv
     : bitwise_and(floor(v1/2), floor(v2/2), bv*2);
     
function decimaltobitwise(v1, v2) = 
   assert(is_num(v1), "v1")
   assert(is_num(v2), "v2")
   v1==0 && v2 == 0 ? 1 : 
      v1==0 && v2 == 1 ? 2 :
      v1==1 && v2 == 0 ? 4 :
      v1==1 && v2 == 1 ? 8 : 0;  

module frame_plain(
    num_x, 
    num_y, 
    center_fill_grid_x = false,
    center_fill_grid_y = false,
    extra_down=0, 
    trim=0, 
    baseTaper = 0, 
    height = 4,
    cornerRadius = gf_cup_corner_radius,
    reducedWallHeight = 0,
    roundedCorners = 15,
    $fn = 44) {
  frameLipHeight = extra_down > 0 ? height -0.6 : height;
  
  difference() {
    color(color_cup)
    //full outer material to build from
    outer_baseplate(
      num_x=num_x, 
      num_y=num_y, 
      extendedDepth=extra_down,
      trim=trim, 
      height=frameLipHeight,
      cornerRadius = cornerRadius,
      roundedCorners = roundedCorners);
    //Wall reduction
    echo("frame_plain", num_x=num_x, num_y=num_y);
    
    frame_cavity(
      num_x=num_x, 
      num_y=num_y, 
      center_fill_grid_x = center_fill_grid_x,
      center_fill_grid_y = center_fill_grid_y,
      extra_down = extra_down, 
      frameLipHeight = frameLipHeight,
      cornerRadius = cornerRadius,
      reducedWallHeight = reducedWallHeight,
      $fn = 44)
        children();
  }
}

module frame_cavity(
    num_x, 
    num_y, 
    center_fill_grid_x = false,
    center_fill_grid_y = false,
    extra_down=0, 
    frameLipHeight = 4,
    cornerRadius = gf_cup_corner_radius,
    reducedWallHeight = 0,
    $fn = 44) {
  frameWallReduction = reducedWallHeight > 0 ? max(0, frameLipHeight-reducedWallHeight) : 0;
    translate([0, 0, -fudgeFactor]) 
      gridcopy(
        num_x, 
        num_y,
        centerGridx = center_fill_grid_x,
        centerGridy = center_fill_grid_y) {
        echo("frame_plain", gci=$gci, gc_size=$gc_size, gc_position=$gc_position);
      if(frameWallReduction>0)
        for(side=[[0, [$gc_size.x, $gc_size.y]*gf_pitch],[90, [$gc_size.y, $gc_size.x]*gf_pitch]]){
        if(side[1].x >= gf_pitch/2)
         translate([$gc_size.x/2*gf_pitch,$gc_size.y/2*gf_pitch,frameLipHeight])
         rotate([0,0,side[0]])
          WallCutout(
            lowerWidth=side[1].x-15,
            wallAngle=80,
            height=frameWallReduction,
            thickness=side[1].y+fudgeFactor*2,
            cornerRadius=frameWallReduction,
            topHeight=1,
            $fn = 64);
          }
          
        pad_oversize(
          margins=1,
          extend_down=extra_down,
          $gc_size.x,
          $gc_size.y)
              children();
  }
}

module baseplate_cavities(
  num_x, 
  num_y,  
  baseCavityHeight,
  magnetSize = [gf_baseplate_magnet_od,gf_baseplate_magnet_thickness],
  magnetSouround = true,
  centerScrewEnabled = false,
  cornerScrewEnabled = false,
  weightHolder = false,
  cornerRadius = gf_cup_corner_radius,
  roundedCorners = 15) {

  assert(is_num(num_x) && num_x >= 0 && num_x <=1, "num_x must be a number between 0 and 1");
  assert(is_num(num_y) && num_y >= 0 && num_y <=1, "num_y must be a number between 0 and 1");
  assert(is_num(baseCavityHeight), "baseCavityHeight must be a number");
  
  
    overSize = 1;
    minFloorThickness = 1;
    counterSinkDepth = 2.5;
    screwDepth = counterSinkDepth+3.9;
    screwOuterChamfer = 8.5;
    weightDepth = 4;
  
    magnet_position = magnet_position(magnetSize[0]);
    magnetborder = 5;
    
    _centerScrewEnabled = centerScrewEnabled && num_x >= 1 && num_y >=1;
    _weightHolder = weightHolder && num_x >= 1 && num_y >=1;
    
    translate([gf_pitch/2,gf_pitch/2])
    union(){
      gridcopycorners(r=magnet_position, num_x=num_x, num_y=num_y, center= true) {
        translate([0, 0, baseCavityHeight-magnetSize[1]-fudgeFactor*3]) 
        cylinder(d=magnetSize[0], h=magnetSize[1]+fudgeFactor*2, $fn=48);

        // counter-sunk holes in the bottom
        if(cornerScrewEnabled){
          cylinder(d=3.5, h=baseCavityHeight, $fn=24);
          translate([0, 0, -fudgeFactor]) 
            cylinder(d1=8.5, d2=3.5, h=counterSinkDepth, $fn=24);
        }
      }
      
      if(_weightHolder){
        translate([-10.7, -10.7, -fudgeFactor]) 
          cube([21.4, 21.4, weightDepth + 0.01]);
          
         for (a2=[0,90]) {
          rotate([0, 0, a2])
          hull() 
            for (a=[0, 180]) 
              rotate([0, 0, a]) 
              translate([-14.9519, 0, -fudgeFactor])
                cylinder(d=8.5, h=2.01, $fn=24);
        }
      }
      
      if(_centerScrewEnabled)
      {
        //counter-sunk holes for woodscrews
        union(){
          translate([0, 0, baseCavityHeight-counterSinkDepth]) 
            cylinder(d1=3.5, d2=8.5, h=counterSinkDepth, $fn=24);
          translate([0, 0, -fudgeFactor]) 
            cylinder(d=3.5, h=baseCavityHeight, $fn=24);
        }
      }
      
      if(magnetSouround && !_centerScrewEnabled && !_weightHolder){
        supportDiameter = max(
          cornerScrewEnabled ? 8.5 : 0,
          magnetSize[0]) + magnetborder;

        difference(){
          translate([-gf_pitch/2,-gf_pitch/2,0])
            cube([gf_pitch,gf_pitch,baseCavityHeight]);
          
          translate([0, 0, -fudgeFactor*2]) 
          gridcopycorners(r=magnet_position, num_x=num_x, num_y=num_y, center= true) {
            rdeg =
              $gcci[2] == [ 1, 1] ? 90 :
              $gcci[2] == [-1, 1] ? 180 :
              $gcci[2] == [-1,-1] ? -90 :
              $gcci[2] == [ 1,-1] ? 0 : 0;
            rotate([0,0,rdeg])
              //magnet retaining ring
              union(){
              echo(magnetSupportWidth=magnetSupportWidth, supportDiameter=supportDiameter, minus4=-supportDiameter/4);
                magnetSupportWidth = max(17/2,supportDiameter);
                cylinder(d=supportDiameter, h=baseCavityHeight+fudgeFactor*4, $fn=48);

                translate([magnetSupportWidth/2, -magnetSupportWidth/2+supportDiameter/2, baseCavityHeight/2]) 
                  cube([magnetSupportWidth,magnetSupportWidth,baseCavityHeight+fudgeFactor*6],center = true);

                translate([magnetSupportWidth/2-supportDiameter/2, -magnetSupportWidth/2, baseCavityHeight/2]) 
                  cube([magnetSupportWidth,magnetSupportWidth,baseCavityHeight+fudgeFactor*6],center = true);
              }
            }
        }
      }
    }
}

module outer_baseplate(
  num_x, 
  num_y, 
  height = 4,
  baseTaper = 0, 
  extendedDepth = 0,
  trim=0, 
  cornerRadius = gf_cup_corner_radius,
  roundedCorners = 15){
    
  assert(is_num(num_x), "num_x must be a number");
  assert(is_num(num_y), "num_y must be a number");
  assert(is_num(height), "height must be a number");
  assert(is_num(baseTaper), "baseTaper must be a number");
  assert(is_num(extendedDepth), "extendedDepth must be a number");
  assert(is_num(trim), "trim must be a number");
  assert(is_num(cornerRadius), "cornerRadius must be a number");
  assert(is_num(roundedCorners), "roundedCorners must be a number");
  
    fudgeFactor = 0.01;
  corner_position = gf_pitch/2-cornerRadius-trim;
 //full outer material to build from
  hull() 
    cornercopy(corner_position, num_x, num_y) {
      radius = bitwise_and(roundedCorners, decimaltobitwise($idx[0],$idx[1])) > 0 ? cornerRadius : 0.01;// 0.01 is almost zero....
      ctrn = [
        ($idx[0] == 0 ? -1 : 1)*(cornerRadius-radius), 
        ($idx[1] == 0 ? -1 : 1)*(cornerRadius-radius), -extendedDepth];
      translate(ctrn)
      union(){
        translate([0, 0, baseTaper])
          cylinder(r=radius, h=height+extendedDepth-baseTaper);
        cylinder(r2=radius,r1=baseTaper, h=baseTaper+fudgeFactor);
      }
    }
}