# $Id$

# ==================================== timer stuff ===========================================

# set the update period

UPDATE_PERIOD = 0.3;

# set the timer for the selected function

registerTimer = func {
    
    settimer(arg[0], UPDATE_PERIOD);

} # end function 

# =============================== end timer stuff ===========================================

# =============================== set the aircraft type =====================================

spitfireIIa = 0;

type = getprop("sim/aircraft");

if (type == "spitfireIIa") {spitfireIIa = 1;}

print ("type: " , type );

# =============================== Boost Controller stuff======================================

BOOST_CONTROL_AUTHORITY = 0.99; # How much can it move the throttle?
#BOOST_CONTROL_RANGE = 1;         When does it start to engage? (psig)
BOOST_CONTROL_LIMIT_RATED = 9;        # Rated Maximum MP  (psi gauge) (1 hr)
BOOST_CONTROL_LIMIT_COMBAT = 12.5;    # Combat limit (5 mins)

if (type == "seafireIIIc") {BOOST_CONTROL_LIMIT_COMBAT = 16;}  

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
	print("c: " , c );
    
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
      
#        print(sprintf("mp=%0.5f, in=%0.5f, raw=%0.5f, out=%0.5f", mp, in, val, damp));
		boost_pressure_psi.setDoubleValue(mp);
        boost_control.setDoubleValue(damp);
		boost_control_cutout.setBoolValue(cutout);
        settimer(updateBoostControl, 0.1);
}

updateBoostControl();

# ======================================= end Boost Controller f ============================


# ============================= Coffman starter stuff =======================================


nowN       = props.globals.getNode("/sim/time/elapsed-sec", 1);
starterN   = props.globals.getNode("controls/engines/engine/starter", 1);
primerN    = props.globals.getNode("controls/engines/engine/primer", 1);
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
	max_run = 4;
	
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
					           	print ("starter stopping, out of gas!"); 
					            }, max_run)};
     		}

			if (ready) {
				primerMixture(primerN.getValue());
				starterN.setValue(1);
#				print ("starter running!");
			}
		}
	} else{
		settimer(stopCof, 0.2);
	}
} # end function


stopCof = func {

    min_run = 2;
	if (!Start and starterN.getValue()) {
		if (nowN.getValue() - LastStartTime < min_run) {
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

# ============================ end Coffman starter stuff =====================================

# ================================= priming pump stuff =======================================

pumpPrimer = func{
    
    push = arg[0];
    
    if (push){
        pump = getprop("controls/engines/engine/primer") + 1;
        setprop("controls/engines/engine/primer", pump);
        setprop("controls/engines/engine/primer-pump",1);
        }
    else
        {
        setprop("controls/engines/engine/primer-pump",0);
    }

} # end function

primerMixture = func{
    
	mixture = 0;
    primer = arg[0];
    
    if(primer >3 and primer <7) {
        mixture = 1;
    }
    
    return mixture;
	   
} # end function

# ================================== end priming pump stuff =================================

# ================================= magneto stuff ===========================================

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

# =============================== end magneto stuff =========================================

# ====================================== door and canopy stuff ==============================

openDoor = func{ # open the door if canopy is open
    
    dooropen = arg[0];
    canopyopen = getprop("gear/canopy/position-norm");
    if (canopyopen) {
        setprop("controls/flight/door-position-norm",dooropen)
    }
    
} # end function

toggleDoor = func{ # toggle the door if canopy is open
    
    dooropen = getprop("controls/flight/door-position-norm");
    canopyopen = getprop("gear/canopy/position-norm");
    if (canopyopen) {
        dooropen = !dooropen;
        setprop("controls/flight/door-position-norm",dooropen);
    }
    
} # end function

openCanopy = func{ # open the canopy if door is closed
    
    canopyopen = arg[0];
    dooropen = getprop("controls/flight/door-position-norm");
    if (!dooropen) {
        setprop("controls/flight/canopy-slide",canopyopen)
    }

} # end function

# ==================================== end door and canopy ===================================

# ======================================== Cutoff ============================================

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

# =================================== end Cutoff ============================================

# ======================================= fuel tank stuff ===================================

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

# tranfer fuel

fuelTrans = func {
    
    amount = 0;

    
    if(getprop("/sim/freeze/fuel")) { return registerTimer(fuelTrans); }
    
    capacityLower = getprop("consumables/fuel/tank[1]/capacity-gal_us");
    if(capacityLower == nil) { capacityLower = 0; }
    
    levelLower = getprop("consumables/fuel/tank[1]/level-gal_us");
    if(levelLower == nil) { levelLower = 0; }
    
    levelUpper = getprop("consumables/fuel/tank/level-gal_us");
    if(levelUpper == nil) { levelUpper = 0; }
    
    if ( capacityLower > levelLower and levelUpper > 0){
        amount = capacityLower - levelLower;
        if (amount > levelUpper) {amount = levelUpper}
        levelUpper = levelUpper - amount;
        levelLower = levelLower + amount;
        setprop( "consumables/fuel/tank/level-gal_us",levelUpper);
        setprop( "consumables/fuel/tank[1]/level-gal_us",levelLower);
    }
    
    #print("Upper: ",levelUpper, " Lower: ",levelLower);
    #print( " Amount: ",amount);

    registerTimer(fuelTrans);
    
} # end funtion fuelTrans    
        

# fire it up

registerTimer(fuelTrans);

# ========================== end fuel stuff ======================================

# =========================== flap stuff =========================================

flapLever = func{                         #sets the flap lever up or down

    down = arg[0];
    
    setprop("controls/flight/flaps-lever",down);
    if (down) {registerTimer(flapBlowin)}                        # run the timer
        
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
            flap = -0.08*airspeed + 9.4;
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
    setprop("sim/alarms/gear-warn",cancel);
    if (cancel) {registerTimer(resetWarn)}                    # run the timer
        
} # end function 

resetWarn = func{

    throttle = getprop("controls/engines/engine/throttle");
    gearwarn = getprop("sim/alarms/gear-warn");
    #print("throttle " , throttle , " gearwarn: " , gearwarn);
    if (gearwarn and throttle >= 0.25 ) { 
        setprop("sim/alarms/gear-warn",0);                    # reset the gear warning
        }
        else
        {
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

# =============================== end -ve g cutoff ===========================================

# end 
