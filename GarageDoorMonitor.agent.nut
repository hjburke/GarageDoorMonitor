//--------------------------------------------------------------------------------------------------------
// GarageDoorMonitor.agent.nut
//
// A garage door monitor and controller based on the Electric Imp IoT platform.
// This is the code that runs in the Electric Imp cloud.
//
// (c) Burketech 2017 
//--------------------------------------------------------------------------------------------------------

//--------------------------------------------------------------------------------------------------------
// Libraries
//--------------------------------------------------------------------------------------------------------

#require "Dweetio.class.nut:1.0.1"
#require "Rocky.class.nut:2.0.0"
#require "Utilities.nut:1.0.0"

//--------------------------------------------------------------------------------------------------------
// Constants
//--------------------------------------------------------------------------------------------------------

const DOOR1         = "Left"
const DOOR2         = "Right"

const INDEX = @"
<!DOCTYPE html>
<html lang='en-US'>
 <head>
  <meta charset='UTF-8'>
  <meta http-equiv='X-UA-Compatible' content='IE=edge'>

  <meta name='viewport' content='width=device-width, initial-scale=1'>
  <meta name='mobile-web-app-capable' content='yes'>
  <link rel='stylesheet' href='//maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css' integrity='sha384-BVYiiSIFeK1dGmJRAkycuHAHRg32OmUcww7on3RYdg4Va+PmSTsz/K68vbdEjh4u' crossorigin='anonymous'>
  <link href='//fonts.googleapis.com/css?family=Play' rel='stylesheet'>
  <style>
   .center { margin-left: auto; margin-right: auto; margin-bottom: auto; margin-top: auto; }
   body {background-color: #3366cc}
   h1 {color: #99ccff; font-family: Play, sans-serif; font-weight:bold; text-align:center}
   p {color: white; font-family: Play, sans-serif; font-weight:bold; font-size:18px}
  </style>
  <title>GDM</title>
 </head>
 <body>

  <h1>Garage Door Monitor</h1>
  <div class='container-fluid'>
   <div class='row'>
    <div class='col-xs-6 text-right' id='left-status'><img src='//res.cloudinary.com/burketech/image/upload/v1505852890/GDM/Unknown.png' width='150px' onclick='postPush(""Left"");'><p>Unknown</p></div>
    <div class='col-xs-6' id='right-status'><img src='//res.cloudinary.com/burketech/image/upload/v1505852890/GDM/Unknown.png' width='150px' onclick='postPush(""Right"");'><p>Unknown</p></div>
   </div>
  </div>
  <script src='//ajax.googleapis.com/ajax/libs/jquery/3.2.1/jquery.min.js'></script>
  <script>
   var agenturl = '%s';
   var apikey = '%s';
   getState(updateReadout);

    function updateReadout(data) {
     var imgl='//res.cloudinary.com/burketech/image/upload/v1505852890/GDM/'+data.Left+'.png';
     var imgr='//res.cloudinary.com/burketech/image/upload/v1505852890/GDM/'+data.Right+'.png';
     $('#left-status img').attr('src',imgl);
     $('#left-status p').text(data.LChng);
     $('#right-status img').attr('src',imgr);
     $('#right-status p').text(data.RChng);
     setTimeout(function() {
      getState(updateReadout);
     }, 2000);
    }
    
   function getState(callback) {
    $.ajax({
     url : agenturl + '/state',
     headers: {'api-key': apikey},
     type: 'GET',
     success : function(response) {
      if (callback) {
       callback(response);
      }
     },
     error : function(xhr, ajaxOptions, thrownError) {
        if (xhr.status === 401) {
            window.location.reload();
        }
     }
    });
   }
   
   function postPush(door) {
    $.ajax({
     url : agenturl + '/press',
     headers: {'api-key': apikey},
     type: 'POST',
     data: JSON.stringify({ 'door' : door }),
     success : function(response) {
     }
    });
   }
  </script>
 </body>
</html>
";

const AUTHUSER = "<USERID>";
const AUTHPASS = "<PASSWORD>";

// Need better way to convert timezone - no auto DST
const TZ = -4;

dwt <- DweetIO();
api <- Rocky();
 
//--------------------------------------------------------------------------------------------------------
// Setup default values
//--------------------------------------------------------------------------------------------------------

local currentDoorState = {};
local lastUpdate = {};
currentDoorState[DOOR1] <- "Unknown";
currentDoorState[DOOR2] <- "Unknown";
lastUpdate[DOOR1] <- "Unknown";
lastUpdate[DOOR2] <- "Unknown";

local ak = {};
local userauth = "Basic "+http.base64encode(AUTHUSER+":"+AUTHPASS);

// Add static API keys
ak["<FIXED KEY GOES HERE>"] <- date();

//--------------------------------------------------------------------------------------------------------
// Authenticate the API Calls
//--------------------------------------------------------------------------------------------------------

api.authorize(function(context) {
    local key = context.getHeader("api-key"); 
    //server.log("RX Key: "+key);
    if (context.req.path == "/") {
        return true;
    }

    // Check if the api key exists in the key table, if not then the call
    // is not authorized.
    try {
        local d=ak[key];
    } catch(exception) {
        server.log("ERROR: Expired or invalid API KEY "+key);
        return false;
    }
    
    return true;
})

//--------------------------------------------------------------------------------------------------------
// Handle API call to get the home page
//--------------------------------------------------------------------------------------------------------

api.get("/", function(context) {
    local auth=context.getHeader("Authorization");
    if (auth == userauth) {
        local url = http.agenturl();
        utilities.getNewUUID(function(err, uuid) {
            if (err) {
                server.error(err);
            } else {
                //server.log("TX Key: " + uuid);
                ak[uuid] <- date();
                context.send(200, format(INDEX, url, uuid));
            }
        });
    } else {
        context.setHeader("WWW-Authenticate","Basic realm='Authentication Required'");
        context.send(401);
    }
})

//--------------------------------------------------------------------------------------------------------
// Handle API call to get the current status of the doors
//--------------------------------------------------------------------------------------------------------

api.get("/state", function(context) {
    context.send(200, {"Left" : currentDoorState[DOOR1],
                       "LChng" : lastUpdate[DOOR1],
                       "Right" : currentDoorState[DOOR2],
                       "RChng" : lastUpdate[DOOR2]
    });
})

//--------------------------------------------------------------------------------------------------------
// Handle API call to press one of the door buttons
//--------------------------------------------------------------------------------------------------------

api.post("/press", function(context) {
    local data = http.jsondecode(context.req.rawbody);
    device.send("pressButton",{"door":data.door});
    context.send(200);
})

//--------------------------------------------------------------------------------------------------------
// Handle device calls to update the status of a door
//--------------------------------------------------------------------------------------------------------

device.on("doorstatus", function(value) {
    local door = value["door"];
    local d = date(time()+(TZ*3600));
    local datestring = format("%04d-%02d-%02d %02d:%02d", d.year, d.month+1, d.day, d.hour, d.min);
    currentDoorState[door] = value["status"];
    lastUpdate[door] = datestring;
    server.log(door + " Door " + currentDoorState[door]);
    dwt.dweet("GDM"+door, {"status":currentDoorState[door]});
});

//--------------------------------------------------------------------------------------------------------
// END
//--------------------------------------------------------------------------------------------------------
