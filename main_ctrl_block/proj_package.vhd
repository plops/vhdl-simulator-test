library ieee;

use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.ezono_package.all;

--------------------------------------------------------------------------------
-- Package Description
--------------------------------------------------------------------------------
package proj_package is

  ------------------------------------------------------------------------------
  -- Global
  ------------------------------------------------------------------------------

  constant C_ZEROS_64BIT : std_logic_vector(63 downto 0) := (others => '0');
  constant C_ONES_64BIT  : std_logic_vector(63 downto 0) := (others => '1');

  -- Residual Power Suppression Logic
  constant C_RPS_LOGIC : std_logic := '0';

  constant C_ADC_DATA_WIDTH : natural := 12;  --14;

  -- Channel Data Width
  constant C_CHANNEL_WIDTH :
    natural range 1 to 32 := C_ADC_DATA_WIDTH;

  constant C_16BIT_BUS_WIDTH : natural := 16;

  constant C_32BIT_BUS_WIDTH : natural := 32;

  -- Eg: If ADC output is 12 bit. We have 4096 possible values.
  --     dc level is at 2048
  constant C_DC_LEVEL_FOR_UNSIGNED_INPUT :
    std_logic_vector(C_CHANNEL_WIDTH-1 downto 0) :=
    '1' & C_ZEROS_64BIT(C_CHANNEL_WIDTH-2 downto 0);

  -- Number of Channels

  constant C_NB_PROBE_ELEMENTS : natural range 1 to 1024 := 128;

  constant C_NB_CHANNELS_IN_BINARY :
    natural range 1 to 8 := 5;

  constant C_NB_CHANNELS :
    natural range 2 to 256 := 2**C_NB_CHANNELS_IN_BINARY;


  -- Channels Data
  type T_CHANNELS_DATA is
    array(0 to C_NB_CHANNELS-1) of
    std_logic_vector(C_CHANNEL_WIDTH-1 downto 0);
          
  type T_CHANNELS_DATA_16BIT is
    array(0 to C_NB_CHANNELS-1) of
    std_logic_vector(C_16BIT_BUS_WIDTH-1 downto 0);

  type T_HALF_CHANNELS_DATA_16BIT is
    array(0 to C_NB_CHANNELS/2-1) of
    std_logic_vector(C_16BIT_BUS_WIDTH-1 downto 0);

  type T_HALF_CHANNELS_DATA_32BIT is
    array(0 to C_NB_CHANNELS/2-1) of
    std_logic_vector(C_32BIT_BUS_WIDTH-1 downto 0);

  constant C_NB_HVMs : natural range 1 to C_NB_CHANNELS := 8;

  constant C_CHANNELS_DATA_ZEROS : T_CHANNELS_DATA := (others => (others => '0'));


  ------------------------------------------------------------------------------
  -- Main Contrl Block
  ------------------------------------------------------------------------------

  constant C_CMD_REG_WIDTH    : natural := 16;
  constant C_STATUS_REG_WIDTH : natural := 28;
  constant C_WAIT_CNT_WIDTH   : natural := 32;

  subtype T_CMD_REG is std_logic_vector(C_CMD_REG_WIDTH-1 downto 0);
  subtype T_STATUS_REG is std_logic_vector(C_STATUS_REG_WIDTH-1 downto 0);

  ------------------------------------------------------------------------------
  -- Config ID
  -- Bugzilla 4001, 4002
  ------------------------------------------------------------------------------
  constant C_CONFIG_ID_WIDTH         : natural := 12;
  constant C_CONFIG_ID_FRAME_TYPE    : natural := 4;
  constant C_CONFIG_ID_FRAME_TYPE_UL : natural := C_CONFIG_ID_WIDTH - 1;
  constant C_CONFIG_ID_FRAME_TYPE_LL : natural := C_CONFIG_ID_FRAME_TYPE_UL -
                                                  C_CONFIG_ID_FRAME_TYPE + 1;

  ------------------------------------------------------------------------------
  -- Line ID
  ------------------------------------------------------------------------------
  constant C_LINE_ID_WIDTH : natural := 13;

  -- Default Line ID is 2 (1st Even Line)
  constant C_DEFAULT_LINE_ID : std_logic_vector(C_LINE_ID_WIDTH-1 downto 0) := conv_std_logic_vector(2, C_LINE_ID_WIDTH);

  constant C_LINE_ID_FILLER          : std_logic := '1';
  constant C_LINE_ID_FILLER_WIDTH    : natural   := 1;
  constant C_LINE_ID_FILLER_POSITION : natural   := C_LINE_ID_WIDTH-1;

  constant C_LINE_ID_FEATURE_WIDTH : natural := 2;
  constant C_LINE_ID_FEATURE_UL    : natural := C_LINE_ID_WIDTH-1 - C_LINE_ID_FILLER_WIDTH;
  constant C_LINE_ID_FEATURE_LL    : natural := C_LINE_ID_FEATURE_UL - C_LINE_ID_FEATURE_WIDTH + 1;

  constant C_B_MODE : std_logic_vector(C_LINE_ID_FEATURE_WIDTH-1 downto 0) := "00";
  constant C_F_MODE : std_logic_vector(C_LINE_ID_FEATURE_WIDTH-1 downto 0) := "01";
  constant C_M_MODE : std_logic_vector(C_LINE_ID_FEATURE_WIDTH-1 downto 0) := "10";

  constant C_LINE_ID_FOCAL_ZONE_WIDTH : natural := 2;
  constant C_LINE_ID_FOCAL_ZONE_UL    : natural := C_LINE_ID_WIDTH-1 - C_LINE_ID_FILLER_WIDTH - C_LINE_ID_FEATURE_WIDTH;
  constant C_LINE_ID_FOCAL_ZONE_LL    : natural := C_LINE_ID_FOCAL_ZONE_UL - C_LINE_ID_FOCAL_ZONE_WIDTH + 1;

  constant C_FIRST_FOCAL_ZONE  : std_logic_vector(C_LINE_ID_FOCAL_ZONE_WIDTH-1 downto 0) := "00";
  constant C_SECOND_FOCAL_ZONE : std_logic_vector(C_LINE_ID_FOCAL_ZONE_WIDTH-1 downto 0) := "01";
  constant C_THIRD_FOCAL_ZONE  : std_logic_vector(C_LINE_ID_FOCAL_ZONE_WIDTH-1 downto 0) := "10";
  constant C_FOURTH_FOCAL_ZONE : std_logic_vector(C_LINE_ID_FOCAL_ZONE_WIDTH-1 downto 0) := "11";

  constant C_ANGLE_FEATURE_WIDTH  : natural := 2;
  constant C_ANGLE_DIRECTION_FLAG : natural := 1;
  constant C_ANGLE_WIDTH          : natural := C_ANGLE_FEATURE_WIDTH + C_ANGLE_DIRECTION_FLAG;

  constant C_FIRST_ANGLE  : std_logic_vector(C_ANGLE_FEATURE_WIDTH-1 downto 0) := "00";
  constant C_SECOND_ANGLE : std_logic_vector(C_ANGLE_FEATURE_WIDTH-1 downto 0) := "01";
  constant C_THIRD_ANGLE  : std_logic_vector(C_ANGLE_FEATURE_WIDTH-1 downto 0) := "10";
  constant C_FOURTH_ANGLE : std_logic_vector(C_ANGLE_FEATURE_WIDTH-1 downto 0) := "11";

  constant C_LINE_ID_LINE_NB_WIDTH : natural := 8;
  constant C_LINE_ID_LINE_NB_UL    : natural := C_LINE_ID_LINE_NB_WIDTH-1;
  constant C_LINE_ID_LINE_NB_LL    : natural := 0;

  -- extended lines
  constant C_FIRST_REGULAR_LINE_NB : natural := 32;
  constant C_LAST_REGULAR_LINE_NB  : natural := 225;
  constant C_FIRST_REGULAR_LINE_ID : std_logic_vector(C_LINE_ID_LINE_NB_WIDTH-1 downto 0)
 := conv_std_logic_vector(C_FIRST_REGULAR_LINE_NB, C_LINE_ID_LINE_NB_WIDTH);
  constant C_LAST_REGULAR_LINE_ID : std_logic_vector(C_LINE_ID_LINE_NB_WIDTH-1 downto 0)
 := conv_std_logic_vector(C_LAST_REGULAR_LINE_NB, C_LINE_ID_LINE_NB_WIDTH);

  ------------------------------------------------------------------------------

  --DBF Memory Control related constants--
  constant C_CONF_MEM_DEPTH_BIN :
    natural range 2 to 18 := 17;

  ------------------------------------------------------------------------------
  -- Memory Widths
  ------------------------------------------------------------------------------
  constant C_CONF_MEM_WIDTH : natural range 1 to 128 := 32;

  constant C_LINE_ID_MEM_WIDTH          : natural range 1 to C_CONF_MEM_WIDTH := C_LINE_ID_WIDTH;
  constant C_FOCUS_DELAY_MEM_WIDTH      : natural range 1 to C_CONF_MEM_WIDTH := 32;
  constant C_FOCUS_NB_SAMPLES_MEM_WIDTH : natural range 1 to C_CONF_MEM_WIDTH := 16;
  constant C_TX_PULSE_TRAIN_MEM_WIDTH   : natural range 1 to C_CONF_MEM_WIDTH := 10;
  constant C_DAC_MEM_WIDTH              : natural range 1 to C_CONF_MEM_WIDTH := 20;
  constant C_PMNDT_MEM_WIDTH            : natural range 1 to C_CONF_MEM_WIDTH := 32;  
  constant C_CDC_MEM_WIDTH              : natural range 1 to C_CONF_MEM_WIDTH := 32;
  constant C_DIGITAL_GAIN_MEM_WIDTH     : natural range 1 to C_CONF_MEM_WIDTH := 12;

  -- bbp digital gain ---------------------------
  constant C_DIGITAL_GAIN_WIDTH : natural := 12;

  --HPF FIRs parameters-----------------------
  constant C_HPF_MEM_WIDTH : natural range 1 to C_CONF_MEM_WIDTH := 16;

  constant C_HPF_TAPS_NB : natural := 28;

  type T_HPF_DATA is array(0 to 31) of std_logic_vector(C_HPF_MEM_WIDTH-1 downto 0);

  --LPF FIRs parameters-----------------------
  constant C_LPF_MEM_WIDTH  : natural range 1 to C_CONF_MEM_WIDTH := 16;
  constant C_LPF_ADDR_WIDTH : natural range 1 to C_CONF_MEM_WIDTH := 5;

  constant C_LPF_TAPS_NB : natural := 26;  -- (2*13)+1 (mirrow + central taps)

  --type T_LPF_DATA is array(0 to 31) of std_logic_vector(C_LPF_MEM_WIDTH-1 downto 0);
  constant C_LPF_TAPS : natural := 10;
  type     T_LPF_COEF is array(0 to C_LPF_TAPS-1) of std_logic_vector(C_LPF_MEM_WIDTH-1 downto 0);

  --Command_register File parameters-----------------------
  constant C_CONF_REGS_FILE_WIDTH : natural := C_CONF_MEM_WIDTH;

  constant C_CONF_REGS_NB : natural := 32;

  type T_CONF_REGS_DATA is array(0 to C_CONF_REGS_NB-1) of std_logic_vector(C_CONF_REGS_FILE_WIDTH-1 downto 0);


  -- Parameter for number of samples to mask,
  -- to avoid transitions in bbp filters.
  constant C_MASK_CNT_WIDTH : natural := 8;

  -- Defintions for the interface between PCIe and Mem Control
  constant C_PCIE_TO_MEM_CONTROL_DATA_BUS_WIDTH : natural := C_CONF_MEM_WIDTH;

  ------------------------------------------

  constant C_ADS_DATA_WIDTH    : natural := 16;
  constant C_ADS_ADDRESS_WIDTH : natural := 8;

  constant C_NB_VCAs_IN_BINARY : natural := 2;
  constant C_NB_VCAs           : natural := 4;

  constant C_VCA_SPI_DATA_WIDTH : natural := 40;
  constant C_VCA_DATA_WIDTH     : natural := 8;

  constant C_DAC_DATA_WIDTH : natural := 12;
  constant C_DAC_STEP_WIDTH : natural := C_DAC_MEM_WIDTH - C_DAC_DATA_WIDTH;

  constant C_DAC_DEFAULT_DATA      : std_logic_vector := x"000";
  constant C_DAC_MIN_STEP_DURATION : natural          := 2;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  -- Tx Pulses
  ------------------------------------------------------------------------------
  -- Assuming Symmetry, we use only half of Channels
  constant C_NB_PULSERS_IN_BINARY : natural := C_NB_CHANNELS_IN_BINARY;
  constant C_NB_PULSERS           : natural := 2**C_NB_PULSERS_IN_BINARY;

  constant C_TX_PULSE_LEVEL_WIDTH : natural := 2;

  constant C_TX_DELAYS_MEM_WIDTH : natural := 10;

  constant C_TX_DELAYS_NB : natural := 32;

  type T_TX_PULSE_DELAYS is array(0 to C_TX_DELAYS_NB-1) of std_logic_vector(C_TX_DELAYS_MEM_WIDTH-1 downto 0);


  type T_TX_PULSE_DATA is array(0 to C_NB_PULSERS-1) of std_logic_vector(C_TX_PULSE_LEVEL_WIDTH-1 downto 0);

  type T_PULSERS_DATA is array(0 to C_NB_PULSERS-1) of std_logic_vector(C_TX_PULSE_TRAIN_MEM_WIDTH-1 downto 0);

  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  constant C_NB_MUX_CHIPS            : natural := 8;
  constant C_NB_MUXES_PER_CHIP       : natural := 4;
  constant C_NB_INDIVIDUAL_MUX_WIDTH : natural := 4;

  constant C_DAC_LENGTH      : natural := 12;
  constant C_NB_ANALOG_CONFS : natural := 3;

  constant C_ADS : natural range 0 to C_NB_ANALOG_CONFS-1 := 0;
  constant C_DAC : natural range 0 to C_NB_ANALOG_CONFS-1 := 1;
  constant C_VCA : natural range 0 to C_NB_ANALOG_CONFS-1 := 2;

  constant C_CONF_REG_FLD_TWOS_COMPLEMENT_BIT_POSITION : natural := 8;


  ------------------------------------------------------------------------------
  -- Framer
  ------------------------------------------------------------------------------
  constant C_FRAMER_INPUT_DATA_WIDTH  : natural range 1 to 64  := C_BBP_DATA_OUT_WIDTH;
  constant C_NB_DBFS_IN_BINARY        : natural range 1 to 16  := 4;
  constant C_RAM_ADDR_WIDTH           : natural range 1 to 64  := 8; -- for B- and M-mode
  constant C_RAM_ADDR_C_MODE_WIDTH    : natural range 1 to 64  := 6;
  constant C_RAM_NDL_ADDR_WIDTH       : natural range 1 to 64  := 6;
  constant C_RAM_DATA_WIDTH           : natural range 1 to 128 := 64;
  constant C_PCIE_TARGET_ADDR_WIDTH   : natural range 1 to 64  := 32;
  constant C_PCIE_LOCAL_ADDR_WIDTH    : natural range 1 to 64  := 16;
  constant C_PCIE_DATA_SIZE_IN_BINARY : natural range 1 to 16  := 16;
  constant C_VALID_BIT_POSITION       : natural range 0 to 63  := 0;
  constant C_ID_LSB_POSITION          : natural range 0 to 63  := 32;

  constant C_SYSTEM_RAM_OFFSET : std_logic_vector := x"1DA00000";  -- 474 MB
  
  ------------------------------------------------------------------------------
  constant C_NDL_DATA_WIDTH  : natural range 1 to 64  := C_32BIT_BUS_WIDTH;
  ------------------------------------------------------------------------------
  -- PCIe Interface
  ------------------------------------------------------------------------------
  constant C_NB_REGS : natural := 8;
  type     T_REGS is array(0 to C_NB_REGS-1) of std_logic_vector(63 downto 0);

  constant C_NB_CMD_REGS : natural := 1;
  type     T_CMD_REGS is array(0 to C_NB_CMD_REGS-1) of std_logic_vector(63 downto 0);

  constant C_NB_STATUS_REGS : natural := 7;
  type     T_STATUS_REGS is array(0 to C_NB_STATUS_REGS-1) of std_logic_vector(63 downto 0);

  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  -- TOP LEVEL
  ------------------------------------------------------------------------------
  constant C_NB_DEBUGIOs : natural range 1 to 64 := 32;

  constant C_CMD_QUEUE_DEPTH_IN_BINARY : natural := 4;
  -- 16 + 16 + 32
  constant C_PCIE_PARAMS_FIFO_WIDTH : natural := C_PCIE_DATA_SIZE_IN_BINARY +
                                                 C_PCIE_LOCAL_ADDR_WIDTH +
                                                 C_PCIE_TARGET_ADDR_WIDTH;

  constant C_PCIE_PARAMS_FIFO_DEPTH_IN_BINARY : natural := 4;

  constant C_PROBE_ID_WIDTH : natural range 1 to 64 := 16;

  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  -- SECURE MGMT
  ------------------------------------------------------------------------------
  constant C_PROGRAM_MEM_DATA_WIDTH     : natural := 32;
  constant C_PROGRAM_MEM_ADDRESS_WIDTH  : natural := 8;
  constant C_SECURE_DATA_WIDTH          : natural := 8;
  constant C_SECURE_SECRET_KEY_WIDTH    : natural := 64;
  constant C_SECURE_ID_WIDTH            : natural := 48;
  constant C_SECURE_PROG_CHIPS_VN_WIDTH : natural := 12;

  constant C_SECRET_KEY_ID : std_logic_vector(C_SECURE_SECRET_KEY_WIDTH-1 downto 0) := x"ac78223127c43e09";

  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  -- Frame Compounding
  ------------------------------------------------------------------------------  
  constant C_CMPD_MEM_WIDTH                  : natural := 7;
  constant C_CMPD_MEM_DEPTH_BIN              : natural := 12;
  constant C_FRAME_CMPD_DATA_WIDTH           : natural := 16;
  constant C_FRAME_CMPD_REPETITION_REG_WIDTH : natural := 2;
  constant C_FRAME_CMPD_RAM_ADDR_WIDTH       : natural := 10;
  -------------------------
  -- PMNDT
  -------------------------
  constant C_PMNDT_MEM_DEPTH_BIN             : natural := 6;
  constant C_CMD_PROBE_RD      : std_logic_vector(16-1 downto 0) := x"9000";
  constant C_CMD_PROBE_WR      : std_logic_vector(16-1 downto 0) := x"A000";
  constant C_CMD_PROBE_HOLD    : std_logic_vector(16-1 downto 0) := x"B000";
  constant C_CMD_PROBE_ERR_CLR : std_logic_vector(16-1 downto 0) := x"E000"; -- Returns Probe_mgmt_ndt FSM from 
                                                                             -- ERROR state to READY  
  constant C_CMD_PROBE_MC_RES  : std_logic_vector(16-1 downto 0) := x"F000"; -- Command for MC reset

  ------------------------------------------------------------------------------
  -- Median & Geometric Filters
  ------------------------------------------------------------------------------  
  constant C_ORDER      : natural := 3;
  constant C_HIGH_ORDER : natural := 5;

  constant C_FILTER_DATA_WIDTH : natural := 16;

  constant C_DOUBLE_FILTER_DATA_WIDTH          : natural := 2 * C_FILTER_DATA_WIDTH;
  constant C_TRIPLE_FILTER_DATA_WIDTH          : natural := 3 * C_FILTER_DATA_WIDTH;
  constant C_FILTER_HYBRID_DATA_WIDTH          : natural := 2 * C_FILTER_DATA_WIDTH;
  constant C_FILTER_DATA_WIDTH_PLUS_ONE        : natural := C_FILTER_DATA_WIDTH + 1;
  constant C_DOUBLE_FILTER_DATA_WIDTH_PLUS_ONE : natural := C_DOUBLE_FILTER_DATA_WIDTH + 1;

  type T_NEIGHBOUR_GROUP is array(0 to C_ORDER-1) of
    std_logic_vector(C_FILTER_DATA_WIDTH-1 downto 0);

  type T_DOUBLE_NEIGHBOUR_GROUP is array(0 to C_ORDER-1) of
    std_logic_vector(C_DOUBLE_FILTER_DATA_WIDTH-1 downto 0);

  type T_TRIPLE_NEIGHBOUR_GROUP is array(0 to C_ORDER-1) of
    std_logic_vector(C_TRIPLE_FILTER_DATA_WIDTH-1 downto 0);

  type T_HYBRID_NEIGHBOUR_GROUP is array(0 to C_ORDER-1) of
    std_logic_vector(C_FILTER_HYBRID_DATA_WIDTH-1 downto 0);

  type T_HIGH_NEIGHBOUR_GROUP is array(0 to C_HIGH_ORDER-1) of
    std_logic_vector(C_FILTER_DATA_WIDTH-1 downto 0);

  type T_PLUS_ONE_NEIGHBOUR_GROUP is array(0 to C_ORDER-1) of
    std_logic_vector(C_FILTER_DATA_WIDTH_PLUS_ONE-1 downto 0);

  type T_PLUS_ONE_DOUBLE_NEIGHBOUR_GROUP is array(0 to C_ORDER-1) of
    std_logic_vector(C_DOUBLE_FILTER_DATA_WIDTH_PLUS_ONE-1 downto 0);

  type T_NEIGHBOUR_HOOD is array(0 to C_ORDER-1) of
    T_NEIGHBOUR_GROUP;

  type T_3x3_NEIGHBOUR_HOOD is array(0 to C_ORDER-1) of
    T_NEIGHBOUR_GROUP;

  type T_HYBRID_NEIGHBOUR_HOOD is array(0 to C_ORDER-1) of
    T_HYBRID_NEIGHBOUR_GROUP;

  type T_5x3_NEIGHBOUR_HOOD is array(0 to C_HIGH_ORDER-1) of
    T_NEIGHBOUR_GROUP;

  type T_5x3_HYBRID_NEIGHBOUR_HOOD is array(0 to C_HIGH_ORDER-1) of
    T_HYBRID_NEIGHBOUR_GROUP;

  type T_3x3_PLUS_ONE_NEIGHBOUR_HOOD is array(0 to C_ORDER-1) of
    T_PLUS_ONE_NEIGHBOUR_GROUP;

  constant C_MAX_LINES : natural := 194;
  constant C_MAX_SMPLS : natural := 1024;

  constant C_FIFO_DEPTH_IN_BINARY : natural := 2;

  constant C_LINE_CNT_WIDTH : natural := C_LINE_ID_LINE_NB_WIDTH;
  constant C_SMPL_CNT_WIDTH : natural := 10;

  constant C_ITERATION_WIDTH : natural                             := 3;
  constant C_MAX_ITERATIONS  : natural                             := 2 ** C_ITERATION_WIDTH;
  constant C_NB_ITERATIONS   : natural range 0 to C_MAX_ITERATIONS := 6;
  constant C_GEO_STEP_WIDTH  : natural                             := 8;

  type T_GEO_STEP is array(0 to C_NB_ITERATIONS-1) of
    std_logic_vector(C_GEO_STEP_WIDTH-1 downto 0);

  ------------------------------------------------------------------------------
  -- Doppler Median Filter
  ------------------------------------------------------------------------------

  constant C_F_MODE_HYBRID_FILTER_DATA_WIDTH : natural := 11;  --8 bits for velocity and3 fow variance
  constant C_F_MODE_FILTER_DATA_WIDTH        : natural := 8;
  constant C_F_MODE_SMPL_CNT_WIDTH           : natural := C_MAX_NB_DOPPLER_POINTS_IN_BIN;

  type T_F_MODE_HYBRID_NEIGHBOUR_GROUP is array(0 to C_ORDER-1) of
    std_logic_vector(C_F_MODE_HYBRID_FILTER_DATA_WIDTH-1 downto 0);


  ------------------------------------------------------------------------------
  -- Device Dependencies
  ------------------------------------------------------------------------------
  constant C_VENDOR : T_FPGA_VENDOR := ALTERA;
  constant C_FAMILY : T_FPGA_FAMILY := Stratix_II_GX;
  ------------------------------------------------------------------------------

end package proj_package;
-------------------------------------------------------------------------------
