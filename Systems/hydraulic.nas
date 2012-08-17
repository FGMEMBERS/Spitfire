###############################################################################
##
##  Hydraulic system module for FlightGear.
##
##  Copyright (C) 2012  Vivian Meazza  (vivia.meazza(at)lineone.net)
##  This file is licensed under the GPL license v2 or later.
##
###############################################################################
# Properties under /systems/hydraulic:
# + servicable      - Current status  Must be set by user code.

# + pressure        - OUTPUT ONLY property, do not try to set

# ==================================== Definiions ===========================================
# set the maximum and minimum pressure
MAX_PRESSURE = 1200.0;
MIN_PRESSURE = 500.0;

# set the update period
UPDATE_PERIOD = 0.3;

# set the timer for the selected function

registerTimer = func {

    settimer(arg[0], UPDATE_PERIOD);

} # end function 

#does what it says on the tin
var clamp = func(v, min, max) { v < min ? min : v > max ? max : v }

# ================================ Initalize ====================================== 
# Make sure all needed properties are present and accounted 
# for, and that they have sane default values.

# =============== Variables ================
var pressure = 0;
var max_pressure = 0;
var pump = nil;

var valve = nil;
var valve_1 = nil;
var valve_2 = nil;

var actuator = nil;
var actuator_1 = nil;
var actuator_2 = nil;
var actuator_3 = nil;
var actuator_4 = nil;

var relief_valve = nil;

var initialize = func {

print( "Initializing Hydraulic System ..." );

props.globals.initNode("/systems/hydraulic/serviceable", 1, "BOOL");
props.globals.initNode("/systems/hydraulic/pressure-psi", 0, "DOUBLE");
props.globals.initNode("/controls/hydraulic/lever", 1, "DOUBLE");
props.globals.initNode("/controls/hydraulic/lever[1]", 0, "DOUBLE");
props.globals.initNode("/controls/hydraulic/lever[2]", 0, "DOUBLE");
props.globals.initNode("/systems/hydraulic/outputs/gear", 1, "DOUBLE");
props.globals.initNode("/systems/hydraulic/outputs/gear[1]", 1, "DOUBLE");
#props.globals.initNode("/systems/hydraulic/outputs/gear[2]", 1, "DOUBLE");
#props.globals.initNode("/systems/hydraulic/outputs/rad-flap", 0, "DOUBLE");
#props.globals.initNode("/systems/hydraulic/outputs/flaps", 0, "DOUBLE");

###
# overwrite these functions in controls.nas
#
controls.gearDown = func(x) { if (x) 
	{ 
	setprop("/controls/hydraulic/lever", x);
	print("controls.gear ",getprop("/controls/hydraulic/lever"));
	} 
	}


###
# suppliers ("name", "rpm source", "control property", status, factor, max pressure)
#
	pump = Pump.new("pump-engine",
					"engines/engine[0]/rpm",
					"controls/hydraulic/system/engine-pump",
					1,
					0.9,
					1300);

###
# valves ("name", "input property", "control property", status, initial state)
#
	valve = Valve.new("gear",
					"systems/hydraulic/pressure-psi",
					"controls/hydraulic/lever",
					1,
					1);

###
# actuators ("name", "input property", "output property", "position property",
# status, min, max, initial state)
#

	actuator = Actuator.new("gear",
					"systems/hydraulic/valves/gear/output-pressure-psi",
					"systems/hydraulic/outputs/gear",
					"gear/gear/position-norm",
					1,
					-MAX_PRESSURE,
					MAX_PRESSURE,
					1);

	actuator_1 = Actuator.new("gear-1",
					"systems/hydraulic/valves/gear/output-pressure-psi",
					"systems/hydraulic/outputs/gear[1]",
					"gear/gear[1]/position-norm",
					1,
					-MAX_PRESSURE,
					MAX_PRESSURE,
					1);

###
# relief valves ("name", "input property", "control property", "output property", status,
# max, initial state)
#
	relief_valve = Relief.new("blow-off",
					"systems/hydraulic/suppliers/pump-engine/output-pressure-psi",
					"systems/hydraulic/pressure-psi",
					"systems/hydraulic/pressure-psi",
					1,
					MAX_PRESSURE,
					0);

# =============================== listeners ===============================
#

	setlistener("/gear/gear[1]/wow", func (n){
		var wow = n.getValue();
		var up_lock = 0;
		var down_lock = getprop("/gear/gear[1]/position-norm");

		if(wow and down_lock < 1.0)
			{
			print("collapse");
			}

#		setprop("systems/hydraulic/outputs/gear", gear);
#		setprop("systems/hydraulic/outputs/gear[1]", gear);
#		setprop("systems/hydraulic/outputs/gear[2]", gear);
#		print ("lever ", lever," gear ", gear);

	},
	0,
	0); # end listener

	setlistener("controls/hydraulic/lever", func {
		run_gear();
		},
			0,
			0);

# =============================== start it up ===============================
#
print( "... done" );
update_hydraulic();

} #end init

###
# =================== hydraulic system =========================
#
###
# This is the main loop which keeps eveything updated
#
update_hydraulic = func {
#	time = props.globals.getNode("/sim/time/elapsed-sec", 1).getValue();
#	dt = time - last_time;
#	last_time = time;
	
	foreach (var p; Pump.list)
		{
		p.update();
		}

	foreach ( var r; Relief.list)
		{
		r.update();
		}

	foreach (var v; Valve.list)
		{
		v.update();
		}

	foreach ( var a; Actuator.list)
		{
		a.update();
		}

# Request that the update fuction be called again 
	registerTimer(update_hydraulic);
}

##
# Pump class. Defines an hydraulic pump

Pump = {
	 new : func(name, source, control, serviceable, factor, max_pressure) {
		var obj = { parents : [ Pump ] };
		obj.name = name;
		#print ("name ", name);
		#print ("output ", output);
		obj.rpm_source_N = props.globals.getNode( source, 1 );
		obj.rpm_source_N.setDoubleValue(0);
		obj.control_N = props.globals.getNode( control, 1 );
		obj.control_N.setBoolValue( 1 );
#		obj.output_pressure_N = props.globals.getNode( output, 1 );
#		obj.output_pressure_N.setDoubleValue( 0 );
		obj.factor = factor;
		obj.max_pressure = max_pressure;
		obj.props_N = props.globals.getNode( "systems/hydraulic/suppliers", 1 ).getChild(name, 0, 1);
		obj.props_serviceable_N = obj.props_N.getChild("serviceable", 0, 1);
		obj.props_serviceable_N.setBoolValue( serviceable );
		obj.props_out_pressure_N = obj.props_N.getChild("output-pressure-psi", 0, 1);
		obj.props_out_pressure_N.setDoubleValue( 0 );
		append(Pump.list, obj); 
		return obj;
	},
	update : func {
		var rpm = me.rpm_source_N.getValue();
		var serviceable = me.props_serviceable_N.getValue();
		var control = me.control_N.getValue();
		var factor = me.factor;
		var max_pressure = me.max_pressure;

		if (serviceable)
			{
			pressure = clamp(factor * rpm * control, 0, max_pressure);
			}
		else
			{
			pressure = 0;
			}

	me.props_out_pressure_N.setDoubleValue(pressure);
	# print ("pressure ", pressure);
		
	},
	setMaxPressure : func (pressure) {
		me.max_pressure = pressure;
	},
	setServiceable : func (serviceable) {
		me.props_serviceable_N.setBoolValue( serviceable ); 
	},
	list : [],
};

# Valve class. Defines a valve in the hydraulic system. Input is an hydraulic pressure source, output is used 
# to drive an actuator

Valve = {
	 new : func(name, source, control, serviceable, state) {
		var obj = { parents : [ Valve ] };
		obj.name = name;
#		print ("name ", name);
#        print ("source ", source);
#		print ("output ", output);
		obj.source_N = props.globals.getNode( source, 1 );
		obj.source_N.setDoubleValue(0);
		obj.control_N = props.globals.getNode( control, 1 );
		obj.control_N.setDoubleValue(state);
		obj.props_N = props.globals.getNode( "systems/hydraulic/valves", 1 ).getChild(name, 0, 1);
		obj.props_serviceable_N = obj.props_N.getChild("serviceable", 0, 1);
		obj.props_serviceable_N.setBoolValue( serviceable );
		obj.props_in_pressure_N = obj.props_N.getChild("input-pressure-psi", 0, 1);
		obj.props_in_pressure_N.setDoubleValue( 0 );
		obj.props_out_pressure_N = obj.props_N.getChild("output-pressure-psi", 0, 1);
		obj.props_out_pressure_N.setDoubleValue( 0 );

		append(Valve.list, obj); 
		return obj;
	},
	update : func {
		var source = me.source_N.getValue();
		var control = clamp(me.control_N.getValue(), -1, 1); 
		var serviceable = me.props_serviceable_N.getValue();
		var output_pressure = 0;
		#print (me.name," source ", source, " control " , control);

		if (serviceable)
			{
			output_pressure = source * control;
			}
		else
			{
			output_pressure = 0;
			}

		me.props_in_pressure_N.setDoubleValue(source);
		me.props_out_pressure_N.setDoubleValue(output_pressure);

	    #print (me.name, " valve output ", output_pressure);
		
	},
	setServiceable : func (serviceable) {
		me.props_serviceable_N.setBoolValue( serviceable ); 
	},
	list : [],
};

# Actuator class. Defines a double acting actuator in the hydraulic system.  
# The output (normalised) can be used to drive control surfaces etc 

Actuator = {
	 new : func(name, source, output, pos_norm, serviceable, min, max, state) {
		var obj = { parents : [ Actuator ] };
		obj.name = name;
#		print ("name ", name);
#       print ("source ", source);
		#print ("output ", output);
		obj.source_N = props.globals.getNode( source, 1 );
		obj.source_N.setDoubleValue( 0 );
		obj.output_N = props.globals.getNode( output, 1 );
		obj.output_N.setDoubleValue( state );
		obj.position_norm_N = props.globals.getNode( pos_norm, 1 );
		obj.position_norm_N.setDoubleValue( state );
		obj.props_N = props.globals.getNode( "systems/hydraulic/actuators", 1 ).getChild(name, 0, 1);
		obj.props_serviceable_N = obj.props_N.getChild("serviceable", 0, 1);
		obj.props_serviceable_N.setBoolValue( serviceable );
		obj.props_in_pressure_N = obj.props_N.getChild("input-pressure-psi", 0, 1);
		obj.props_in_pressure_N.setDoubleValue( 0 );
		obj.props_position_norm_N = obj.props_N.getChild("position-norm", 0, 1);
		obj.props_position_norm_N.setDoubleValue( 0 );
		obj.min = min;
		obj.max = max;

		append(Actuator.list, obj); 
		return obj;
	},
	update : func {
		var source = me.source_N.getValue();
		var serviceable = me.props_serviceable_N.getValue();
		var state = me.position_norm_N.getValue();
		var output = 0;
		#print (me.name, " source ", source, " state " , state);

		if(source < MIN_PRESSURE and source > -MIN_PRESSURE or !serviceable)
			{
			output = state;
			#print (me.name," low pressure ", output);
			}
		elsif (source >= MIN_PRESSURE)
			{
			output = source / me.max;
			#print(me.name," max output ", output);
			output = math.max(output, state);
			#print(me.name," output max ", output);
			}
		elsif(source <= - MIN_PRESSURE)
			{
			output = (source - me.min) / math.abs(me.min);
			#print(me.name," min output ", output);
			output = math.min(output, state);
			#print(me.name," output min ", output);
			}
		else
			{
			output = state;
			}

		output = clamp(output, -1, 1);
		me.output_N.setDoubleValue( output );
		me.props_in_pressure_N.setDoubleValue( source );
		me.props_position_norm_N.setDoubleValue( state );

#	    print (me.name, " output ", me.output_N.getValue());
		
	},
	setServiceable : func (serviceable) {
		me.props_serviceable_N.setBoolValue( serviceable ); 
	},
	list : [],
};

# Relief Valve class. Defines a relief valve in the hydraulic system.  The output controls
# the pressure in the hydraulic system.
# "name", "input property", "control property", "output property", status,
# max, initial state

Relief = {
	 new : func(name, source, control, output, serviceable,  max, state) {
		var obj = { parents : [ Relief ] };
		obj.name = name;
#		print ("name ", name);
#       print ("source ", source);
#		print ("output ", output);
		obj.source_N = props.globals.getNode( source, 1 );
		obj.source_N.setDoubleValue( 0 );
		obj.control_N = props.globals.getNode( control, 1 );
		obj.control_N.setDoubleValue(state);
		obj.output_N = props.globals.getNode( output, 1 );
		obj.output_N.setDoubleValue( MAX_PRESSURE );

		obj.props_N = props.globals.getNode( "systems/hydraulic/relief-valves", 1 ).getChild(name, 0, 1);
		obj.props_serviceable_N = obj.props_N.getChild("serviceable", 0, 1);
		obj.props_serviceable_N.setBoolValue( serviceable );
		obj.props_in_pressure_N = obj.props_N.getChild("input-pressure-psi", 0, 1);
		obj.props_in_pressure_N.setDoubleValue( 0 );
		obj.props_out_pressure_N = obj.props_N.getChild("output-pressure-psi", 0, 1);
		obj.props_out_pressure_N.setDoubleValue( 0 );

		obj.max = max;

		append(Actuator.list, obj); 
		return obj;
	},
	update : func {
		var source = me.source_N.getValue();
		var serviceable = me.props_serviceable_N.getValue();
		var control = clamp(me.control_N.getValue(), -1, 1);
		var output = source;
#		print (me.name, " source ", source, " control " , control);

		if (serviceable and control != 0)
			{
			output = clamp(source, 0, me.max);
			}
		else
			{
			output = source;
			}

		me.output_N.setDoubleValue( output );
		me.props_in_pressure_N.setDoubleValue( source );
		me.props_out_pressure_N.setDoubleValue( output );

	#    print (me.name, " output ", me.output_N.getValue());
		
	},
	setServiceable : func (serviceable) {
		me.props_serviceable_N.setBoolValue( serviceable ); 
	},
	list : [],
};

###
#=============================== functions ===============================
# 
#============================ GearLever ===================================


var run_gear = func {

	var gear_control = getprop("controls/hydraulic/lever");
	var valve = 0;
	var gear_lever = 0;

	var gearleft = getprop("gear/gear/position-norm");
	var uplockleft = 0;
	var downlockleft = 0;

	var gearright = getprop("gear/gear[1]/position-norm");
	var uplockright = 0;
	var downlockright = 0;

#   print ("gearleft ", gearleft, " gearright ", gearright, " gear_control ", gear_control, " valve ", valve);

	if ( gearleft >= 0 and gearleft <= 0.05 and gear_control == 1){
		valve = -1;
		} elsif (gearleft >= 0.95 and gearleft <= 1 and gear_control == 0){
			valve = 1;
		} else {
			valve = 0;
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

#  print ("gearleft ", gearleft, " gearright ", gearright, " gear_control ", gear_control, " valve ", valve);

		if( valve == -1 and gear_control == 1){
			interpolate("controls/gear/gear-lever", -0.2, 0.1);
			settimer(run_gear, 0);
			} elsif (!downlockleft and !downlockright and gear_control == 1){
				interpolate("controls/gear/gear-lever", 1.0, 1.0);
				interpolate("controls/gear/oil-flow", 0.5, 1);
				settimer(run_gear, 0);
			} elsif( valve == 1 and gear_control == -1){
				interpolate("controls/gear/gear-lever", 0.2, 0.1);
				settimer(run_gear, 0);
			} elsif (!uplockleft and !uplockright and gear_control == -1){
				interpolate("controls/gear/gear-lever", -1.0, 1.0);
				interpolate("controls/gear/oil-flow", -1, 0.5);
				settimer(run_gear, 0);
			} else {
				interpolate("controls/gear/gear-lever", 0, 1.0);
				interpolate("controls/gear/oil-flow", 0, 0.5);
				}
	}
# ==================== Fire it up =====================

setlistener("sim/signals/fdm-initialized", initialize);

# end 


