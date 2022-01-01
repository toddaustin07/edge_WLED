local requestpath = [[
{
    "id": "valleyboard16460.httprequestpath",
    "version": 1,
    "status": "proposed",
    "name": "httprequestpath",
    "ephemeral": false,
    "attributes": {
        "path": {
            "schema": {
                "type": "object",
                "properties": {
                    "value": {
                        "type": "string"
                    }
                },
                "additionalProperties": false,
                "required": [
                    "value"
                ]
            },
            "setter": "setPath",
            "enumCommands": []
        }
    },
    "commands": {
        "setPath": {
            "name": "setPath",
            "arguments": [
                {
                    "name": "value",
                    "optional": false,
                    "schema": {
                        "type": "string"
                    }
                }
            ]
        }
    }
}
]]

local effectmode = [[
{
    "id": "partyvoice23922.wledeffectmode2",
    "version": 1,
    "status": "proposed",
    "name": "wledeffectmode2",
    "ephemeral": false,
    "attributes": {
        "effectMode": {
            "schema": {
                "type": "object",
                "properties": {
                    "value": {
                        "type": "integer",
                        "minimum": 0,
                        "maximum": 200
                    }
                },
                "additionalProperties": false,
                "required": [
                    "value"
                ]
            },
            "setter": "setEffectMode",
            "enumCommands": []
        }
    },
    "commands": {
        "setEffectMode": {
            "name": "setEffectMode",
            "arguments": [
                {
                    "name": "effectMode",
                    "optional": false,
                    "schema": {
                        "type": "integer",
                        "minimum": 0,
                        "maximum": 200
                    }
                }
            ]
        }
    }
}
]]

local createdev_cap = [[
{
    "id": "partyvoice23922.createanother",
    "version": 1,
    "status": "proposed",
    "name": "createanother",
    "attributes": {},
    "commands": {
        "push": {
            "name": "push",
            "arguments": []
        }
    }
}
]]

return {
	requestpath = requestpath,
	effectmode = effectmode,
    createdev_cap = createdev_cap,
}
