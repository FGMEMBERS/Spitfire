###############################################################################
##
##  Fuel system module for FlightGear.
##
##  Copyright (C) 2012  Vivian Meazza  (vivia.meazza(at)lineone.net)
##  This file is licensed under the GPL license v2 or later.
##
###############################################################################

# Properties under /consumables/fuel/tank[n]:
# + level-gal_us    - Current fuel load.  Can be set by user code.
# + level-lbs       - OUTPUT ONLY property, do not try to set
# + selected        - boolean indicating tank selection.
# + density-ppg     - Fuel density, in lbs/gallon.
# + capacity-gal_us - Tank capacity
#
# Properties under /engines/engine[n]:
# + fuel-consumed-lbs - Output from the FDM, zeroed by this script
# + out-of-fuel       - boolean, set by this code.

# ==================================== Definiions ===========================================
# set the update period
UPDATE_PERIOD = 0.3;

# set the timer for the selected function

registerTimer = func {

    settimer(arg[0], UPDATE_PERIOD);
    
}# end func

#does what it says on the tin
var clamp = func(v, min, max) { v < min ? min : v > max ? max : v }

var update = func {
	if (fuel_freeze) {
		return;
	}

	var consumed_fuel = 0;
	foreach (var e; engines) {
		var fuel = e.getNode("fuel-consumed-lbs");
		consumed_fuel += fuel.getValue();
		fuel.setDoubleValue(0);
	}

#	print("running update");

	# Build a list of available tanks. An available tank is both selected and has 
    # fuel remaining.  Note the filtering for "zero-capacity" tanks.  The FlightGear
    # code likes to define zombie tanks that have no meaning to the FDM,
    # so we have to take measures to ignore them here. 
    var availableTanks = [];
	var cap = 0.01; #  division by 0 issue
	var contents = 0;
	var selected = 0;

    foreach(t; alltanks) {

		if(t.getNode("capacity-gal_us") != nil)
			{
			cap = t.getNode("capacity-gal_us", 1).getValue();
			contents = t.getNode("level-gal_us", 1).getValue();
			selected = t.getNode("selected", 1).getBoolValue();

			if( cap > 0.01 and contents > 0 and selected ) append(availableTanks, t);

			}# endif

		} # end foreach

    # Subtract fuel from tanks, set auxilliary properties.  Set out-of-fuel
    # when all available tanks are dry.
		var outOfFuel = 0;
		var lbs = 0;
		var ppg = 0;
		var gals = 0;

		if(size(availableTanks) == 0)
			{
			outOfFuel = 1;
			} 
		else 
			{
			fuelPerTank = consumed_fuel / size(availableTanks);

			foreach(t; availableTanks) 
				{
				ppg = t.getNode("density-ppg").getValue();
				lbs = t.getNode("level-gal_us").getValue() * ppg;
				lbs = lbs - fuelPerTank;

				if(lbs <= 0) 
					{
					lbs = 0; 

					if(t.getNode("kill-when-empty", 1).getBoolValue()) outOfFuel = 1;

					} #endif

				gals = lbs / ppg;
				t.getNode("level-gal_us").setDoubleValue(gals);
				t.getNode("level-lbs").setDoubleValue(lbs);
				} # end foreach

			} #endif
    
    # Total fuel properties
	foreach(t; alltanks) 
		{
		cap  += t.getNode("capacity-gal_us").getValue();
		gals += t.getNode("level-gal_us").getValue();
		lbs  += t.getNode("level-lbs").getValue();
		}

    setprop("/consumables/fuel/total-fuel-gals", gals);
    setprop("/consumables/fuel/total-fuel-lbs", lbs);
    setprop("/consumables/fuel/total-fuel-norm", gals/cap);

# we use the mixture to control the engines, so set the mixture
	var cutoff = getprop("controls/engines/engine/cutoff") or 0;
	var starter = getprop("controls/engines/engine/starter") or 0;
	var mixture = 0;

	if ( outOfFuel or !cutoff )
		{
		mixture = 0;
		} 
	elsif( starter == 1 ) 
		{ # mixture is controlled by start conditions
		primer = getprop("engines/engine/primer");
	    mixture = ( primerMixture(primer) );
		}
	else 
		{ # mixture is controlled by G force and mixture lever
		mixture = ( spitfire.negGCutoff() );              
		}

# set the mixture on the engines
	foreach(e; enginecontrols) 
		{
		e.getNode("mixture").setDoubleValue(mixture);
		}

} #end func update

# ==================== fuel cocks =====================
# operate fuel cocks

var openCock=func{

	setprop("consumables/fuel/tank["~ arg[0] ~"]/selected", arg[1])

}#end func

# toggle fuel cocks

toggleCock=func{

    var cock = !getprop("consumables/fuel/tank["~ arg[0] ~"]/selected");
	setprop("consumables/fuel/tank["~ arg[0] ~"]/selected", cock);
	interpolate("controls/engines/engine/fuel-cock/lever-norm["~ arg[0] ~"]", cock, 2.0);

}#end func


var setTankContents=func{

	tank =getprop("controls/switches/fuel-gauge-sel") or 0;
	contents = getprop("consumables/fuel/tank[" ~ tank ~ "]/level-gal_us") or 0;
	setprop("instrumentation/fuel/contents-gal_us",contents);
#	print("contents: " , contents, " tank: " , tank);
	
}#end func

# ========== primer stuff ======================

var pumpPrimer = func{
	var push = arg[0];
	var pump = getprop("engines/engine/primer") or 0;

	if (push)
		{
		pump += 1;
		setprop("engines/engine/primer", pump);
		setprop("controls/engines/engine/primer-pump", 1);
		}
	else
		{
		setprop("controls/engines/engine/primer-pump", 0);
		}

} # end function

var primerMixture = func{
	var mixture = 0;
	var primer = arg[0];
	var throttle = getprop("controls/engines/engine/throttle") or 0;
	
	if(primer >3 and primer <7 and throttle > 0.25 and throttle < 0.35) {
		mixture = 1;
	}
	
	return mixture;
	   
} # end function
# ================================== end priming pump stuff =================================


# ========== tranfer fuel ======================

var fuelTrans = func {

    var amount = 0;

    if(getprop("/sim/freeze/fuel")) return;

    var capacityLower = getprop("consumables/fuel/tank[1]/capacity-gal_us") or 0;
    var levelLower = getprop("consumables/fuel/tank[1]/level-gal_us") or 0;
    var levelUpper = getprop("consumables/fuel/tank/level-gal_us") or 0;

    if ( capacityLower > levelLower and levelUpper > 0){
        amount = capacityLower - levelLower;

#        if (amount > levelUpper) {amount = levelUpper; }
		amount = math.min(amount, levelUpper);
        levelUpper -= amount;
        levelLower += amount;
        setprop( "consumables/fuel/tank/level-gal_us",levelUpper);
        setprop( "consumables/fuel/tank[1]/level-gal_us",levelLower);
    }

#print("Upper: ",levelUpper, " Lower: ",levelLower);
#print( " Amount: ",amount);

} # end funtion fuelTrans

# ========== utility function ======================
var init_double_prop = func(node, prop, val) {
	if (node.getNode(prop) != nil) val = num(node.getNode(prop).getValue());
	if(val == nil) val = 0;
	node.getNode(prop, 1).setDoubleValue(val);
}

# ========== main loop function ======================
var loop = func {
	update();
	fuelTrans();
	registerTimer(loop);
}



# ================================ Initalize ====================================== 
# Make sure all needed properties are present and accounted 
# for, and that they have sane default values.

# =============== Variables ================

var alltanks = [];
var engines = [];
var enginecontrols = [];
var fuel_freeze = nil;
var total_gals = nil;
var total_lbs = nil;
var total_norm = nil;

controls.startEngine = func(v = 1) {

	if (!v)
		{
		setprop("engines/engine/primer", 0);
		return setprop("/controls/engines/engine/starter", 0);
		} 
	else 
		{
		setprop("/controls/engines/engine/starter", v)
		}
	}

var L = setlistener("/sim/signals/fdm-initialized", func {
	removelistener(L);
	print( "Initializing Fuel System ..." );
	setlistener("/sim/freeze/fuel", func(n) { fuel_freeze = n.getBoolValue() }, 1);
	setlistener("/controls/switches/fuel-gauge-sel", func(n) {setTankContents();}, 1);
	
	total_gals = props.globals.getNode("/consumables/fuel/total-fuel-gals", 1);
	total_lbs = props.globals.getNode("/consumables/fuel/total-fuel-lbs", 1);
	total_norm = props.globals.getNode("/consumables/fuel/total-fuel-norm", 1);

	enginecontrols = props.globals.getNode("controls/engines").getChildren("engine");
	engines = props.globals.getNode("engines", 1).getChildren("engine");
	foreach (var e; engines) 
		{
		e.getNode("fuel-consumed-lbs", 1).setDoubleValue(0);
		e.getNode("out-of-fuel", 1).setBoolValue(0);
		e.getNode("primer", 1).setDoubleValue(0);
		}

	foreach (var t; props.globals.getNode("/consumables/fuel", 1).getChildren("tank"))
		{

		if (t.getNode("name") == nil)
			{
#			print("name skipping", t.getNode("name",1).getValue());
			continue;           # skip native_fdm.cxx generated zombie tanks
			}

#		print("name", t.getNode("name",1).getValue());
		append(alltanks, t);
		init_double_prop(t, "level-gal_us", 0.0);
		init_double_prop(t, "level-lbs", 0.0);
		init_double_prop(t, "capacity-gal_us", 0.01); # not zero (div/zero issue)
		init_double_prop(t, "density-ppg", 6.0);      # gasoline

		if (t.getNode("selected") == nil) t.getNode("selected", 1).setBoolValue(1);

		} #end foreach

	print ("... done");

#	print("tank size", size(alltanks));
	loop();
	});


