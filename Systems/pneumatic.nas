###############################################################################
##
##  Pneumatic system module for FlightGear.
##
##  Copyright (C) 2012  Vivian Meazza  (vivian.meazza(at)lineone.net)
##  This file is licensed under the GPL license v2 or later.
##
###############################################################################
# Properties under /systems/pneumatic:
# + servicable      - Current status  Must be set by user code.

# + pressure        - OUTPUT ONLY property, do not try to set

# ==================================== Definiions ===========================================
# set constants 
MAX_PRESSURE = 300.0;
MIN_PRESSURE = 100.0;
INHG2PSI = 0.491154077497;
MAXTANKS = 2;

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
var min_pressure = 0;
var pump = nil;

var valve = nil;
var valve_1 = nil;
var valve_2 = nil;

var actuator = nil;
var actuator_1 = nil;
var actuator_2 = nil;
var actuator_3 = nil;
var actuator_4 = nil;
var actuator_5 = nil;
var actuator_6 = nil;
var actuator_7 = nil;
var actuator_8 = nil;
var actuator_9 = nil;
#var actuator_10 = nil;
#var actuator_11 = nil;
#var actuator_12 = nil;
#var actuator_13 = nil;

var relief = nil;
var relief_1 = nil;

var non_return = nil;

var proportionator  = nil;

var tank = nil;
var tank_1 = nil;

var IAS_N = props.globals.getNode("/velocities/airspeed-kt", 1);

var lowpass = aircraft.lowpass.new(1.5);

var initialize = func {

print( "Initializing Pneumatic System ..." );

props.globals.initNode("/controls/pneumatic/system/engine-pump", 1, "BOOL");
props.globals.initNode("/systems/pneumatic/serviceable", 1, "BOOL");
props.globals.initNode("/systems/pneumatic/pressure-psi", 0, "DOUBLE");
props.globals.initNode("/controls/pneumatic/lever", 1, "DOUBLE");
props.globals.initNode("/controls/pneumatic/lever[1]", 0, "DOUBLE");
props.globals.initNode("/controls/pneumatic/lever[2]", 0, "DOUBLE");
props.globals.initNode("/systems/pneumatic/outputs/brake", 1, "DOUBLE");
props.globals.initNode("/systems/pneumatic/outputs/brake[1]", 1, "DOUBLE");
#props.globals.initNode("/systems/pneumatic/outputs/flap[0]", 0, "DOUBLE");
#props.globals.initNode("/systems/pneumatic/outputs/flap[1]", 0, "DOUBLE");
props.globals.initNode("/environment/pressure-inhg", 0, "DOUBLE");

#for (var i = 0; i < MAXTANKS; i += 1){
#	props.globals.initNode("/consumables/air/tank["~ i ~ "]/capacity-cu-ft", 0.001, "DOUBLE");
#	props.globals.initNode("/consumables/air/tank["~ i ~ "]/level-cu-ft", 0, "DOUBLE");
#	props.globals.initNode("/consumables/air/tank["~ i ~ "]/selected", 0, "BOOL");
#	props.globals.initNode("/consumables/air/tank["~ i ~ "]/pressure-in-psi", 0, "DOUBLE");
#	props.globals.initNode("/consumables/air/tank["~ i ~ "]/pressure-psi", 0, "DOUBLE");
#	}

for (i = 0; i < 6; i += 1){
	props.globals.initNode("/systems/pneumatic/outputs/trigger-gun["~ i ~ "]", 1, "BOOL");
	}

###
# overwrite this variable in controls.nas
#
controls.fullBrakeTime = 0.001;

controls.applyParkingBrake = func(v) {
    if (!v) { return; }
    var p = "/controls/gear/brake-left";
    setprop(p, var i = !getprop(p));
    return i;
}

###
# suppliers ("name", "rpm source", "control property", status, factor)
#
	pump = Pump.new("pump-engine",
					"engines/engine[0]/rpm",
					"controls/pneumatic/system/engine-pump",
					1,
					0.5);

###
# non-return valves ("name", "input property", status)
#
	non_return_valve = NonReturn.new("pump",
					"systems/pneumatic/suppliers/pump-engine/pressure-out-psi",
					1);

###
# pressure control valves ("name", "source", status, max pressure)
#
	relief = Relief.new("pressure-regulator",
					"systems/pneumatic/non-return-valves/pump/pressure-out-psi",
					1,
					MAX_PRESSURE);

	relief_1 = Relief.new("pressure-reducing",
					"/consumables/air/tank1/pressure-psi",
					1,
					200);

###
# tanks ("name", "source property", capacity, level, selected)
#
	tank = Tank.new("tank",
					"systems/pneumatic/relief-valves/pressure-regulator/pressure-out-psi",
					0.8,
					16.326,
					1);

	tank_1 = Tank.new("tank1",
					"/consumables/air/tank/pressure-psi",
					0.8,
					16.326,
					1);

###
# valves ("name", "input property", "control property", status, initial state)
#
	valve = Valve.new("brakes",
					"systems/pneumatic/pressure-psi",
					"controls/gear/brake-left",
					1,
					1);
					
	valve_1 = Valve.new("trigger",
					"systems/pneumatic/pressure-psi",
					"controls/armament/trigger",
					1,
					0);

	valve_3 = Valve.new("flaps",
					"systems/pneumatic/pressure-psi",
					"controls/flight/flaps-lever",
					1,
					0);

###
# proportionator valves ("name", "input property", "control property", status, threshold)
# 
	proportionator_valve = Proportionator.new("brakes",
					"systems/pneumatic/valves/brakes/pressure-out-psi",
					"controls/flight/rudder",
					1,
					0.3);

###
# actuators ("name", "input property", "output property", "position property",
# status, capacity, min, max, initial state)
#
	actuator = Actuator.new("brake",
					"systems/pneumatic/proportionators/brakes/pressure-out-psi",
					"systems/pneumatic/outputs/brake",
					"gear/gear/position-norm",
					1,
					0.01,
					0,
					1,
					1);

	actuator_1 = Actuator.new("brake-1",
					"systems/pneumatic/proportionators/brakes/pressure-out-psi[1]",
					"systems/pneumatic/outputs/brake[1]",
					"gear/gear/position-norm",
					1,
					0.01,
					0,
					1,
					1);

	actuator_2 = Actuator.new("trigger",
					"systems/pneumatic/valves/trigger/pressure-out-psi",
					"systems/pneumatic/outputs/trigger-gun",
					"systems/pneumatic/actuators/trigger/position-norm",
					1,
					0.005,
					0,
					1,
					0);

	actuator_3 = Actuator.new("trigger-1",
					"systems/pneumatic/valves/trigger/pressure-out-psi",
					"systems/pneumatic/outputs/trigger-gun[1]",
					"systems/pneumatic/actuators/trigger-1/position-norm",
					1,
					0.005,
					0,
					1,
					0);

	actuator_4 = Actuator.new("trigger-2",
					"systems/pneumatic/valves/trigger/pressure-out-psi",
					"systems/pneumatic/outputs/trigger-gun[2]",
					"systems/pneumatic/actuators/trigger-2/position-norm",
					1,
					0.005,
					0,
					1,
					0);

	actuator_5 = Actuator.new("trigger-3",
					"systems/pneumatic/valves/trigger/pressure-out-psi",
					"systems/pneumatic/outputs/trigger-gun[3]",
					"systems/pneumatic/actuators/trigger-3/position-norm",
					1,
					0.005,
					0,
					1,
					0);

	actuator_6 = Actuator.new("trigger-4",
					"systems/pneumatic/valves/trigger/pressure-out-psi",
					"systems/pneumatic/outputs/trigger-gun[4]",
					"systems/pneumatic/actuators/trigger-4/position-norm",
					1,
					0.005,
					0,
					1,
					0);

	actuator_7 = Actuator.new("trigger-5",
					"systems/pneumatic/valves/trigger/pressure-out-psi",
					"systems/pneumatic/outputs/trigger-gun[5]",
					"systems/pneumatic/actuators/trigger-5/position-norm",
					1,
					0.005,
					0,
					1,
					0);

	actuator_8 = Actuator.new("flap",
					"systems/pneumatic/valves/flaps/pressure-out-psi",
					"systems/pneumatic/outputs/flaps",
					"surface-positions/flap-pos-norm",
					1,
					0.1,
					0,
					200,
					0);

	actuator_9 = Actuator.new("flap-1",
					"systems/pneumatic/valves/flaps/pressure-out-psi",
					"systems/pneumatic/outputs/flaps[1]",
					"surface-positions/flap-pos-norm[1]",
					1,
					0.1,
					0,
					1,
					0);

# =============================== listeners ===============================
#

# =============================== start it up ===============================
#
print( "... done" );
update_pneumatic();

} #end init

###
# =================== pneumatic system =========================
#
###
# This is the main loop which keeps eveything updated
#
update_pneumatic = func {
#	time = props.globals.getNode("/sim/time/elapsed-sec", 1).getValue();
#	dt = time - last_time;
#	last_time = time;

# set the ambient pressure
min_pressure = sprintf("%0.3f", getprop("environment/pressure-inhg") * INHG2PSI);

	foreach (var p; Pump.list)
		{
		p.update();
		}

	foreach (var nrv; NonReturn.list)
		{
		nrv.update();
		}

	foreach (var r; Relief.list)
		{
		r.update();
		}

setprop("systems/pneumatic/pressure-psi", relief_1.output);
#	getprop("systems/pneumatic/relief-valves/pressure-regulator/pressure-out-psi"));

	foreach (var t; Tank.list)
		{
		t.update();
		}

	foreach (var v; Valve.list)
		{
		v.update();
		}

	foreach (var prp; Proportionator.list)
		{
		prp.update();
		}

	foreach (var a; Actuator.list)
		{
		a.update();
		}

# Request that the update fuction be called again 
	registerTimer(update_pneumatic);
}

##
# Pump class. Defines a pneumatic pump

Pump = {
	 new : func(name, source, control, serviceable, factor) {
		var obj = { parents : [ Pump ] };
		obj.name = name;
#		print ("name ", name);
#		#print ("output ", output);
		obj.rpm_source_N = props.globals.getNode( source, 1 );
		obj.rpm_source_N.setDoubleValue(0);
		obj.control_N = props.globals.getNode( control, 1 );
		obj.control_N.setBoolValue( 1 );
		obj.factor = factor;

		obj.props_N = props.globals.getNode( "systems/pneumatic/suppliers", 1 ).getChild(name, 0, 1);
		obj.props_serviceable_N = obj.props_N.getChild("serviceable", 0, 1);
		obj.props_serviceable_N.setBoolValue( serviceable );
		obj.props_out_pressure_N = obj.props_N.getChild("pressure-out-psi", 0, 1);
		obj.props_out_pressure_N.setDoubleValue( min_pressure );
		append(Pump.list, obj); 
		return obj;
	},
	update : func {
		var rpm = me.rpm_source_N.getValue();
		var serviceable = me.props_serviceable_N.getValue();
		var control = me.control_N.getValue();
		var factor = me.factor;

		if (serviceable)
			{
			pressure = math.max(factor * rpm * control, min_pressure);
			}
		else
			{
			pressure = min_pressure;
			}

	me.props_out_pressure_N.setDoubleValue(pressure);
#   print ("punp pressure-psi ", pressure);
		
	},
	setMaxPressure : func (pressure) {
		me.max_pressure = pressure;
	},
	setServiceable : func (serviceable) {
		me.props_serviceable_N.setBoolValue( serviceable ); 
	},
	list : [],
};

# Valve class. Defines a valve in the pneumatic system. Input is a pneumatic pressure source, output is used 
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

		obj.props_N = props.globals.getNode( "systems/pneumatic/valves", 1 ).getChild(name, 0, 1);
		obj.props_serviceable_N = obj.props_N.getChild("serviceable", 0, 1);
		obj.props_serviceable_N.setBoolValue( serviceable );
		obj.props_in_pressure_N = obj.props_N.getChild("pressure-in-psi", 0, 1);
		obj.props_in_pressure_N.setDoubleValue( 0 );
		obj.props_out_pressure_N = obj.props_N.getChild("pressure-out-psi", 0, 1);
		obj.props_out_pressure_N.setDoubleValue( 0 );

		append(Valve.list, obj); 
		return obj;
	},
	update : func {
		var source = me.source_N.getValue();
		var control = clamp(me.control_N.getValue(), -1, 1); 
		var serviceable = me.props_serviceable_N.getValue();
		var output_pressure = 0;
#		print (me.name," source ", source, " control " , control);

		if (serviceable)
			{
			output_pressure= math.max( source * control, min_pressure );
			}
		else
			{
			output_pressure = min_pressure;
			}

		me.props_in_pressure_N.setDoubleValue(source);
		me.props_out_pressure_N.setDoubleValue(output_pressure);

#		print (me.name, " valve output ", output_pressure);
		
	},
	setServiceable : func (serviceable) {
		me.props_serviceable_N.setBoolValue( serviceable ); 
	},
	list : [],
};

# Actuator class. Defines an actuator in the pneumatic system.  The output can be used to drive 
# control surfaces etc 

Actuator = {
	 new : func(name, source, output, pos_norm, serviceable, capacity, min, max, state) {
		var obj = { parents : [ Actuator ] };
		obj.name = name;
#		print ("name ", name);
#		print ("source ", source);
#		print ("output ", output);
#		print ("pos_norm ", pos_norm, " state ", state);
		obj.source_N = props.globals.getNode( source, 1 );
		obj.source_N.setDoubleValue( 0 );
		obj.output_N = props.globals.getNode( output, 1 );
		obj.output_N.setDoubleValue( state );
		obj.position_norm_N = props.globals.getNode( pos_norm, 1 );
		obj.position_norm_N.setDoubleValue( state );
		obj.capacity = capacity;
		obj.min = min;
		obj.max = max;

		obj.props_N = props.globals.getNode( "systems/pneumatic/actuators", 1 ).getChild(name, 0, 1);
		obj.props_serviceable_N = obj.props_N.getChild("serviceable", 0, 1);
		obj.props_serviceable_N.setBoolValue( serviceable );
		obj.props_in_pressure_N = obj.props_N.getChild("pressure-in-psi", 0, 1);
		obj.props_in_pressure_N.setDoubleValue( obj.source_N.getValue() );
		obj.props_position_norm_N = obj.props_N.getChild("position-norm", 0, 1);
		obj.props_position_norm_N.setDoubleValue( state );
		obj.props_back_pressure_N = obj.props_N.getChild("back-pressure-psi", 0, 1);
		obj.props_back_pressure_N.setDoubleValue( 0 );

		setlistener(obj.output_N, func (n){
			var actuator_pos_norm = obj.props_position_norm_N.getValue();
			var name = obj.name;
			var pressure = obj.source_N.getValue();
			var in_pressure = obj.props_in_pressure_N.getValue();
			var level = calcLevel(in_pressure - min_pressure, obj.capacity);
			tank.setLevel(level);

#			print("listener ", name, " ", actuator_pos_norm, " " , pressure, " " , in_pressure, " level ", level,
#			" capacity ", capacity);

			},
			0,
			0);

#		setlistener(obj.source_N, func (n){
#			obj.update();

#			print("listener 2 ", obj.name, " source ",  n.getValue() );

#			},
#			0,
#			0);

		append(Actuator.list, obj); 
		return obj;
	},
	update : func {
		var source = me.source_N.getValue();
		var serviceable = me.props_serviceable_N.getValue();
		var state = me.position_norm_N.getValue();
		var airspeed = IAS_N.getValue();
		var output = 0;
		var back_pressure = 0;
#		print("flap_pos ", getprop("surface-positions/flap-pos-norm"));
#		print (me.name, " input ", output, " source ", source, " state ", state);

		if(me.name == "flap" or me.name == "flap-1") back_pressure = me.getBackPressure(state);

		var input = source - back_pressure;

		if (input >= MIN_PRESSURE and serviceable)
			{
			output = (input)/me.max;
			}
		elsif (input < MIN_PRESSURE and input > 50 and serviceable)
			{
			output = state;
#			print (me.name," no movement ", input, " out ", output);
			}
		else
			{
			output = 0;
#			print (me.name," close ", input, " out ", output);
			}

#		print (me.name, " output ", output, " source ", source, " state ", state);
		output = clamp(output, me.min, me.max); 
		me.output_N.setDoubleValue( output );
		me.props_position_norm_N.setDoubleValue( state );
		me.props_in_pressure_N.setDoubleValue( source );
		me.props_back_pressure_N.setDoubleValue( back_pressure );

	},
	setServiceable : func (serviceable) {
		me.props_serviceable_N.setBoolValue( serviceable ); 
	},
	getPressure : func () {
	me.update();
	return me.props_in_pressure_N.getValue(); 
	},
	getBackPressure : func (state) {
	var airspeed = IAS_N.getValue();
		
	# An arbitrary function which provides a non-linear relationship between
	# back pressure,  airspeed and flap extension
	# y = 4E-05x2 - 0.4495x + 0.4504
	# y = 4E-06x2 - 0.0449x + 0.045

	var back_pressure = 0.000004 * (airspeed * airspeed * state) * (airspeed * airspeed * state)
		- 0.0449 * (airspeed * airspeed * state) + 0.045;
	back_pressure = math.max(back_pressure, 0);
	back_pressure = lowpass.filter(back_pressure);
 
#	print (me.name, " back_pressure ", back_pressure, " airspeed ", airspeed, " state " , state);
		
	return back_pressure;
		},
	list : [],
};

# Relief Valve class. Defines a relief valve in the pneumatic system.  The output controls
# the pressure in the pneumatic system.
# "name", "input property", "control property", "output property", status,
# max, initial state

Relief = {
	 new : func(name, source, serviceable, max) {
		var obj = { parents : [ Relief ] };
		obj.name = name;
#		print ("name ", name);
#       print ("source ", source);
#		print ("output ", output);
		obj.source_N = props.globals.getNode( source, 1 );
		obj.source_N.setDoubleValue( min_pressure );
		obj.max = max;
		obj.output = 0;

		obj.props_N = props.globals.getNode( "systems/pneumatic/relief-valves", 1 ).getChild(name, 0, 1);
		obj.props_serviceable_N = obj.props_N.getChild("serviceable", 0, 1);
		obj.props_serviceable_N.setBoolValue( serviceable );
		obj.props_in_pressure_N = obj.props_N.getChild("pressure-in-psi", 0, 1);
		obj.props_in_pressure_N.setDoubleValue( obj.source_N.getValue() );
		obj.props_out_pressure_N = obj.props_N.getChild("pressure-out-psi", 0, 1);
		obj.props_out_pressure_N.setDoubleValue( obj.source_N.getValue() );

		append(Relief.list, obj); 
		return obj;
	},
	update : func {
		var source = me.source_N.getValue();
		var serviceable = me.props_serviceable_N.getValue();
		me.output = source;
#		print (me.name, " source ", source, " control " , control);

		if (serviceable)
			{
			me.output = clamp(source, min_pressure, me.max);
			}
		else
			{
			me.output = source;
			}

		me.props_in_pressure_N.setDoubleValue( source );
		me.props_out_pressure_N.setDoubleValue( me.output );

#		print (me.name, " output ", me.output_N.getValue());
		
	},
	setServiceable : func (serviceable) {
		me.props_serviceable_N.setBoolValue( serviceable ); 
	},
	list : [],
};

NonReturn = {
	 new : func(name, source, serviceable) {
		var obj = { parents : [ NonReturn ] };
		obj.name = name;
#		print ("name ", name);
#        print ("input ", input);
#		print ("output ", output);
		obj.source_N = props.globals.getNode( source, 1 );
		obj.source_N.setDoubleValue( min_pressure );

		obj.props_N = props.globals.getNode( "systems/pneumatic/non-return-valves", 1 ).getChild(name, 0, 1);
		obj.props_serviceable_N = obj.props_N.getChild("serviceable", 0, 1);
		obj.props_serviceable_N.setBoolValue( serviceable );
		obj.props_in_pressure_N = obj.props_N.getChild("pressure-in-psi", 0, 1);
		obj.props_in_pressure_N.setDoubleValue( obj.source_N.getValue() );
		obj.props_out_pressure_N = obj.props_N.getChild("pressure-out-psi", 0, 1);
		obj.props_out_pressure_N.setDoubleValue( obj.source_N.getValue() );

		append(NonReturn.list, obj); 
		return obj;
	},
	update : func {
		var input = me.source_N.getValue();
		var output = min_pressure;
		var serviceable = me.props_serviceable_N.getValue();

#		print (me.name, " source ", source, " control " , control);

		if (serviceable)
			{
			output = math.max(input, output);
			}

#		me.output_N.setDoubleValue( output );
		me.props_in_pressure_N.setDoubleValue( input );
		me.props_out_pressure_N.setDoubleValue( output );

#	    print (me.name, " output ", me.output_N.getValue());
		
	},
	setServiceable : func (serviceable) {
		me.props_serviceable_N.setBoolValue( serviceable ); 
	},
	list : [],
};

Proportionator = {
	 new : func(name, source, control, serviceable, threshold) {
		var obj = { parents : [Proportionator ] };
		obj.name = name;
#		print ("name ", name);
#        print ("input ", source);
#		print ("control ", control);
		obj.source_N = props.globals.getNode( source, 1 );
		obj.source_N.setDoubleValue( min_pressure );
		obj.control_N = props.globals.getNode( control, 1 );
		obj.control_N.setDoubleValue( 0 );
		obj.threshold = threshold;

		obj.props_N = props.globals.getNode( "systems/pneumatic/proportionators", 1 ).getChild(name, 0, 1);
		obj.props_serviceable_N = obj.props_N.getChild("serviceable", 0, 1);
		obj.props_serviceable_N.setBoolValue( serviceable );
		obj.props_in_pressure_N = obj.props_N.getChild("pressure-in-psi", 0, 1);
		obj.props_in_pressure_N.setDoubleValue( obj.source_N.getValue() );
		obj.props_out_pressure1_N = obj.props_N.getChild("pressure-out-psi", 0, 1);
		obj.props_out_pressure1_N.setDoubleValue( obj.source_N.getValue() );
		obj.props_out_pressure2_N = obj.props_N.getChild("pressure-out-psi", 1, 1);
		obj.props_out_pressure2_N.setDoubleValue( obj.source_N.getValue() );
		obj.props_control_N = obj.props_N.getChild("control", 0, 1);
		obj.props_control_N.setDoubleValue( 0 );
		
		append(Proportionator.list, obj); 
		return obj;
	},
	update : func {
		var input = me.source_N.getValue();
		var control = me.control_N.getValue();
		var threshold = me.threshold;
		var serviceable = me.props_serviceable_N.getValue();

#		print (me.name, " input ", input, " control " , control);

		if (serviceable)
			{
			if (control > threshold)
				me.setOutput( min_pressure, input );
			elsif (control < -threshold)
				me.setOutput( input, min_pressure );
			else
				me.setOutput( input, input );
			}

		me.props_in_pressure_N.setDoubleValue( input );
		me.props_control_N.setDoubleValue( control );

#	    print (me.name, " output ", me.output_N.getValue());
		
	},
	setServiceable : func (serviceable) {
		me.props_serviceable_N.setBoolValue( serviceable ); 
	},
	setOutput: func (output1, output2) {
		me.props_out_pressure1_N.setDoubleValue( output1 );
		me.props_out_pressure2_N.setDoubleValue( output2 );
	},
	list : [],
};

Tank = {
	 new : func(name, source, capacity, level, selected) {
		var obj = { parents : [Tank] };
		obj.name = name;
#		print ("name ", name);
#        print ("input ", source);
#		print ("output1 ", output1);
#		print ("output2 ", output2);
		obj.source_N = props.globals.getNode( source, 1 );
		obj.source_N.setDoubleValue( min_pressure );
#		obj.output_N = props.globals.getNode( output, 1 );
#		obj.output_N.setDoubleValue( min_pressure );
		obj.capacity = capacity;
		obj.level = level;

		obj.props_N = props.globals.getNode( "/consumables/air", 1 ).getChild(name, 0, 1);
		obj.props_selected_N = obj.props_N.getChild("selected", 0, 1);
		obj.props_selected_N.setBoolValue( selected );
		obj.props_in_pressure_N = obj.props_N.getChild("pressure-in-psi", 0, 1);
		obj.props_in_pressure_N.setDoubleValue( obj.source_N.getValue() );
		obj.props_capacity_N = obj.props_N.getChild("capacity-cu-ft", 0, 1);
		obj.props_capacity_N.setDoubleValue( capacity );
		obj.props_out_pressure_N = obj.props_N.getChild("pressure-psi", 0, 1);
		obj.props_out_pressure_N.setDoubleValue( obj.source_N.getValue() );
		obj.props_level_N = obj.props_N.getChild("level-cu-ft", 0, 1);
		obj.props_level_N.setDoubleValue( level );
		obj.props_name_N = obj.props_N.getChild("name", 0, 1);
		obj.props_name_N.setValue( name );

		append(Tank.list, obj); 
#		print ("size ", size(Tank.list));
		return obj;
	},
	update : func {
	var source = me.source_N.getValue();
	var level = me.props_level_N.getValue();
	var capacity = me.capacity;
	var pressure = calcPressure( level, capacity );
	
#	print(me.name, " source ", source, " pressure ", pressure, " level ", level, " capacity ", capacity, " ", size(Tank.list));

	if (source > pressure)
		{
		level = calcLevel(source, capacity);
#		print(me.name, " source ", source, " level ", level);
		}

	pressure = calcPressure( level, capacity );
	me.props_in_pressure_N.setDoubleValue(source);
	me.props_out_pressure_N.setDoubleValue(pressure);
	me.props_level_N.setDoubleValue(level);
#	me.output_N.setDoubleValue(pressure);

#	print(me.name, " level ", level , " pressure ", pressure);	
	},
	setSelected : func (selected) {
		me.props_selected_N.setBoolValue( selected ); 
	},
	setOutput: func (output1, output2) {
	},
	setLevel: func(n) {
#	print(me.name, " n ", n, " level ", me.props_level_N.getValue());
	var level = me.props_level_N.getValue() - n;
#	print(me.name, "new level ", level);
	level = math.max(level, me.capacity);
	me.props_level_N.setDoubleValue( level );
	},
	list : [],
};

###
#=============================== functions ===============================
# 
# We apply Boyle's Law to derive the pressure in the tank fom the capacity of a
# tank and the contents. We ignore the effects of temperature.

var calcPressure = func (cu_ft, cap){
    var Vc = cap;
    var Va = cu_ft;
    var Pa = 14.7;

#    print (Vc, " ", Va, " ", Pa);

    Pc = (Pa * Va)/Vc;
    return Pc;
}# end func calcPressure
 
var calcLevel = func (pressure, cap){
    var Vc = cap;
    var Va = 0;
    var Pa = 14.7;
	var Pc = pressure;

    Va = (Pc * Vc)/Pa;

#	print (" calclevel capacity ", Vc, " level calc", Va, " Pa ", Pa, " Pressure  ", Pc);
    return Va;
}# end func calcLevel

# ==================== Fire it up =====================

setlistener("sim/signals/fdm-initialized", initialize);

# end 


