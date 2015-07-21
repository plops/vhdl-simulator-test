
library ieee;

use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.ezono_package.all;
use work.proj_package.all;

--------------------------------------------------------------------------------
-- Package Description
--------------------------------------------------------------------------------
package main_ctrl_block_package is

  constant C_CMD_CODE_WIDTH : natural := 4;

  constant C_CMD_CODE_LL : natural :=
    C_CMD_REG_WIDTH - C_CMD_CODE_WIDTH;

  constant C_CMD_CODE_UL : natural := C_CMD_REG_WIDTH-1;


  constant C_CMD_DATA_WIDTH : natural :=
    C_CMD_REG_WIDTH - C_CMD_CODE_WIDTH;

  constant C_CMD_DATA_UL : natural := C_CMD_DATA_WIDTH-1;
  constant C_CMD_DATA_LL : natural := 0;


  subtype T_CMD_CODE is std_logic_vector(C_CMD_CODE_WIDTH-1 downto 0);
  subtype T_CMD_DATA is std_logic_vector(C_CMD_DATA_WIDTH-1 downto 0);

  constant C_STATUS_CODE_WIDTH : natural := 4;

  subtype T_STATUS_CODE is std_logic_vector(C_STATUS_CODE_WIDTH-1 downto 0);

  type T_MASTER_SM_STATE_TYPE is (
    MASTER_SM_POWER_OFF,
    MASTER_SM_SECURITY_CHECK,
    MASTER_SM_IDLE,
    MASTER_SM_SCAN,
    MASTER_SM_ERROR,
    MASTER_SM_STANDBY, 
    MASTER_SM_PAUSE
    );

  constant C_MASTER_STATUS_POWER_OFF      : T_STATUS_CODE := x"0";
  constant C_MASTER_STATUS_SECURITY_CHECK : T_STATUS_CODE := x"1";
  constant C_MASTER_STATUS_IDLE           : T_STATUS_CODE := x"2";
  constant C_MASTER_STATUS_SCAN           : T_STATUS_CODE := x"3";
  constant C_MASTER_STATUS_ERROR          : T_STATUS_CODE := x"4";
  constant C_MASTER_STATUS_STANDBY        : T_STATUS_CODE := x"5"; 
 constant C_MASTER_STATUS_PAUSE : T_STATUS_CODE := x"6";

  constant C_ERROR_CODE_WIDTH : natural := 8;

  subtype T_ERROR_CODE is std_logic_vector(C_ERROR_CODE_WIDTH-1 downto 0);

  constant C_MASTER_NO_ERROR                  : T_ERROR_CODE := x"00";
  constant C_MASTER_SECURITY_ERROR            : T_ERROR_CODE := x"01";
  constant C_MASTER_THERMAL_ERROR             : T_ERROR_CODE := x"02";
  constant C_MASTER_POWER_GOOD_NEVER_OCCURED  : T_ERROR_CODE := x"03";
  constant C_MASTER_CDC_LOCK_NEVER_OCCURED    : T_ERROR_CODE := x"04";
  constant C_MASTER_CDC_CONFIG_ERROR          : T_ERROR_CODE := x"05";
  constant C_MASTER_ADS_ERROR                 : T_ERROR_CODE := x"06";
  constant C_MASTER_VCA_ERROR                 : T_ERROR_CODE := x"07";
  constant C_MASTER_HVM_ERROR                 : T_ERROR_CODE := x"08";
  constant C_MASTER_RX_AFEM_ERROR             : T_ERROR_CODE := x"09";
  constant C_MASTER_TA_FIRST_STAGE_FULL       : T_ERROR_CODE := x"0A";
  constant C_MASTER_TA_SECOND_STAGE_FULL      : T_ERROR_CODE := x"0B";
  constant C_MASTER_TA_THIRD_STAGE_FULL       : T_ERROR_CODE := x"0C";
  constant C_MASTER_TA_FOURTH_STAGE_FULL      : T_ERROR_CODE := x"0D";
  constant C_MASTER_TA_FIFTH_STAGE_FULL       : T_ERROR_CODE := x"0E";
  constant C_MASTER_TA_LAST_STAGE_FULL        : T_ERROR_CODE := x"0F";
  constant C_MASTER_TA_FIFOS_NOT_EMPTY        : T_ERROR_CODE := x"10";
  constant C_MASTER_TA_OVERFLOW               : T_ERROR_CODE := x"11";
  constant C_MASTER_PRI_PLL_LOCK_ERROR        : T_ERROR_CODE := x"12";
  constant C_MASTER_SYSTEM_RAM_OFFSET_ERROR   : T_ERROR_CODE := x"13";
  constant C_MASTER_LINE_ID_TABLE_EMPTY       : T_ERROR_CODE := x"14";
  constant C_MASTER_OVERFLOW_WATCHDOG_ERROR   : T_ERROR_CODE := x"15";
  constant C_MASTER_PULSERS_OTP_ERROR         : T_ERROR_CODE := x"16";
  constant C_MASTER_POWER_GOOD_GONE_DOWN      : T_ERROR_CODE := x"17";
  constant C_MASTER_CDC_LOCK_GONE_DOWN        : T_ERROR_CODE := x"18";
  constant C_MASTER_CONFIG_UPDATE_FAILURE     : T_ERROR_CODE := x"19";
  constant C_MASTER_PCIE_LINK_IS_BUSY         : T_ERROR_CODE := x"1A";
  constant C_MASTER_IMG_PROC_MODULE_IS_BUSY   : T_ERROR_CODE := x"1B";
  constant C_MASTER_FRAMER_OVERLAP_ERROR      : T_ERROR_CODE := x"1C";
  constant C_MASTER_NDL_PCIE_LINK_IS_BUSY     : T_ERROR_CODE := x"1D";
  constant C_MASTER_C_MODE_PCIE_LINK_IS_BUSY  : T_ERROR_CODE := x"1E";
  constant C_MASTER_M_MODE_PCIE_LINK_IS_BUSY  : T_ERROR_CODE := x"1F"; 
  constant C_MASTER_CMPD_NOT_ENOUGH_SMPLS_ERR : T_ERROR_CODE := x"20"; 
                                                                            constant C_MASTER_PCIE_RAM_B_MODE_OVERFLOW_ERR : T_ERROR_CODE := x"21"; 
                                                                            constant C_MASTER_PCIE_RAM_C_MODE_OVERFLOW_ERR : T_ERROR_CODE := x"22"; 
                                                                                                                                                      constant C_MASTER_PCIE_RAM_M_MODE_OVERFLOW_ERR : T_ERROR_CODE := x"23";
  constant C_MASTER_UNKNOWN_ERROR : T_ERROR_CODE := x"FF";


  type T_CMD_CTRL_SM_STATE_TYPE is (
    CMD_CTRL_SM_IDLE,
    CMD_CTRL_SM_CMD_REQUEST,
    CMD_CTRL_SM_NEW_CMD,
    CMD_CTRL_SM_CONSUME
    );

  constant C_CMD_RESET         : T_CMD_CODE := x"0";
  constant C_CMD_FLIP          : T_CMD_CODE := x"1";
  constant C_CMD_SCAN          : T_CMD_CODE := x"2";
  constant C_CMD_STOP_SCAN     : T_CMD_CODE := x"3";
  constant C_CMD_WATCHDOG_WAKE : T_CMD_CODE := x"4"; 
 constant C_CMD_PAUSE_SCAN : T_CMD_CODE := x"5";

  type T_LINE_ID_SM_STATE_TYPE is (
    LINE_ID_SM_IDLE,
    LINE_ID_SM_FETCH_LINE_ID,
    LINE_ID_SM_LINE_ID_READY,
    LINE_ID_SM_MUX_PROGRAMMING,
    LINE_ID_SM_READY,
    LINE_ID_SM_WAIT_ON_FILLER,
    LINE_ID_SM_FILLER_READY
    );

  constant C_LINE_ID_STATUS_IDLE            : T_STATUS_CODE := x"0";
  constant C_LINE_ID_STATUS_FETCH_LINE_ID   : T_STATUS_CODE := x"1";
  constant C_LINE_ID_STATUS_LINE_ID_READY   : T_STATUS_CODE := x"2";
  constant C_LINE_ID_STATUS_MUX_PROGRAMMING : T_STATUS_CODE := x"3";
  constant C_LINE_ID_STATUS_READY           : T_STATUS_CODE := x"4";
  constant C_LINE_ID_STATUS_WAIT_ON_FILLER  : T_STATUS_CODE := x"5";
  constant C_LINE_ID_STATUS_FILLER_READY    : T_STATUS_CODE := x"6";


  type T_SCAN_SM_STATE_TYPE is (
    SCAN_SM_IDLE,
    SCAN_SM_WAIT_BEFORE_TRANSMISSION,
    SCAN_SM_TRANSMISSION,
    SCAN_SM_WAIT_BEFORE_RECEPTION,
    SCAN_SM_RECEPTION,
    SCAN_SM_READY,
    SCAN_SM_WAIT_ON_FILLER
    );

  constant C_SCAN_STATUS_IDLE                     : T_STATUS_CODE := x"0";
  constant C_SCAN_STATUS_WAIT_BEFORE_TRANSMISSION : T_STATUS_CODE := x"1";
  constant C_SCAN_STATUS_TRANSMISSION             : T_STATUS_CODE := x"2";
  constant C_SCAN_STATUS_WAIT_BEFORE_RECEPTION    : T_STATUS_CODE := x"3";
  constant C_SCAN_STATUS_RECEPTION                : T_STATUS_CODE := x"4";
  constant C_SCAN_STATUS_READY                    : T_STATUS_CODE := x"5";
  constant C_SCAN_STATUS_WAIT_ON_FILLER           : T_STATUS_CODE := x"6";


  type T_FLIP_SM_STATE_TYPE is (
    FLIP_SM_IDLE,
    FLIP_SM_WAIT_BEFORE_FLIP,
    FLIP_SM_FLIP,
    FLIP_SM_WAIT_AFTER_FLIP,
    FLIP_SM_WAIT
    );

  constant C_FLIP_STATUS_IDLE             : T_STATUS_CODE := x"0";
  constant C_FLIP_STATUS_WAIT_BEFORE_FLIP : T_STATUS_CODE := x"1";
  constant C_FLIP_STATUS_FLIP             : T_STATUS_CODE := x"2";
  constant C_FLIP_STATUS_WAIT_AFTER_FLIP  : T_STATUS_CODE := x"3";
  constant C_FLIP_STATUS_WAIT             : T_STATUS_CODE := x"4";


  type T_CONFIG_SM_STATE_TYPE is (
    CONFIG_SM_IDLE,
    CONFIG_SM_CONFIGURE
    );

  constant C_CONFIG_STATUS_IDLE      : T_STATUS_CODE := x"0";
  constant C_CONFIG_STATUS_CONFIGURE : T_STATUS_CODE := x"1";


  constant C_ANALOG_CONF_ALL_ZEROS : std_logic_vector(
    C_NB_ANALOG_CONFS-1 downto 0) := (others => '0');

  constant C_ANALOG_CONF_DONE_ALL_ONES : std_logic_vector(
    C_NB_ANALOG_CONFS-1 downto 0) := (others => '1');


  constant C_FILLER_DELAY_PADDING_ZEROS : natural := 4;

  constant C_FILLER_DELAY_WIDTH    : natural := C_LINE_ID_WIDTH-1;
  constant C_FILLER_DELAY_WIDTH_UL : natural := C_FILLER_DELAY_WIDTH-1;
  constant C_FILLER_DELAY_WIDTH_LL : natural := 0;


  constant C_WAIT_BEFORE_RX_CNT_WIDTH : natural := 16;

  constant C_CNT_LOAD_VALUE_WAIT_BEFORE_RX_UL :
    natural := C_WAIT_BEFORE_RX_CNT_WIDTH-1;

  constant C_CNT_LOAD_VALUE_WAIT_BEFORE_RX_LL :
    natural := 0;


  constant C_WAIT_BEFORE_TX_CNT_WIDTH :
    natural := C_WAIT_CNT_WIDTH - C_WAIT_BEFORE_RX_CNT_WIDTH;

  constant C_CNT_LOAD_VALUE_WAIT_BEFORE_TX_UL :
    natural := C_WAIT_BEFORE_RX_CNT_WIDTH + C_WAIT_BEFORE_TX_CNT_WIDTH-1;

  constant C_CNT_LOAD_VALUE_WAIT_BEFORE_TX_LL :
    natural := C_WAIT_BEFORE_RX_CNT_WIDTH;

  constant C_WATCHDOG_CNT_LOAD_VALUE_WIDTH : natural := 32;
  constant C_WATCHDOG_CNT_LOAD_VALUE       : natural := 250000000;  -- 5 seconds with 50MHz.

end package main_ctrl_block_package;
-------------------------------------------------------------------------------
