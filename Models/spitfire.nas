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
print ("type: " , type , " spitfireIIa: " , spitfireIIa);

if (type == "spitfireIIa") {spitfireIIa = 1;}

print ("type: " , type , " spitfireIIa: " , spitfireIIa);
# ============================= Coffman starter stuff =======================================

indexCof = func{
    pull=arg[0];
    if(pull) {
        i = getprop("controls/engines/engine/coffman-starter/index");
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
    start = arg[0];
	
    if(start and spitfire.spitfireIIa) {             #Coffman starter
	     print ("type: " , spitfire.type , " spitfireIIa: " , spitfireIIa);
        i = getprop("controls/engines/engine/coffman-starter/index");
        j= "controls/engines/engine/coffman-starter/cartridge" ~ "[" ~ i ~ "]";
        primer = getprop("controls/engines/engine/primer");
        setprop("controls/engines/engine/coffman-starter/starter-push-norm",1);
        if (getprop(j) ) {                            # if cartridge hasn't been fired  
            primerMixture(primer);                            # set the mixture
            setprop("controls/engines/engine/starter",1);     # starter runs
            setprop(j,0);                                    # fire this cartridge
        }
	}
	elsif (start) {                           #Electric starter
	    primer = getprop("controls/engines/engine/primer");
	    primerMixture(primer);                            # set the mixture
        setprop("controls/engines/engine/starter",1);     # starter runs	    
    }
	else{
        setprop("controls/engines/engine/starter",0);
        setprop("controls/engines/engine/coffman-starter/starter-push-norm",0);
        setprop("controls/engines/engine/primer", 0);    # set primer back to zero
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
        controls.stepFlaps(1);                                # full flap
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
            controls.stepFlaps(-1);                    # flap up, don't run the timer                    
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
