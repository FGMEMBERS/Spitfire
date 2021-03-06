# $Id: spitfire.nas,v 1.16 2009/01/07 17:49:48 vmmeazza Exp $

# =============================== DEFINITIONS ===========================================

# set the update period

UPDATE_PERIOD = 0.3;

# set the timer for the selected function

registerTimer = func {

    settimer(arg[0], UPDATE_PERIOD);

} # end function 

#does what it says on the tin
var clamp = func(v, min, max) { v < min ? min : v > max ? max : v }

#conversion hours to sec
var hr2sec = 3600;
# =========================== end  DEFINITIONS ===========================================

#========================= Initialize ===============================
#
# Make sure all needed properties are present and accounted 
# for, and that they have sane default values.



var countNode    = props.globals.getNode("ai/submodels/submodel[1]/count", 1);
var count_1_Node = props.globals.getNode("ai/submodels/submodel[3]/count", 1);
var count_2_Node = props.globals.getNode("ai/submodels/submodel[5]/count", 1);
var count_3_Node = props.globals.getNode("ai/submodels/submodel[7]/count", 1);
var count_4_Node = props.globals.getNode("ai/submodels/submodel[9]/count", 1);
var count_5_Node = props.globals.getNode("ai/submodels/submodel[11]/count", 1);

props.globals.initNode("/sim/rendering/dirt-factor[2]", 0.0, "DOUBLE");
props.globals.initNode("/sim/rendering/dirt-factor[3]", 0.0, "DOUBLE");
props.globals.initNode("/controls/flight/buffet", 0.0, "DOUBLE");
props.globals.initNode("/surface-positions/flap-pos-norm", 0.0, "DOUBLE");

var type = getprop("sim/aircraft");

var hobbs_engine = aircraft.timer.new("sim/time/hobbs/engine[0]", 60, 0);
var hobbs_airframe = aircraft.timer.new("sim/time/hobbs/" ~ type ~ "/airframe[0]", 900, 1);	
var engine_running_Node = props.globals.initNode("engines/engine[0]/running", 1, "BOOL");
var flying_Node = props.globals.initNode("gear/gear/wow", 1, "BOOL");

# =============== Variables ================

var rnd_wt_lbs     = 0.286600941; #20mm cannon
var rnd_wt_303_lbs = 0.068272184; #.303 MG

var ammo_wt = [0,0,0,0,0,0];
var count   = [0,0,0,0,0,0];

var spitfireIIa = 0;

#var type = "";

var initialize = func {

    print( "Initializing Spitfire utilities ..." );


    setprop("sim/model/position/latitude-deg", getprop("position/latitude-deg"));
    setprop("sim/model/position/longitude-deg", getprop("position/longitude-deg"));
    setprop("sim/model/position/altitude-ft", getprop("position/altitude-ft"));
    setprop("controls/gear/gear-lever", 0);
    setprop("controls/gear/oil-flow", 0);
    

# =============== initialize ==========================

    controls.fullBrakeTime = 0;
    rain();
    tyresmoke();
#    aircraft.steering.init();
#        ammo();

# initialise Hobbs meter
    hobbs_engine.reset();
	updateBuffet(); 


# ======== set the aircraft type =================

        if (type == "spitfireIIa") {spitfireIIa = 1;}

        print ("type: " , type );


# ============ listeners ==========================

    setlistener( "controls/lighting/nav-lights", func {
        var nav_lights_node = props.globals.getNode("controls/lighting/nav-lights", 1);
        var generic_node = props.globals.getNode("sim/multiplay/generic/int[0]", 1);
        generic_node.setIntValue(nav_lights_node.getValue());
#        print("nav_lights ", nav_lights_node.getValue(), "generic_node ", generic_node.getValue());
    }
    ); 

    setlistener("gear/gear[0]/position-norm", func {
        var gear = getprop("gear/gear[0]/position-norm");

        if (gear == 1 ){
            run_tyresmoke0 = 1;
        }else{
            run_tyresmoke0 = 0;
        }

    },
        1,
        0);

    setlistener("gear/gear[1]/position-norm", func {
        var gear = getprop("gear/gear[1]/position-norm");

        if (gear == 1 ){
            run_tyresmoke1 = 1;
        }else{
            run_tyresmoke1 = 0;
        }

    },
        1,
        0);

    setlistener("gear/gear[2]/position-norm", func {
        var gear = getprop("gear/gear[2]/position-norm");

        if (gear == 1 ){
            run_tyresmoke2 = 1;
        }else{
            run_tyresmoke2 = 0;
        }

    },
        1,
        0);

    setlistener("controls/gear/gear-down", func (n){
        var gear_control = n.getValue();

        if (gear_control == 0) {
            gear_lever = -1;
        } else {
            gear_lever = 1;
        }

        run_gear();

    },
        0,
        0);

    setlistener("gear/canopy/position-norm", func (n){
        var canopy_pos = n.getValue();
        var canopy_slide = getprop("controls/flight/canopy-slide");

        if (canopy_pos == 0 or canopy_pos == 1) {
            setprop("/controls/flight/canopy-lever", 0);
        } elsif (canopy_slide == 0){
            setprop("/controls/flight/canopy-lever", -1);
        } else {
            setprop("/controls/flight/canopy-lever", 1);
        }

#        print ("controls/flight/canopy-lever ", getprop("/controls/flight/canopy-lever"));
#        print ("controls/flight/canopy-slide ", getprop("/controls/flight/canopy-slide"));
#        print ("gear/canopy/position-norm ", getprop("/gear/canopy/position-norm"));
    },
        0,
        0);

    setlistener( "engines/engine/cranking", func {updateSmoking()},
        0,
        0);

    setlistener( "engines/engine/running", func {updateSmoking()},
        0,
        0);

    setlistener("/systems/pneumatic/outputs/trigger-gun", func {ammo()},
        1,
        0); # end listener

# set it all running on the next update cycle
        settimer(update, 0);

        print(" ... done");


} #end func init

# ==== this is the Main Loop which keeps everything updated ========================

var update = func {
    updateBoostControl();
    rain();
    tyresmoke();
    updatePilotG();
    updateHobbs();
    headShake();

    var hobbs = getprop("sim/time/hobbs/engine[0]");
    var dirt_factor = clamp(hobbs*0.9/(0.5 * hr2sec), 0.0, 0.9);
    setprop("/sim/rendering/dirt-factor", dirt_factor);

    hobbs = getprop("sim/time/hobbs/" ~ type ~ "/airframe[0]");
    dirt_factor = clamp(hobbs*0.75/(1.0 * hr2sec), 0.0, 0.6);
    setprop("/sim/rendering/dirt-factor[1]", dirt_factor);

    hobbs = getprop("sim/time/hobbs/" ~ type ~ "/airframe[0]");
    dirt_factor = clamp(-0.3 - hobbs*0.3/(1.0 * hr2sec), -0.8, -0.3);
    setprop("/sim/rendering/refl-correction", dirt_factor);

	registerTimer(update, 0);

	}# end func update (main loop) 


# ========================== Buffet stuff======================================

	updateBuffet = func {
		
		var alpha = getprop("/orientation/alpha-deg");
		var flap = getprop("/surface-positions/flap-pos-norm");
		var speed = getprop("/velocities/airspeed-kt");
		var buffet = 0;
		var factor = 0;

		if (alpha <= 14.0 and flap < 0.9 ){
			buffet = 0;	
#print ("flap up");
		} elsif (alpha <= 9.0 and flap >= 0.9 ){
			buffet = 0;
#print ("flap down");
		} elsif (speed <= 35.0){
			buffet = 0;
#print ("speed");
		} else {
#			print ("buffet");
			factor = clamp(alpha * 0.05, 0.5, 1.0);
            buffet = (-factor + 2.0 * factor * rand());
		}

		interpolate("/controls/flight/buffet", buffet, 0.125);
		settimer(updateBuffet, 0.125);

}# end func updateBuffet 


# ========================== Boost Controller stuff======================================

BOOST_CONTROL_AUTHORITY = 0.99; # How much can it move the throttle?
#BOOST_CONTROL_RANGE = 1;         When does it start to engage? (psig)
BOOST_CONTROL_LIMIT_RATED = 9;        # Rated Maximum MP  (psi gauge) (1 hr)
BOOST_CONTROL_LIMIT_COMBAT = 12.5;    # Combat limit (5 mins)

if (type == "seafireIIIc") {BOOST_CONTROL_LIMIT_COMBAT = 16.0;}  

boost_control = props.globals.getNode("/controls/engines/engine/boost-control", 1);
boost_pressure = props.globals.getNode("/engines/engine/boost-gauge-inhg", 1);
boost_pressure_psi = props.globals.getNode("/engines/engine/boost-gauge-psi", 1);
boost_control_damp = props.globals.getNode("/controls/engines/engine/boost-control-damp", 1);
boost_control_range = props.globals.getNode("/controls/engines/engine/boost-control-range", 1);
boost_control_cutout = props.globals.getNode("/controls/engines/engine/boost-control-cutout", 1);
throttle = props.globals.getNode("/controls/engines/engine/throttle", 1);
mp_inhg = props.globals.getNode("/engines/engine/mp-inhg", 1);

boost_control.setDoubleValue(1); 
boost_pressure.setDoubleValue(0); 
boost_pressure_psi.setDoubleValue(0); 
boost_control_damp.setDoubleValue(0.015); 
boost_control_range.setDoubleValue(0.5); 
boost_control_cutout.setBoolValue(0); 
mp_inhg.setDoubleValue(0);

damp = 0;

toggleCutout = func{
    var t = throttle.getValue();
    var c = boost_control_cutout.getValue();

    if ( t != 1){
        c = !c;
        boost_control_cutout.setBoolValue(c);
    } 	    
#	print("c: " , c );

} # end function toggleCutout

updateBoostControl = func {
    var n = boost_control_damp.getValue(); 
    var BOOST_CONTROL_RANGE = boost_control_range.getValue();
    var mp = (mp_inhg.getValue() * 0.491154077497) - 14.6959487755 ;
    var cutout = boost_control_cutout.getValue();
    var throttle = throttle.getValue();
    var val = 0;

    if (throttle == 1 and !cutout){
        cutout = 1;
    }

    if(! cutout){
        val = (mp - BOOST_CONTROL_LIMIT_RATED) / BOOST_CONTROL_RANGE;
    } else {
        val = (mp - BOOST_CONTROL_LIMIT_COMBAT) / BOOST_CONTROL_RANGE;
    }	

    var in = val;

    if (val < 0  ) {
        val = 0;                             # Can't increase throttle
    } elsif (val < -BOOST_CONTROL_AUTHORITY) {
        val = -BOOST_CONTROL_AUTHORITY        # limit by authority
    } else {
        val = -val;
        }

        damp = (val * n) + (damp * (1 - n)); # apply low pass filter

#	print(sprintf("mp=%0.5f, in=%0.5f, raw=%0.5f, out=%0.5f", mp, in, val, damp));
            boost_pressure_psi.setDoubleValue(mp);
        boost_control.setDoubleValue(damp);
        boost_control_cutout.setBoolValue(cutout);
#        settimer(updateBoostControl, 0.0);
}

updateBoostControl();

# =================================== end Boost Controller f ============================

# ========================= Coffman starter stuff =======================================


nowN       = props.globals.getNode("/sim/time/elapsed-sec", 1);
starterN   = props.globals.getNode("controls/engines/engine/starter", 1);
primerN    = props.globals.getNode("engines/engine/primer", 1);
cartridgeN = props.globals.getNode("controls/engines/engine/coffman-starter/index");
LastStartTime = 0;
LastCartridge = -1;
Start = 0;		# stopCof needs this, too


indexCof = func{
	pull=arg[0];
	if(pull) {
#        i = getprop("controls/engines/engine/coffman-starter/index");
		i = cartridgeN.getValue();
		i = i - 1;
		if (i == -1) {
			i = 5;
		}
		setprop("controls/engines/engine/coffman-starter/index",i);
		setprop("controls/engines/engine/coffman-starter/index-pull-norm",1)
	}else{
		setprop("controls/engines/engine/coffman-starter/index-pull-norm",0)
	}

} # end function


startCof = func{
	Start = arg[0];
	max_run = 5.5;

	if (Start) {
		LastStartTime = nowN.getValue();
		if (!starterN.getValue()) { 			# not started yet: do it now
			setprop("controls/engines/engine/coffman-starter/starter-push-norm", 1);

		ready = !spitfire.spitfireIIa;		# seafires are always ready

			if (!ready) {						# must be a spitfire
				LastCartridge = cartridgeN.getValue();

		j = "controls/engines/engine/coffman-starter/cartridge[" ~ LastCartridge ~ "]";

		if (ready = getprop(j)) {
			setprop(j, 0);
#					print("max run: " , max_run);
			settimer(func {             # nameless out-of-gas watcher
				starterN.setValue(0);
			primerN.setValue(0);
#			print ("starter stopping, out of gas!"); 
				}, max_run)};
				}

			if (ready) {
				fuel.primerMixture(primerN.getValue());
				starterN.setValue(1);
#				print ("starter running!");
				}
			}
		} else{
			settimer(stopCof, 0.2);
		}
} # end function


stopCof = func {

	min_run = 4.5;

	if (!Start and starterN.getValue()) {
		if (nowN.getValue() - LastStartTime < min_run) {
			starterN.setValue(1);
			settimer(stopCof, 0.2);			# too soon; let's try again later
#			print ("too soon! min run: " , min_run);
		} else {
			primerN.setValue(0);
			starterN.setValue(0);
			setprop("controls/engines/engine/coffman-starter/starter-push-norm", 0);
#			print ("starter stopping!");
		}
	}
} # end function

# ======================= end Coffman starter stuff =====================================
# ============================= magneto stuff ===========================================

	setMagnetos = func{     # set the magneto value according to the switch positions

	right = getprop("controls/engines/engine/mag-switch-right");
left = getprop("controls/engines/engine/mag-switch-left");
if (left and right){                                 # both
	setprop("controls/engines/engine/magnetos",3); 
}
elsif (left and !right) {                         # left
	setprop("controls/engines/engine/magnetos",1)
}
elsif (!left and right) {                         # right
	setprop("controls/engines/engine/magnetos",2)
}
else{    
	setprop("controls/engines/engine/magnetos",0); # none
}

} # end function

	setleftMagswitch = func{

		left = arg[0];
		setprop("controls/engines/engine/mag-switch-left",left);
		spitfire.setMagnetos();

} # end function


	setrightMagswitch = func{

		right = arg[0];
		setprop("controls/engines/engine/mag-switch-right",right);
		spitfire.setMagnetos();

} # end function


	toggleleftMagswitch = func{

		left = getprop("controls/engines/engine/mag-switch-left");
		left = !left;
		setprop("controls/engines/engine/mag-switch-left",left);
		spitfire.setMagnetos();

} # end function

	togglerightMagswitch = func{

		right = getprop("controls/engines/engine/mag-switch-right");
		right = !right;
		setprop("controls/engines/engine/mag-switch-right",right);
		spitfire.setMagnetos();

} # end function

# =========================== end magneto stuff =========================================

# ================================== door and canopy stuff ==============================

openDoor = func{ 
# open the door if canopy is open
    dooropen = arg[0];
    canopyopen = getprop("gear/canopy/position-norm");
    if (canopyopen) {
        setprop("controls/flight/door-position-norm",dooropen)
    }

} # end function

toggleDoor = func{ 
# toggle the door if canopy is open
    dooropen = getprop("controls/flight/door-position-norm");
    canopyopen = getprop("gear/canopy/position-norm");

    if (canopyopen) {
        dooropen = !dooropen;
        setprop("controls/flight/door-position-norm",dooropen);
    }

} # end function

openCanopy = func{ 
# open the canopy if door is closed
    canopyopen = arg[0];
    dooropen = getprop("controls/flight/door-position-norm");

    if (!dooropen) {
        setprop("controls/flight/canopy-slide",canopyopen);
    }

} # end function

# =============================== end door and canopy ===================================

# =================================== Cutoff ============================================

pullCutoff = func{

    pull=arg[0];
    mixturelever = getprop("controls/engines/engine/mixture-lever");

    if(pull) {
        setprop("controls/engines/engine/cutoff-pull-norm",1);
        setprop("controls/engines/engine/cutoff",0);
#setprop("controls/engines/engine/mixture",0);
        if (getprop("engines/engine/rpm") < 100) {setprop("engines/engine/running",0)}
    }else{
        setprop("controls/engines/engine/cutoff-pull-norm",0);
        setprop("controls/engines/engine/cutoff",1);
#setprop("controls/engines/engine/mixture",mixturelever)
    }

} # end function

# =============================== end Cutoff ============================================

# =================================== fuel tank stuff ===================================

# switch off fuel gauge

#setprop("controls/switches/fuel-gauge",0);

# operate fuel cocks

openCock=func{

    cock=arg[0];
    open=arg[1];
    if (cock == 0){

#setprop("controls/engines/engine/fuel-cock/lever-norm[0]",open);
        setprop("consumables/fuel/tank[0]/selected",open)
    }
    else
    {
#setprop("controls/engines/engine/fuel-cock/lever-norm[1]",open);
        setprop("consumables/fuel/tank[1]/selected",open)
    }

}#end func

# toggle fuel cocks

toggleCock=func{

    cock=arg[0];

    if (cock == 0){
#open = getprop("controls/engines/engine/fuel-cock/lever-norm[0]");
#open = !open;
#setprop("controls/engines/engine/fuel-cock/lever-norm[0]",open);
        open = getprop("consumables/fuel/tank[0]/selected");
        open = !open;
        setprop("consumables/fuel/tank[0]/selected",open)
    }
    else
    {
#open = getprop("controls/engines/engine/fuel-cock/lever-norm[1]");
#open = !open;
#setprop("controls/engines/engine/fuel-cock/lever-norm[1]",open);
        open = getprop("consumables/fuel/tank[1]/selected");
        open = !open;
        setprop("consumables/fuel/tank[1]/selected",open)
    }

}#end func


# ========================== end fuel stuff ======================================

# =========================== flap stuff =========================================

flapLever = func{                         #sets the flap lever up or down

down = arg[0];

interpolate("controls/flight/flaps-lever", down, 1.0 );
#if (down) {registerTimer(flapBlowin)}                        # run the timer

} # end function 

flapBlowin = func{
    flap = 0;
    lever = getprop("controls/flight/flaps-lever");
    airspeed = getprop("velocities/airspeed-kt");
#print("lever: " , lever , " airspeed (kts): " , airspeed);

    if (lever and airspeed < 105 ) { 
        controls.stepProps("/controls/flight/flaps", "/sim/flaps",1);                                # full flap
            return registerTimer(flapBlowin);                        # run the timer                
    }
    elsif (lever and airspeed >= 105 and airspeed <= 115) {
        flap = -0.08 * airspeed + 9.4;
#print("flap: " , flap);
        setprop("controls/flight/flaps", flap);            # flap partially blown in     
            return registerTimer(flapBlowin);                    # run the timer                        
    }
    elsif (lever and airspeed > 115) {
        flap = 0.2;
        setprop("controls/flight/flaps", flap);            # flap blown in                                         
            return registerTimer(flapBlowin);                    # run the timer
    }
    else
    {
        controls.stepProps("/controls/flight/flaps", "/sim/flaps",-1);                    # flap up, don't run the timer                    
    }

} # end function 

# =============================== end flap stuff =========================================

# =========================== gear warning stuff =========================================

toggleGearWarn = func{                                         # toggle the gear warning

cancel = getprop("sim/alarms/gear-warn");
cancel = !cancel;
#print("cancel :", cancel);
setprop("sim/alarms/gear-warn", cancel);
if (cancel) {registerTimer(resetWarn)}                    # run the timer

} # end function 

resetWarn = func{

    var throttle = getprop("controls/engines/engine/throttle");
    var gearwarn = getprop("sim/alarms/gear-warn");
#print("throttle " , throttle , " gearwarn: " , gearwarn);
    if (gearwarn and throttle >= 0.25 ) { 
        setprop("sim/alarms/gear-warn",0);                    # reset the gear warning
    } else {
        return registerTimer(resetWarn);                      # run the timer                
    }

} # end function 


# =========================== end gear warning stuff =========================================

# =============================== -ve g cutoff stuff =========================================

negGCutoff = func{

    g = getprop("accelerations/pilot-g");
    if (g == nil) { g = 0 };
    mixture = getprop("controls/engines/engine/mixture-lever");
    if (spitfireIIa) {
        if (g > 0.75) {
            return  mixture;                    # mixture set by lever
        }
        elsif (g <= 0.75 and g >= 0)  {            # mixture set by - ve g
            mixture = g * 4/3;
        }
        else  {                                    # mixture set by - ve g
            mixture = 0;
        }
    } 

#    print("g: " , g , " mixture: " , mixture);

    return mixture;

} # end function 

# =============================== end -ve g cutoff ==================================

# =============================== Pilot G stuff======================================

pilot_g = props.globals.getNode("accelerations/pilot-g", 1);
timeratio = props.globals.getNode("accelerations/timeratio", 1);
pilot_g_damped = props.globals.getNode("accelerations/pilot-g-damped", 1);

pilot_g.setDoubleValue(0);
pilot_g_damped.setDoubleValue(0); 
timeratio.setDoubleValue(0.03); 

g_damp = 0;

updatePilotG = func {
    var n = timeratio.getValue(); 
    var g = pilot_g.getValue() ;
#if (g == nil) { g = 0; }
    g_damp = ( g * n) + (g_damp * (1 - n));

    pilot_g_damped.setDoubleValue(g_damp);

# print(sprintf("pilot_g_damped in=%0.5f, out=%0.5f", g, g_damp));

#    settimer(updatePilotG, 0.1);

} #end updatePilotG()

updatePilotG();

# headshake - this is a modification of the original work by Josh Babcock

# Define some stuff with global scope

xConfigNode = '';
yConfigNode = '';
zConfigNode = '';

xAccelNode = '';
yAccelNode = '';
zAccelNode = '';

var xDivergence_damp = 0;
var yDivergence_damp = 0;
var zDivergence_damp = 0;

var last_xDivergence = 0;
var last_yDivergence = 0;
var last_zDivergence = 0;

# Make sure that some vital data exists and set some default values
enabledNode = props.globals.getNode("/sim/headshake/enabled", 1);
enabledNode.setBoolValue(1);

xMaxNode = props.globals.getNode("/sim/headshake/x-max-m",1);
xMaxNode.setDoubleValue( 0.025 );

xMinNode = props.globals.getNode("/sim/headshake/x-min-m",1);
xMinNode.setDoubleValue( -0.05 );

yMaxNode = props.globals.getNode("/sim/headshake/y-max-m",1);
yMaxNode.setDoubleValue( 0.025 );

yMinNode = props.globals.getNode("/sim/headshake/y-min-m",1);
yMinNode.setDoubleValue( -0.025 );

zMaxNode = props.globals.getNode("/sim/headshake/z-max-m",1);
zMaxNode.setDoubleValue( 0.025 );

zMinNode = props.globals.getNode("/sim/headshake/z-min-m",1);
zMinNode.setDoubleValue( -0.05 );

view_number_Node = props.globals.getNode("/sim/current-view/view-number",1);
view_number_Node.setDoubleValue( 0 );

time_ratio_Node = props.globals.getNode("/sim/headshake/time-ratio",1);
time_ratio_Node.setDoubleValue( 0.003 );

seat_vertical_adjust_Node = props.globals.getNode("/controls/seat/vertical-adjust",1);
seat_vertical_adjust_Node.setDoubleValue( 0 );

xThresholdNode = props.globals.getNode("/sim/headshake/x-threshold-m",1);
xThresholdNode.setDoubleValue( 0.02 );

yThresholdNode = props.globals.getNode("/sim/headshake/y-threshold-m",1);
yThresholdNode.setDoubleValue( 0.02 );

zThresholdNode = props.globals.getNode("/sim/headshake/z-threshold-m",1);
zThresholdNode.setDoubleValue( 0.02 );

# We will use these later
xConfigNode = props.globals.getNode("/sim/view/config/z-offset-m");
yConfigNode = props.globals.getNode("/sim/view/config/x-offset-m");
zConfigNode = props.globals.getNode("/sim/view/config/y-offset-m");

xAccelNode = props.globals.getNode("/accelerations/pilot/x-accel-fps_sec",1);
xAccelNode.setDoubleValue( 0 );
yAccelNode = props.globals.getNode("/accelerations/pilot/y-accel-fps_sec",1);
yAccelNode.setDoubleValue( 0 );
zAccelNode = props.globals.getNode("/accelerations/pilot/z-accel-fps_sec",1);
zAccelNode.setDoubleValue(-32 );


headShake = func {

# First, we don't shake outside the vehicle. Inside, we boogie down.
# There are two coordinate systems here, one used for accelerations, and one used for the viewpoint.
# We will be using the one for accelerations.
    var enabled = enabledNode.getValue();
    var view_number= view_number_Node.getValue();
    var n = timeratio.getValue(); 
    var seat_vertical_adjust = seat_vertical_adjust_Node.getValue();


    if ( (enabled) and ( view_number == 0)) {

        var xConfig = xConfigNode.getValue();
        var yConfig = yConfigNode.getValue();
        var zConfig = zConfigNode.getValue();

        var xMax = xMaxNode.getValue();
        var xMin = xMinNode.getValue();
        var yMax = yMaxNode.getValue();
        var yMin = yMinNode.getValue();
        var zMax = zMaxNode.getValue();
        var zMin = zMinNode.getValue();

#work in G, not fps/s
        var xAccel = xAccelNode.getValue()/32;
        var yAccel = yAccelNode.getValue()/32;
        var zAccel = (zAccelNode.getValue() + 32)/32; # We aren't counting gravity

            var xThreshold =  xThresholdNode.getValue();
        var yThreshold =  yThresholdNode.getValue();
        var zThreshold =  zThresholdNode.getValue();

# Set viewpoint divergence and clamp
# Note that each dimension has it's own special ratio and +X is clamped at 1cm
# to simulate a headrest.

#y = -0.0005x3 - 0.005x2 - 0.0089x - 0.0045
# -0.0004x3 + 0.0042x2 - 0.0084x + 0.0048
# -0.0004x3 - 0.0042x2 - 0.0084x - 0.0048
        if (xAccel < -5 ) {
            xDivergence = -0.03;
        } elsif ((xAccel < -0.5) and (xAccel >= -5)) {
            xDivergence = ((( -0.0005 * xAccel ) - ( 0.0036 )) * xAccel - ( 0.001 )) * xAccel - 0.0004;
        } elsif ((xAccel > 1) and (xAccel <= 6)) {
            xDivergence = ((( -0.0004 * xAccel ) + ( 0.0031 )) * xAccel - ( 0.0016 )) * xAccel + 0.0002;
        } elsif (xAccel > 5) {
            xDivergence = 0.02;
        } else {
            xDivergence = 0;
        }

#       These equations shape the output and convet from G number to divergence left/right in meters
#	y = -0.0005x3 - 0.0036x2 + 0.0001x + 0.0004
#	y = -0.013x3 + 0.125x2 - 0.1202x + 0.0272

        if (yAccel < -5 ) {
            yDivergence = -0.03;
        } elsif ((yAccel < -0.5) and (yAccel >= -5)) {
            yDivergence = ((( -0.005 * yAccel ) - ( 0.0036 )) * yAccel - (  0.0001 )) * yAccel - 0.0004;
        } elsif ((yAccel > 0.5) and (yAccel <= 5)) {
            yDivergence = ((( -0.013 * yAccel ) + ( 0.125 )) * yAccel - (  0.1202 )) * yAccel + 0.0272;
        } elsif (yAccel > 5) {
            yDivergence = 0.03;
        }else {
            yDivergence = 0;
        }

#        setprop("/sim/current-view/x-offset-m", (yConfig + yDivergence));	
# y = -0.0005x3 - 0.0036x2 + 0.0001x + 0.0004
# y = -0.0004x3 + 0.0031x2 - 0.0016x + 0.0002
        if (zAccel < -5 ) {
            zDivergence = -0.03;
        } elsif ((zAccel < -0.5) and (zAccel >= -5)) {
            zDivergence = ((( -0.0005 * zAccel ) - ( 0.0036 )) * zAccel - ( 0.001 )) * zAccel - 0.0004;
        } elsif ((zAccel > 0.5) and (zAccel <= 5)) {
            zDivergence = ((( -0.0004 * zAccel ) + ( 0.0031 )) * zAccel - ( 0.0016 )) * zAccel + 0.0002;
        } elsif (zAccel > 5) {
            zDivergence = 0.02;
        } else {
            zDivergence = 0;
        }
# 

        xDivergence_total = (xDivergence * 0.75) + (zDivergence * 0.25);

        if (xDivergence_total > xMax){xDivergence_total = xMax;}
        if (xDivergence_total < xMin){xDivergence_total = xMin;}

        if (abs(last_xDivergence - xDivergence_total) <= xThreshold){
            xDivergence_damp = ( xDivergence_total * n) + ( xDivergence_damp * (1 - n));
#	print ("x low pass");
        } else {
            xDivergence_damp = xDivergence_total;
#	print ("x high pass");
        }

        last_xDivergence = xDivergence_damp;

# print (sprintf("x-G=%0.5fx, total=%0.5f, x div damped=%0.5f",xAccel, xDivergence_total, xDivergence_damp));	

        yDivergence_total = yDivergence;
        if (yDivergence_total >= yMax){yDivergence_total = yMax;}
        if (yDivergence_total <= yMin){yDivergence_total = yMin;}

        if (abs(last_yDivergence - yDivergence_total) <= yThreshold){
            yDivergence_damp = ( yDivergence_total * n) + ( yDivergence_damp * (1 - n));
# 	print ("y low pass");
        } else {
            yDivergence_damp = yDivergence_total;
#	print ("y high pass");
        }

        last_yDivergence = yDivergence_damp;

#print (sprintf("y=%0.5f, y total=%0.5f, y min=%0.5f, y div damped=%0.5f",yDivergence, yDivergence_total, yMin , yDivergence_damp));

        zDivergence_total =  (xDivergence * 0.25 ) + (zDivergence * 0.75);

        if (zDivergence_total >= zMax){zDivergence_total = zMax;}
        if (zDivergence_total <= zMin){zDivergence_total = zMin;}

        if (abs(last_zDivergence - zDivergence_total) <= zThreshold){ 
            zDivergence_damp = ( zDivergence_total * n) + ( zDivergence_damp * (1 - n));
#print ("z low pass");
        } else {
            zDivergence_damp = zDivergence_total;
#print ("z high pass");
        }


#	last_zDivergence = zDivergence_damp;

#print (sprintf("z-G=%0.5f, z total=%0.5f, z div damped=%0.5f",zAccel, zDivergence_total,zDivergence_damp));
		var buffet = getprop("controls/flight/buffet") * 0.002;
        setprop("/sim/current-view/z-offset-m", xConfig + xDivergence_damp );
        setprop("/sim/current-view/x-offset-m", yConfig + yDivergence_damp );
        setprop("/sim/current-view/y-offset-m", zConfig + zDivergence_damp + seat_vertical_adjust 
		+ buffet);
    }
#    settimer(headShake,0 );

}

headShake();

# ======================================= end Pilot G stuff ============================

# ================================== Steering ==========================================

#aircraft.steering.init();

# ==================================  Engine Hobbs Meter ================================

 var updateHobbs = func{
    var running = engine_running_Node.getValue();
    var flying = !getprop("gear/gear[1]/wow");

    if(running){
        hobbs_engine.start();
    } else {
        hobbs_engine.stop();
    }

    if(flying){
        hobbs_airframe.start();
    } else {
        hobbs_airframe.stop();
    }

 } # end func updateHobbs

# ==================================  Tyresmoke /Spray ================================
var run_tyresmoke0 = 0;
var run_tyresmoke1 = 0;
var run_tyresmoke2 = 0;

var tyresmoke_0 = aircraft.tyresmoke.new(0);
var tyresmoke_1 = aircraft.tyresmoke.new(1);
var tyresmoke_2 = aircraft.tyresmoke.new(2);



#============================ Tyre Smoke ===================================

var tyresmoke = func {

#print ("run_tyresmoke ",run_tyresmoke0,run_tyresmoke1,run_tyresmoke2);

    if (run_tyresmoke0)
        tyresmoke_0.update();

    if (run_tyresmoke1)
        tyresmoke_1.update();

    if (run_tyresmoke2)
        tyresmoke_2.update();

#    settimer(tyresmoke, 0);
}# end tyresmoke



aircraft.rain.init();

var rain = func {
    var running = engine_running_Node.getValue();
    aircraft.rain.update();
#	print("rain running ", running);

    if(running){
        setprop("sim/model/rain/flow-threshold-kt", 0);
    } else {
        setprop("sim/model/rain/flow-threshold-kt", 15);
    }

#    settimer(rain, 0);
}

#============================ Gear ===================================
var gear_lever = 0;

var run_gear = func {

    var gear_control = getprop("controls/gear/gear-down");
    var cock = 0;

    var gearleft = getprop("gear/gear/position-norm");
    var uplockleft = 0;
    var downlockleft = 0;

    var gearright = getprop("gear/gear[1]/position-norm");
    var uplockright = 0;
    var downlockright = 0;

#   print ("gearleft ", gearleft, " gearright ", gearright, " gear_control ", gear_control);

    if ( gearleft >= 0 and gearleft <= 0.05 and gear_control == 1){
        cock = -1;
    } elsif (gearleft >= 0.95 and gearleft <= 1 and gear_control == 0){
        cock = 1;
    } else {
        cock = 0;
    }

    if (gearleft > 0.05 and gearleft <= 0.07){
        uplockleft = 1;
    } elsif ( gearleft > 0.93 and gearleft < 0.95){
        downlockleft = 1
    }

    if (gearright >= 0.05 and gearright <= 0.07){
        uplockright = 1;
    } elsif ( gearright >= 0.93 and gearright <= 0.95){
        downlockright = 1
    }

#    print ("uplock ", uplock, " downlock ", downlock);

    if( cock == -1 and gear_control == 1){
        setprop("controls/gear/gear-lever", -0.2);
        settimer(run_gear, 0);
    } elsif (!downlockleft and !downlockright and gear_control == 1){
        setprop("controls/gear/gear-lever", 1);
        setprop("controls/gear/oil-flow", 1);
        settimer(run_gear, 0);
    } elsif( cock == 1 and gear_control == 0){
        setprop("controls/gear/gear-lever", 0.2);
        settimer(run_gear, 0);
    } elsif (!uplockleft and !uplockright and gear_control == 0){
        setprop("controls/gear/gear-lever", -1);
        setprop("controls/gear/oil-flow", -1);
        settimer(run_gear, 0);
    } else {
        setprop("controls/gear/gear-lever", 0);
        setprop("controls/gear/oil-flow", 0);
    }
}

# =========================== smoke stuff ====================================
# set the smoke value according to the engine conditions
var updateSmoking = func {

#print("updating Smoke");
var cranking = getprop("engines/engine/cranking");
var running  = getprop("engines/engine/running");
var smoking = 0;

if (cranking and !running){  
    smoking = 1;
} else {
    smoking = 0;            # none
}

setprop("sim/ai/engines/engine/smoking", smoking);

} # end function

# ================================== Ammo State ============================================

var ammo = func {
    var trigger = getprop("/systems/pneumatic/outputs/trigger-gun");

    if (!trigger)
        return;

    var dirt = getprop("/sim/rendering/dirt-factor[2]");

	if(dirt == 0.0){
		dirt= 1.0;
		setprop("/sim/rendering/dirt-factor[2]", dirt);
		}


    count[0] = countNode.getValue();
    count[1] = count_1_Node.getValue();
    count[2] = count_2_Node.getValue();
    count[3] = count_3_Node.getValue();
    count[4] = count_4_Node.getValue();
    count[5] = count_5_Node.getValue();

#     var wt_lbs = rnd_wt_lbs * grp;
    var wt_lbs = 0;


    for(var i = 0; i < 6; i += 1){

        if (i < 2 and (type == "spitfireVb" or type == "seafireIIIc") ){
            wt_lbs = rnd_wt_lbs;
        } else {
            wt_lbs =  rnd_wt_303_lbs;
        }

        ammo_wt[i]= getprop("/yasim/weights/ammo-lb[" ~ i ~ "]");
        ammo_wt[i] = count[i] * wt_lbs;

        if (ammo_wt[i] < 0.)ammo_wt[i] = 0;

		if (i == 5){
			dirt = clamp((1 * (1 - count[i]/300)) * 2, 0.0, 0.75);
			setprop("/sim/rendering/dirt-factor[3]", dirt);
			}

        setprop("/yasim/weights/ammo-lb[" ~ i ~ "]", ammo_wt[i]);
#        print (" ammo count[", i,"] ", count[i], " ", ammo_wt[i], " ", getprop("/sim/rendering/dirt-factor[3]"));
    }# end for

        settimer(ammo, 0);

} # end func ammo



setlistener("sim/signals/fdm-initialized", initialize);

# end 
