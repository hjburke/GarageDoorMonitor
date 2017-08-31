//--------------------------------------------------------------------------------------------------------
// GarageDoorMonitor.device.nut
//
// A garage door monitor and controller based on the Electric Imp IoT platform.
// This is the code that runs on the hardware device and uses the GPIO pins to
// monitor the position of 2 garage doors, using limit switches installed to monitor
// the fully open and fully closed position of the doors.
// Additionally, gpio outputs are used to control relays which simulate the pressing
// of the open/close button.
//
// (c) Burketech 2017 
//--------------------------------------------------------------------------------------------------------

//--------------------------------------------------------------------------------------------------------
// Libraries
//--------------------------------------------------------------------------------------------------------

#require "Button.class.nut:1.2.0"

//--------------------------------------------------------------------------------------------------------
// Constants
//--------------------------------------------------------------------------------------------------------

const OPEN_STATE    = "Open";
const OPENING_STATE = "Opening";
const CLOSED_STATE  = "Closed";
const CLOSING_STATE = "Closing";
const PARTIAL_STATE = "Partial";
const DOOR1         = "Left"
const DOOR2         = "Right"

//--------------------------------------------------------------------------------------------------------
// Define which pins are input and outputs for door1 and door2
//--------------------------------------------------------------------------------------------------------

g1OpenSwitch <- hardware.pin7;
g1ClosedSwitch <- hardware.pin8;
g1Relay <- hardware.pin9;

g2OpenSwitch <- hardware.pin1;
g2ClosedSwitch <- hardware.pin2;
g2Relay <- hardware.pin5;

g1Relay.configure(DIGITAL_OUT,0);
g2Relay.configure(DIGITAL_OUT,0);

//--------------------------------------------------------------------------------------------------------
// Turn relay on for 1/2 second and then off
//--------------------------------------------------------------------------------------------------------

function pulseRelay(relay)
{
    relay.write(1);
    imp.sleep(0.5);
    relay.write(0);
}

//--------------------------------------------------------------------------------------------------------
// Use the de-bounced button library to track the door status
//
// NOTE: Currently the Button library only supports a 10ms debounce time, this does not
//       seem to be long enough for the magnetic reed switches to not bounce a little.
//--------------------------------------------------------------------------------------------------------

door1Open <- Button(g1OpenSwitch,DIGITAL_IN_PULLUP)
.onPress(function() {
    agent.send("doorstatus",{"door":DOOR1,"status":OPEN_STATE})
})
.onRelease(function() {
    agent.send("doorstatus",{"door":DOOR1,"status":CLOSING_STATE});
});

door1Close <- Button(g1ClosedSwitch,DIGITAL_IN_PULLUP)
.onPress(function() {
    agent.send("doorstatus",{"door":DOOR1,"status":CLOSED_STATE});
})
.onRelease(function() {
    agent.send("doorstatus",{"door":DOOR1,"status":OPENING_STATE});
});

door2Open <- Button(g2OpenSwitch,DIGITAL_IN_PULLUP)
.onPress(function() {
    agent.send("doorstatus",{"door":DOOR2,"status":OPEN_STATE})
})
.onRelease(function() {
    agent.send("doorstatus",{"door":DOOR2,"status":CLOSING_STATE});
});

door2Close <- Button(g2ClosedSwitch,DIGITAL_IN_PULLUP)
.onPress(function() {
    agent.send("doorstatus",{"door":DOOR2,"status":CLOSED_STATE});
})
.onRelease(function() {
    agent.send("doorstatus",{"door":DOOR2,"status":OPENING_STATE});
});

//--------------------------------------------------------------------------------------------------------
// Handle calls from Agent to press one of the door buttons
//--------------------------------------------------------------------------------------------------------

agent.on("pressButton", function(value) {
    if (value["door"] == DOOR1) {
        server.log("Pressing button for "+DOOR1+" door")
        pulseRelay(g1Relay);
    }
    if (value["door"] == DOOR2) {
        server.log("Pressing button for "+DOOR2+" door")
        pulseRelay(g2Relay);
    }
})

//--------------------------------------------------------------------------------------------------------
// Get the initial status of the doors
//--------------------------------------------------------------------------------------------------------

if (g1OpenSwitch.read() == 0)
    agent.send("doorstatus",{"door":DOOR1,"status":OPEN_STATE})
else if (g1ClosedSwitch.read() == 0)
    agent.send("doorstatus",{"door":DOOR1,"status":CLOSED_STATE})
else
    agent.send("doorstatus",{"door":DOOR1,"status":PARTIAL_STATE});

if (g2OpenSwitch.read() == 0)
    agent.send("doorstatus",{"door":DOOR2,"status":OPEN_STATE})
else if (g2ClosedSwitch.read() == 0)
    agent.send("doorstatus",{"door":DOOR2,"status":CLOSED_STATE})
else
    agent.send("doorstatus",{"door":DOOR2,"status":PARTIAL_STATE});

//--------------------------------------------------------------------------------------------------------
// END
//--------------------------------------------------------------------------------------------------------
