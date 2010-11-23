# This is aminor amendment of fuel.nas which changes the logic so that the 
# code no longer changes the selection state of tanks.



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

var UPDATE_PERIOD = 0.3;

# ============================== Register timer ===========================================

var registerTimer = func {

    settimer(fuelUpdate, UPDATE_PERIOD);

}# end func

# ============================= end Register timer =======================================

# =================================== Fuel Update ========================================

var fuelUpdate = func {
    var gals = 0;
    var lbs = 0;
    var cap = 0;
    var ppg = 0;
    var contents = 0;

    if(getprop("/sim/freeze/fuel")) { return registerTimer(); }

    if (flag and !done) {print("fuel-cocks running ..."); done = 1};

    var AllEngines = props.globals.getNode("engines").getChildren("engine");

    var AllEnginescontrols = props.globals.getNode("controls/engines").getChildren("engine");

# Sum the consumed fuel
    var total = 0;

    foreach( var e; AllEngines) {
        fuel = e.getNode("fuel-consumed-lbs", 1);
        consumed = fuel.getValue();
        if(consumed == nil) { consumed = 0; }
        total = total + consumed;
        fuel.setDoubleValue(0);
    }

# Unfortunately, FDM initialization hasn't happened when we start
# running.  Wait for the FDM to start running before we set any output
# properties.  This also prevents us from mucking with FDMs that
# don't support this fuel scheme.
    if(total == 0 and !flag) {  # this relies on 'total'
        return registerTimer(); #  not being quite 0 at startup,
    }else{                      # and therefore keeps the function running,
    flag = 1;               # once it has run once.
    }

    if(!initialized) { initialize(); }

    var AllTanks = props.globals.getNode("consumables/fuel").getChildren("tank");

# Build a list of available tanks. An available tank is both selected and has 
# fuel remaining.  Note the filtering for "zero-capacity" tanks.  The FlightGear
# code likes to define zombie tanks that have no meaning to the FDM,
# so we have to take measures to ignore them here. 
    var availableTanks = [];

    foreach( var t; AllTanks) {
        cap = t.getNode("capacity-gal_us", 1).getValue();
        contents = t.getNode("level-gal_us", 1).getValue();
        if(cap != nil and cap > 0.01 ) {
            if(t.getNode("selected", 1).getBoolValue() and contents > 0) {
                append(availableTanks, t);
            }
        }
    }

# Subtract fuel from tanks, set auxilliary properties.  Set out-of-fuel
# when all tanks are dry. Set mixture to
    var outOfFuel = 0;

#cutoff = getprop("controls/engines/engine/cutoff");
#if (cutoff) {
#    mixture = 1;    
#} else {
#    mixture = 0;
#}
#print ("mixture: " , mixture);

    if(size(availableTanks) == 0) {
        outOfFuel = 1;
    } else {
        fuelPerTank = total / size(availableTanks);
        foreach( var t; availableTanks) {
            ppg = t.getNode("density-ppg").getValue();
            lbs = t.getNode("level-gal_us").getValue() * ppg;
            lbs = lbs - fuelPerTank;
            if(lbs < 0) {
                lbs = 0; 
# Kill the engines if we're told to, otherwise simply
# do nothing
                if(t.getNode("kill-when-empty", 1).getBoolValue()) {
                    outOfFuel = 1;
                }
            }
            gals = lbs / ppg;
            t.getNode("level-gal_us").setDoubleValue(gals);
            t.getNode("level-lbs").setDoubleValue(lbs);
        }
    }

# Total fuel properties
    gals = lbs = cap = 0;

    foreach(t; AllTanks) {
        cap = cap + t.getNode("capacity-gal_us").getValue();
        gals = gals + t.getNode("level-gal_us").getValue();
        lbs = lbs + t.getNode("level-lbs").getValue();
    }

    setprop("/consumables/fuel/total-fuel-gals", gals);
    setprop("/consumables/fuel/total-fuel-lbs", lbs);
    setprop("/consumables/fuel/total-fuel-norm", gals/cap);

#foreach(e; AllEngines) {
#    e.getNode("out-of-fuel").setBoolValue(outOfFuel);
#}

# we use the mixture to control the engines, so set the mixture
    var cutoff = getprop("controls/engines/engine/cutoff");
    var starter = getprop("controls/engines/engine/starter");
    var mixture = 0;
    var primer = 0;

#print ("cutoff: " , cutoff, " starter: " , starter);

    if ( outOfFuel or !cutoff ) {
#print( "in out of fuel, mixture: ", mixture);
        mixture = 0;
    } 
    elsif( starter ) { # mixture is controlled by priming pump
        mixture = 1;
    primer = getprop("controls/engines/engine/primer");
    mixture = ( spitfire.primerMixture(primer) );
#print( "calling primerMixture, mixture: ", mixture);
    }
    else { # mixture is controlled by G force and lever
        mixture = 1;
    mixture = ( spitfire.negGCutoff() );              
#print( "calling negG, mixture: ", mixture);
    }

# set the mixture on the engines
    foreach( var e; AllEnginescontrols) {
        e.getNode("mixture").setDoubleValue(mixture);
    }

    registerTimer();

}# end func

# ================================ end Fuel Update ================================

# ================================ Initalize ====================================== 
# Make sure all needed properties are present and accounted
# for, and that they have sane default values.
var flag = 0;
var done = 0;
var initialized = 0;



var initialize = func {

    var AllEngines = props.globals.getNode("engines").getChildren("engine");
    var AllTanks = props.globals.getNode("consumables/fuel").getChildren("tank");
    var AllEnginescontrols = props.globals.getNode("controls/engines").getChildren("engine");

    foreach( var e; AllEngines) {
        e.getNode("fuel-consumed-lbs", 1).setDoubleValue(0);
        e.getNode("out-of-fuel", 1).setBoolValue(0);
    }

    foreach( var t; AllTanks) {
        initDoubleProp(t, "level-gal_us", 0);
        initDoubleProp(t, "level-lbs", 0);
        initDoubleProp(t, "capacity-gal_us", 0.01); # Not zero (div/zero issue)
            initDoubleProp(t, "density-ppg", 6.0); # gasoline

            if(t.getNode("selected") == nil) {
                t.getNode("selected", 1).setBoolValue(1);
            }
    }

    foreach( var c; AllEnginescontrols) {
        if(c.getNode("mixture-lever") == nil) {
            c.getNode("mixture-lever", 1).setDoubleValue(0);
        }
    }

    initialized = 1;

}# end func

# ================================ end Initalize ================================== 

# =============================== Utility Function ================================

var initDoubleProp = func {

    var node = arg[0]; 
    var prop = arg[1]; 
    var val = arg[2];

    if(node.getNode(prop) != nil) {
        val = num(node.getNode(prop).getValue());
    }

    node.getNode(prop, 1).setDoubleValue(val);

}# end func

# =========================== end Utility Function ================================

# Fire it up

setlistener("sim/signals/fdm-initialized", registerTimer);

