.. highlight:: cpp

Macro
=====
The on-board flash memory can also be used to store MetaWear commands instead of sensor data. 

A good example of this feature is to change the name of a device permanently so that is does not advertise as MetaWear. 

Recorded commands can be executed any time after being 
programmed with the functions in `macro.h <https://mbientlab.com/docs/metawear/cpp/0/macro_8h.html>`_ header file.  

Recording Commands
------------------
To record commands:

1. Call `mbl_mw_macro_record <https://mbientlab.com/docs/metawear/cpp/0/macro_8h.html#aa99e58c7cbc1bbecb10985bd08643bba>`_ to put the API in macro mode  
2. Use the MetaWear commands that you want programmed  
3. Exit macro mode with `mbl_mw_macro_end_record <https://mbientlab.com/docs/metawear/cpp/0/macro_8h.html#aa79694ef4d711d84da302983162517eb>`_  

::

        mbl_mw_macro_record(board, 1);
        // COMMANDS TO RECORD GO HERE
        mbl_mw_macro_end_record(board, callback);

Macros can be set to run on boot by setting the ``exec_on_boot`` parameter with a non-zero value.

::

    mbl_mw_macro_record(board, 1); // ON BOOT
    mbl_mw_macro_record(board, 0); // NOT ON BOOT

In this example, the LED will blink blue on boot:

::

    #include "metawear/core/macro.h"
    #include "metawear/peripheral/led.h"

    void setup_macro(MblMwMetaWearBoard* board) {
        static auto callback = [](MblMwMetaWearBoard* board, int32_t id) {
            cout << "Macro ID = " << id << endl;
        };
        MblMwLedPattern pattern = { 16, 16, 0, 500, 0, 1000, 0, 5 };

        mbl_mw_macro_record(board, 1);
        mbl_mw_led_write_pattern(board, &pattern, MBL_MW_LED_COLOR_BLUE);
        mbl_mw_led_play(board);
        mbl_mw_macro_end_record(board, callback);
    }

In this example, we will change the device name permanently:

::

    #include "metawear/core/macro.h"
    #include "metawear/peripheral/led.h"

    void setup_macro(MblMwMetaWearBoard* board) {
        static auto callback = [](MblMwMetaWearBoard* board, int32_t id) {
            cout << "Macro ID = " << id << endl;
            macro_id = id;
        };

        // Change on boot
        mbl_mw_macro_record(board, 1);
        auto new_name = "METAMOO";
        mbl_mw_settings_set_device_name(board, new_name, 7);
        mbl_mw_macro_end_record(board, callback);

        // Change the name now
        mbl_mw_macro_execute(macro_id);
    }

Erasing Macros
--------------
Erasing macros is done with the `mbl_mw_macro_erase_all <https://mbientlab.com/docs/metawear/cpp/0/macro_8h.html#aa1c03d8f08b5058d8f81b532a6930d67>`_ 
method.  The erase operation will not occur until you disconnect from the board.

::

    mbl_mw_macro_erase_all(board);

