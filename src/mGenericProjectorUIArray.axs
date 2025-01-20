MODULE_NAME='mGenericProjectorUIArray'      (
                                                dev dvTP[],
                                                dev vdvObject
                                            )

(***********************************************************)
#include 'NAVFoundation.ModuleBase.axi'
#include 'NAVFoundation.Math.axi'
#include 'NAVFoundation.UIUtils.axi'

/*
 _   _                       _          ___     __
| \ | | ___  _ __ __ _  __ _| |_ ___   / \ \   / /
|  \| |/ _ \| '__/ _` |/ _` | __/ _ \ / _ \ \ / /
| |\  | (_) | | | (_| | (_| | ||  __// ___ \ V /
|_| \_|\___/|_|  \__, |\__,_|\__\___/_/   \_\_/
                 |___/

MIT License

Copyright (c) 2023 Norgate AV Services Limited

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

(***********************************************************)
(*          DEVICE NUMBER DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_DEVICE

(***********************************************************)
(*               CONSTANT DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_CONSTANT

constant integer LEVEL_VOLUME = 1

constant integer ADDRESS_LEVEL_PERCENTAGE    = 1
constant integer ADDRESS_LAMP_HOURS_1    = 2
constant integer ADDRESS_LAMP_HOURS_2    = 3
constant integer ADDRESS_LAMP_HOURS[]    = { 2, 3 }

constant integer LOCK_TOGGLE    = 301
constant integer LOCK_ON    = 302
constant integer LOCK_OFF    = 303
constant integer LEVEL_TOUCH    = 304

(***********************************************************)
(*              DATA TYPE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_TYPE

(***********************************************************)
(*               VARIABLE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_VARIABLE

volatile integer iLocked

volatile integer iLevelTouched
volatile sinteger siRequestedLevel = -1

volatile sinteger iLevel
volatile sinteger iOldLevel

volatile char cLampHours[2][NAV_MAX_CHARS]

(***********************************************************)
(*               LATCHING DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_LATCHING

(***********************************************************)
(*       MUTUALLY EXCLUSIVE DEFINITIONS GO BELOW           *)
(***********************************************************)
DEFINE_MUTUALLY_EXCLUSIVE

(***********************************************************)
(*        SUBROUTINE/FUNCTION DEFINITIONS GO BELOW         *)
(***********************************************************)
(* EXAMPLE: DEFINE_FUNCTION <RETURN_TYPE> <NAME> (<PARAMETERS>) *)
(* EXAMPLE: DEFINE_CALL '<NAME>' (<PARAMETERS>) *)

define_function Update() {
    iOldLevel = iLevel

    if (siRequestedLevel >= 0) {
        if (siRequestedLevel == iLevel) {
            siRequestedLevel = -1
        }
    }
    else {
        if (!iLevelTouched) {
            stack_var integer x

            for (x = 1; x <= length_array(dvTP); x++) {
            send_level dvTP[x], LEVEL_VOLUME, iLevel
            }

            NAVTextArray(dvTP, ADDRESS_LEVEL_PERCENTAGE, '0', "itoa(NAVScaleValue(type_cast(iLevel),255,100,0)),'%'")
        }
    }

    {
        stack_var integer x

        for (x = 1; x <= 2; x++) {
            NAVTextArray(dvTP, ADDRESS_LAMP_HOURS[x], '0', cLampHours[x])
        }
    }
}

(***********************************************************)
(*                STARTUP CODE GOES BELOW                  *)
(***********************************************************)
DEFINE_START {

}

(***********************************************************)
(*                THE EVENTS GO BELOW                      *)
(***********************************************************)
DEFINE_EVENT

level_event[vdvObject, LEVEL_VOLUME] {
    iLevel = level.value
    Update()
}


button_event[dvTP, 0] {
    push: {
        switch (button.input.channel) {
            case VOL_UP:
            case VOL_DN: {
                if (!iLocked) {
                    to[vdvObject, button.input.channel]
                }
            }
            case VOL_MUTE: {
                to[vdvObject, button.input.channel]
            }
            case LOCK_TOGGLE: {
                iLocked = !iLocked
            }
            case LOCK_ON: {
                iLocked = true
            }
            case LOCK_OFF: {
                iLocked = false
            }
            case LEVEL_TOUCH: {
                iLevelTouched = true
            }
        }
    }
    release: {
        switch (button.input.channel) {
            case LEVEL_TOUCH: {
                iLevelTouched = false
            }
        }
    }
}


level_event[dvTP, LEVEL_VOLUME] {
    if (iLevelTouched && !iLocked) {
        siRequestedLevel = level.value
        send_command vdvObject, "'VOLUME-', itoa(siRequestedLevel)"
        NAVTextArray(dvTP, ADDRESS_LEVEL_PERCENTAGE, '0', "itoa(NAVScaleValue(type_cast(siRequestedLevel),255,100,0)),'%'")
    }
}


data_event[dvTP] {
    online: {
        Update()
    }
}


data_event[vdvObject] {
    string: {
        stack_var char cCmdHeader[NAV_MAX_CHARS]
        stack_var char cCmdParam[2][NAV_MAX_CHARS]

        NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                    NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_STRING_FROM,
                                                data.device,
                                                data.text))

        cCmdHeader = DuetParseCmdHeader(data.text)
        cCmdParam[1] = DuetParseCmdParam(data.text)
        cCmdParam[2] = DuetParseCmdParam(data.text)

        switch (cCmdHeader) {
            case 'LAMPTIME': {
                switch (cCmdParam[1]) {
                    case '1': {
                        cLampHours[1] = cCmdParam[2]
                    }
                    case '2': {
                        cLampHours[2] = cCmdParam[2]
                    }
                }

                Update()
            }
        }
    }
}


(***********************************************************)
(*                     END OF PROGRAM                      *)
(*        DO NOT PUT ANY CODE BELOW THIS COMMENT           *)
(***********************************************************)
