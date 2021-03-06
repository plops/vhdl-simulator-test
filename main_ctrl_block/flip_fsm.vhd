
library ieee;

use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.proj_package.all;
use work.main_ctrl_block_package.all;

------------------------------------------------------------------------------
-- Entity Description
------------------------------------------------------------------------------
entity flip_fsm is

  generic (
    g_config_id_width : natural := 12
    );

  port (
    rst : in std_logic;
    clk : in std_logic;

    master_current_state : in T_MASTER_SM_STATE_TYPE;
    scan_current_state   : in T_SCAN_SM_STATE_TYPE;
    config_current_state : in T_CONFIG_SM_STATE_TYPE;

    cmd_rdy  : in std_logic;
    cmd_code : in T_CMD_CODE;
    cmd_data : in T_CMD_DATA;

    -- To allow Flip only between Frames
    frame_session : in std_logic;

    flip      : out std_logic;
    config_id : out std_logic_vector(g_config_id_width-1 downto 0);

    current_state : out T_FLIP_SM_STATE_TYPE;
    status        : out T_STATUS_CODE
    );

end flip_fsm;

------------------------------------------------------------------------------
-- Architecture Description
------------------------------------------------------------------------------
architecture RTL of flip_fsm is

  signal flip_current_state  : T_FLIP_SM_STATE_TYPE;
  signal flip_next_state     : T_FLIP_SM_STATE_TYPE;
  signal scan_previous_state : T_SCAN_SM_STATE_TYPE;
  signal status_r            : T_STATUS_CODE;

  signal config_id_r : std_logic_vector(g_config_id_width-1 downto 0);
  signal flip_r      : std_logic;

begin

  current_state <= flip_current_state;

  flip      <= flip_r;
  config_id <= config_id_r;
  status    <= status_r;

  -- Flip FSM --
  fsm_sync_proc : process (rst, clk)
  begin

    if rst = '1' then

      flip_current_state  <= FLIP_SM_IDLE;
      scan_previous_state <= SCAN_SM_IDLE;

      flip_r      <= '0';
      config_id_r <= (others => '0');

    elsif clk'event and clk = '1' then

      flip_current_state  <= flip_next_state;
      scan_previous_state <= scan_current_state;

      if flip_current_state = FLIP_SM_FLIP then

        flip_r      <= not flip_r;
        config_id_r <= cmd_data(g_config_id_width-1 downto 0);

      end if;

    end if;

  end process fsm_sync_proc;


  fsm_combo_proc : process (
    flip_current_state,
    master_current_state,
    scan_current_state,
    scan_previous_state,
    config_current_state,
    cmd_code,
    cmd_data,
    cmd_rdy,
    frame_session
    )
  begin

    flip_next_state <= flip_current_state;

    case flip_current_state is

      when FLIP_SM_IDLE =>

        if
          cmd_rdy = '1' and
          cmd_code = C_CMD_FLIP
        then

          -- If not Scanning, allow Flip.
          if master_current_state /= MASTER_SM_SCAN then

            flip_next_state <= FLIP_SM_FLIP;

          -- While Scanning, we allow Flip only between Frames
          -- So, we wait for Last Line in the Frame
          -- i.e. frame_session = '0'
          --
          elsif frame_session = '0' then

            flip_next_state <= FLIP_SM_WAIT_BEFORE_FLIP;

          end if;

        end if;


      -- If FLIP occurs while Scanning, We wait for Last Line and
      -- allow flip at End-of-Last-Line in the Frame
      -- i.e. scan_current_state = SCAN_SM_READY
      --
      when FLIP_SM_WAIT_BEFORE_FLIP =>

        if
          scan_current_state /= scan_previous_state and
          scan_current_state = SCAN_SM_READY and
          config_current_state = CONFIG_SM_IDLE
        then

          flip_next_state <= FLIP_SM_FLIP;

        end if;


      -- Do Flip
      when FLIP_SM_FLIP =>

        flip_next_state <= FLIP_SM_WAIT_AFTER_FLIP;


      -- Wait to stabilize flip bus
      when FLIP_SM_WAIT_AFTER_FLIP =>

        flip_next_state <= FLIP_SM_WAIT;


      -- Indicates FLIP command is consumed
      when FLIP_SM_WAIT =>

        flip_next_state <= FLIP_SM_IDLE;


      -- Others
      when others =>

        flip_next_state <= FLIP_SM_IDLE;

    end case;

  end process fsm_combo_proc;




end RTL;
