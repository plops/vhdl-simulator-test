library ieee;

use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.proj_package.all;
use work.main_ctrl_block_package.all;

------------------------------------------------------------------------------
-- Entity Description
------------------------------------------------------------------------------
entity config_fsm is

  port (
    rst                   : in std_logic;
    clk                   : in std_logic;

    master_current_state  : in T_MASTER_SM_STATE_TYPE;
    scan_current_state    : in T_SCAN_SM_STATE_TYPE;
    line_id_current_state : in T_LINE_ID_SM_STATE_TYPE;

    analog_conf_done      : in  std_logic_vector(C_NB_ANALOG_CONFS-1 downto 0);
    analog_conf           : out std_logic_vector(C_NB_ANALOG_CONFS-1 downto 0);

    current_state         : out T_CONFIG_SM_STATE_TYPE;
    status                : out T_STATUS_CODE
    );

end config_fsm;

------------------------------------------------------------------------------
-- Architecture Description
------------------------------------------------------------------------------
architecture RTL of config_fsm is

  signal config_current_state   : T_CONFIG_SM_STATE_TYPE;
  signal config_next_state      : T_CONFIG_SM_STATE_TYPE;
  signal line_id_previous_state : T_LINE_ID_SM_STATE_TYPE;
  signal scan_previous_state    : T_SCAN_SM_STATE_TYPE;
  signal status_r               : T_STATUS_CODE;

  signal analog_conf_done_r     : std_logic_vector(C_NB_ANALOG_CONFS-1 downto 0);
  signal analog_conf_r          : std_logic_vector(C_NB_ANALOG_CONFS-1 downto 0);

begin

  current_state <= config_current_state;
  analog_conf   <= analog_conf_r;
  status        <= status_r;

  -- Configuration FSM --
  --
  fsm_sync_proc : process (rst, clk)
  begin

    if rst = '1' then

      config_current_state   <= CONFIG_SM_IDLE;
      line_id_previous_state <= LINE_ID_SM_IDLE;
      scan_previous_state    <= SCAN_SM_IDLE;
      analog_conf_r          <= C_ANALOG_CONF_ALL_ZEROS;
      analog_conf_done_r     <= C_ANALOG_CONF_DONE_ALL_ONES;

    elsif clk'event and clk = '1' then

      config_current_state   <= config_next_state;
      line_id_previous_state <= line_id_current_state;
      scan_previous_state    <= scan_current_state;
      analog_conf_done_r     <= analog_conf_done;


      analog_conf_r <= C_ANALOG_CONF_ALL_ZEROS;

      -- For every Line, after Line ID is successful Fetched,
      -- issue configuration triggers for ADS & VCA
      --
      if
        line_id_previous_state /= line_id_current_state and
        line_id_current_state = LINE_ID_SM_LINE_ID_READY
      then

        analog_conf_r(C_ADS) <= '1';
        analog_conf_r(C_VCA) <= '1';

      -- For every Line, at the start of Reception,
      -- issue configuration trigger for DAC
      --
      elsif
        scan_previous_state /= scan_current_state and
        scan_current_state = SCAN_SM_RECEPTION
      then

        analog_conf_r(C_DAC) <= '1';

      end if;

    end if;

  end process fsm_sync_proc;


  fsm_combo_proc : process (
    master_current_state,
    config_current_state,
    analog_conf_done,
    analog_conf_done_r,
    analog_conf_r
    )
  begin

    config_next_state <= config_current_state;

    if master_current_state /= MASTER_SM_SCAN then
      config_next_state <= CONFIG_SM_IDLE;
    else

      case config_current_state is

        -- Go to Configure state if it is requested to configure ADS, VCA or DAC..
        -- or if analog_conf_done bus is not all to ones.
        --
        when CONFIG_SM_IDLE =>

          if
            analog_conf_r /= C_ANALOG_CONF_ALL_ZEROS or
            analog_conf_done /= C_ANALOG_CONF_DONE_ALL_ONES
          then

            config_next_state <= CONFIG_SM_CONFIGURE;

          end if;


        -- Configuration under progress ...
        -- Waiting for configuration confirmation, when analog_conf_done bus
        -- is all to ones.
        --
        when CONFIG_SM_CONFIGURE =>

        -- We make sure that we configured the things that we wanted !!
        --
          if
            analog_conf_done /= analog_conf_done_r and
            analog_conf_done = C_ANALOG_CONF_DONE_ALL_ONES
          then

            config_next_state <= CONFIG_SM_IDLE;

          end if;


        -- Others
        when others =>

          config_next_state <= CONFIG_SM_IDLE;


      end case;

    end if;

  end process fsm_combo_proc;


  -- This process encodes current state into a status register
  --
  status_proc : process (rst, clk)
  begin

    if rst = '1' then

      status_r <= C_CONFIG_STATUS_IDLE;

    elsif clk'event and clk = '1' then

      case config_current_state is

        when CONFIG_SM_IDLE =>
          status_r <= C_CONFIG_STATUS_IDLE;

        when CONFIG_SM_CONFIGURE =>
          status_r <= C_CONFIG_STATUS_CONFIGURE;

        when others =>
          status_r <= C_CONFIG_STATUS_IDLE;

      end case;

    end if;

  end process status_proc;

end RTL;
