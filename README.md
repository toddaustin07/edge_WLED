# WLED Driver
A SmartThings Edge driver to provide a device interface to WLED servers

This is a port of the SmartThings Groovy-based DTH by Wesley Menezes (@w35l3y in the SmartThings Community)

I encourage others to take this driver code and extend it.

### Pre-Requisites

- SmartThings Hub
- WLED server (https://kno.wled.ge/)

## Current Limitations

If a command is sent to the WLED server by any means other than the SmartThings device, then the SmartThings device will be out of synch with the actual state of the light strip.  A mechanism is needed to receive notifications from the WLED server for when states have changed.  If the WLED server supports some kind of auto-notification of updates (unclear based on available documentation), then this could be implemented.  Otherwise, some kind of frequent polling would have to be used.

## Installation
Install via my shared channel invite:  https://api.smartthings.com/invitation-web/accept?id=cc2197b9-2dce-4d88-b6a1-2d198a0dfdef

Once installed to your hub, from the SmartThings mobile app, do an **Add Device / Scan nearby** and a new device labeled '**WLED Device**' will be added and found in the 'No room assigned' room.

## Configuration
From the new device's details screen, tap the 3 vertical dot menu in the upper right corner and tap **Settings**.  

#### Host
Provide the IP:port address of the WLED server;  this must include the complete IP and port number address

#### Path
Generally this setting should not be changed.  For the knowledgeable, this string contains a sequence of parameters (separated by '&') that will be sent to the WLED server in every updated request.  The values '\_\_xxxxx\_\_' represent placeholders for the specific SmartThings capability attributes that will be substituted.

## Useage Notes
- A change of any of these values on the device details screen: dimmer, color, effect mode, path -  will always turn the main switch ON and cause a command sequence to be sent to the WLED server. 
- Setting the dimmer level to 0, will turn the main switch OFF
- Effect Mode:  due to a bug in the SmartThings platform, these are listed in random order
- Path: used to send additional custom parameters and values (in addition to those configured in Settings)  
See this page for parameter options: https://kno.wled.ge/interfaces/http-api/
- All fields can be set via automation routines
- Additional SmartThings WLED devices can be created with the 'Create new device' button; they will be found in the 'No room assigned' room.

