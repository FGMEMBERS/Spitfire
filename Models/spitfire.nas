# $Id$

# ************** Cofman starter stuff ***************

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
	if(start) {
		i = getprop("controls/engines/engine/coffman-starter/index");
		j= "controls/engines/engine/coffman-starter/cartridge" ~ "[" ~ i ~ "]";
		setprop("controls/engines/engine/coffman-starter/starter-push-norm",1);
		if (getprop(j)) { 									# if cartridge hasn't been fired
			setprop("controls/engines/engine/starter",1); 	# starter runs
			setprop(j,0) 									# fire this cartridge
		}	
	}else{
		setprop("controls/engines/engine/starter",0);
		setprop("controls/engines/engine/coffman-starter/starter-push-norm",0)
	}
			
} # end function

# =============== magneto stuff========================

setMagnetos = func{ # set the magneto value according to the switch positions

	right = getprop("controls/engines/engine/mag-switch-right");
	left = getprop("controls/engines/engine/mag-switch-left");
	if (left and right){ # both
		setprop("controls/engines/engine/magnetos",3); 
		}
		elsif (left and !right) { # left
			setprop("controls/engines/engine/magnetos",1)
		}
		elsif (!left and right) { # right
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
	if(left) {
	setprop("controls/engines/engine/mag-switch-left",0)
	}else{
	setprop("controls/engines/engine/mag-switch-left",1)
	}
	spitfire.setMagnetos();

} # end function

togglerightMagswitch = func{
	
	right = getprop("controls/engines/engine/mag-switch-right");
	if(right) {
	setprop("controls/engines/engine/mag-switch-right",0)
	}else{
	setprop("controls/engines/engine/mag-switch-right",1)
	}
	spitfire.setMagnetos();

} # end function

# ==================== end magneto stuff =========================

# ==================== door and canopy ==================================

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
		if (!dooropen) {
			setprop("controls/flight/door-position-norm",1)
		} else {
			setprop("controls/flight/door-position-norm",0)
			}
	}
	
} # end function

openCanopy = func{ # open the canopy if door is closed
	
	canopyopen = arg[0];
	dooropen = getprop("controls/flight/door-position-norm");
	if (!dooropen) {
		setprop("controls/flight/wing-fold",canopyopen)
	}

} # end function

# ==================== end door and canopy ===================================

# ************** Cutoff ***************

pullCutoff = func{
    pull=arg[0];
	# mixture = getprop("controls/engines/engine/mixture");
	if(pull) {
		setprop("controls/engines/engine/cutoff-pull-norm",1);
		setprop("controls/engines/engine/cutoff",0);
		setprop("controls/engines/engine/mixture",0)
	}else{
		setprop("controls/engines/engine/cutoff-pull-norm",0);
		setprop("controls/engines/engine/cutoff",1);
		setprop("controls/engines/engine/mixture",1)
		}

} # end function