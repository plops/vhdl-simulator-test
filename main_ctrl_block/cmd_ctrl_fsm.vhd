library ieee;

use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.ezono_package.all;
use work.proj_package.all;
use work.main_ctrl_block_package.all;

------------------------------------------------------------------------------
-- Entity Description
------------------------------------------------------------------------------
entity cmd_ctrl_fsm is

  generic (
    g_vendor : T_FPGA_VENDOR := ALTERA;
    g_family : T_FPGA_FAMILY := Stratix_II_GX
    );

  port (
    rst                        : in  std_logic;
    clk                        : in  std_logic;

    cmd_valid                  : in  std_logic;
    cmd_in                     : in  T_CMD_REG;

    master_current_state       : in  T_MASTER_SM_STATE_TYPE;
    scan_current_state         : in  T_SCAN_SM_STATE_TYPE;
    flip_current_state         : in  T_FLIP_SM_STATE_TYPE;

    -- To know Frame Transitions
    frame_session              : in  std_logic;

    wait_until_processing_ends : out std_logic;
    rst_out                    : out std_logic;

    watchdog_wake              : out std_logic;

    cmd_valid_ndt              : out std_logic;
    cmd_ndt                    : out T_CMD_REG;

    cmd_rdy                    : out std_logic;
    cmd_code                   : out T_CMD_CODE;
    cmd_data                   : out T_CMD_DATA;

    last_processed_cmd         : out T_CMD_REG
    );

end cmd_ctrl_fsm;

------------------------------------------------------------------------------
-- Architecture Description
------------------------------------------------------------------------------
architecture RTL of cmd_ctrl_fsm is

  component mem_sc_fifo
    generic(
      g_vendor          : T_FPGA_VENDOR;
      g_family          : T_FPGA_FAMILY;
      g_width           : natural;
      g_depth_in_binary : natural
      );
    port (
      rst         : in  std_logic;
      clk         : in  std_logic;
      enable      : in  std_logic;
      push        : in  std_logic;
      pop         : in  std_logic;
      data        : in  std_logic_vector(g_width-1 downto 0);
      q           : out std_logic_vector(g_width-1 downto 0);
      empty       : out std_logic;
      full        : out std_logic;
      almost_full : out std_logic;
      usedw       : out std_logic_vector(g_depth_in_binary-1 downto 0)
      );
  end component;

  constant C_CMD_QUEUE_DEPTH_IN_BINARY : natural range 1 to 6               := 4;
  constant C_CMD_QUEUE_WIDTH           : natural range 1 to C_CMD_REG_WIDTH := C_CMD_REG_WIDTH;

  signal cmd_ctrl_current_state        : T_CMD_CTRL_SM_STATE_TYPE;
  signal cmd_ctrl_next_state           : T_CMD_CTRL_SM_STATE_TYPE;
  signal scan_previous_state           : T_SCAN_SM_STATE_TYPE;

  signal cmd_out                       : T_CMD_REG;
  signal last_processed_cmd_r          : T_CMD_REG;

  signal rst_out_r                     : std_logic;
  signal watchdog_wake_r               : std_logic;

  signal cmd_queue_enable_r            : std_logic;

  signal cmd_valid_r                   : std_logic;
  signal cmd_in_r                      : T_CMD_REG;

  signal cmd_valid_ndt_r               : std_logic;
  signal cmd_ndt_r                     : T_CMD_REG;

  signal cmd_req_r                     : std_logic;
  signal cmd_queue_empty               : std_logic;

  signal cmd_rdy_r                     : std_logic;
  signal cmd_code_r                    : T_CMD_CODE;
  signal cmd_data_r                    : T_CMD_DATA;

  signal wait_until_processing_ends_r : std_logic;

begin

  cmd_rdy                    <= cmd_rdy_r;
  cmd_code                   <= cmd_code_r;
  cmd_data                   <= cmd_data_r;

  cmd_valid_ndt              <= cmd_valid_ndt_r;
  cmd_ndt                    <= cmd_ndt_r;

  last_processed_cmd         <= last_processed_cmd_r;

  rst_out                    <= rst_out_r;
  watchdog_wake              <= watchdog_wake_r;

  wait_until_processing_ends <= wait_until_processing_ends_r;

  wait_until_processing_ends_proc : process (rst, clk)
  begin

    if rst = '1' then

      wait_until_processing_ends_r <= '0';

    elsif clk'event and clk = '1' then

      if
        frame_session = '0' and
        cmd_rdy_r = '1' and
        ( cmd_code_r = C_CMD_FLIP or
          cmd_code_r = C_CMD_STOP_SCAN )
      then

         wait_until_processing_ends_r <= '1';

      else
        wait_until_processing_ends_r <= '0';
      end if;

    end if;

  end process wait_until_processing_ends_proc;


  -- This process looks for cmd_valid = '1' and
  -- checks if the command is FSM RESET or WATCHDOG.
  -- If Yes, then it will execute them instantaneously.
  -- If No, then it will push this cmd into the cmd_queue FIFO
  -- This cmd queue FIFO will be popped when CMD CTRL FSM
  -- goes to CMD_REQUEST state.
  --
  cmd_queue_proc : process (rst, clk)
  begin

    if rst = '1' then

      cmd_in_r             <= (others => '0');
      last_processed_cmd_r <= (others => '0');

      cmd_queue_enable_r   <= '0';
      cmd_valid_r          <= '0';
      cmd_req_r            <= '0';
      rst_out_r            <= '0';
      watchdog_wake_r      <= '0';

      cmd_valid_ndt_r      <= '0';

    elsif clk'event and clk = '1' then

      cmd_req_r       <= '0';
      rst_out_r       <= '0';
      watchdog_wake_r <= '0';

      cmd_in_r        <= cmd_in;


      -- cmd_queue_enable_r
      --
      if
        master_current_state = MASTER_SM_POWER_OFF or
        master_current_state = MASTER_SM_SECURITY_CHECK or
        master_current_state = MASTER_SM_ERROR or
        master_current_state = MASTER_SM_STANDBY
      then

        cmd_queue_enable_r <= '0';

      else
        cmd_queue_enable_r <= '1';
      end if;


      -- cmd_valid
      -- create cmd_valid_r and cmd_valid_ndt_r
      -- cmd_valid_r: push cmd in the Command Queue FIFO
      -- cmd_valid_ndt_r: indicates when a command is for PROBE_MGMT_NDT
      --                  Those commands are not stored in the fifo.
      --
       if cmd_valid_ndt_r = '1' then
       
         cmd_valid_ndt_r <= '0';
         
       elsif cmd_valid = '1' then

        -- Prioritizing FSM RESET Command
        -- Issue rst signal for 1 clock cycle
        --
        if cmd_in (C_CMD_CODE_UL downto C_CMD_CODE_LL) = C_CMD_RESET then

          cmd_valid_r <= '0';
          rst_out_r   <= '1';

        -- Prioritizing FSM WAKE WATCHDOG Command
        -- Issue wake watchdog signal for 1 clock cycle
        --
        elsif cmd_in (C_CMD_CODE_UL downto C_CMD_CODE_LL) = C_CMD_WATCHDOG_WAKE then

          cmd_valid_r     <= '0';
          watchdog_wake_r <= '1';

        -- Ignoring any other commands while MASTER FSM is
        -- in POWER_OFF / SECURITY_CHECK / STANDBY states
        --
        elsif
          master_current_state = MASTER_SM_POWER_OFF or
          master_current_state = MASTER_SM_SECURITY_CHECK or
          master_current_state = MASTER_SM_ERROR or
          master_current_state = MASTER_SM_STANDBY
        then

          cmd_valid_r <= '0';

        -- Accept Commands
        else
          if cmd_in(C_CMD_REG_WIDTH-1) = '1' then

            cmd_valid_ndt_r <= '1';
            cmd_ndt_r       <= cmd_in; ----------!!!!!!!!!!!!!!!!!!!!!!!!!!!!

            cmd_valid_r     <= '0';

          else

            cmd_valid_r     <= '1';

          end if;
        
        end if;

      else
        cmd_valid_r <= '0';
      end if;


      -- Pop command Queue
      if cmd_ctrl_next_state = CMD_CTRL_SM_CMD_REQUEST then
        cmd_req_r <= '1';
      end if;


      -- last_processed_cmd_r
      if
        cmd_ctrl_current_state /= cmd_ctrl_next_state and
        cmd_ctrl_current_state = CMD_CTRL_SM_CONSUME
      then

        last_processed_cmd_r <= cmd_code_r & cmd_data_r;

      end if;

    end if;

  end process cmd_queue_proc;


  -- Command Queue FIFO
  --
  cmd_queue : mem_sc_fifo
    generic map (
      g_vendor          => g_vendor,
      g_family          => g_family,
      g_width           => C_CMD_QUEUE_WIDTH,
      g_depth_in_binary => C_CMD_QUEUE_DEPTH_IN_BINARY
      )
    port map (
      rst         => rst,
      clk         => clk,
      enable      => cmd_queue_enable_r,

      push        => cmd_valid_r,
      pop         => cmd_req_r,

      data        => cmd_in_r,
      q           => cmd_out,

      empty       => cmd_queue_empty,
      full        => open,
      almost_full => open,

      usedw       => open
      );


  -- Command Control FSM --

  fsm_sync_proc : process (rst, clk)
  begin

    if rst = '1' then

      cmd_ctrl_current_state <= CMD_CTRL_SM_IDLE;
      scan_previous_state    <= SCAN_SM_IDLE;

      cmd_code_r             <= (others => '0');
      cmd_data_r             <= (others => '0');
      cmd_rdy_r              <= '0';

    elsif clk'event and clk = '1' then

      if cmd_queue_enable_r = '1' then

        cmd_ctrl_current_state <= cmd_ctrl_next_state;
        scan_previous_state    <= scan_current_state;

        -- Parse the Command Code & Data
        -- Flag Command Ready
        --
        if cmd_ctrl_current_state = CMD_CTRL_SM_NEW_CMD then

          cmd_code_r <= cmd_out(C_CMD_CODE_UL downto
                                C_CMD_CODE_LL);

          cmd_data_r <= cmd_out(C_CMD_DATA_UL downto
                                C_CMD_DATA_LL);

          cmd_rdy_r <= '1';

          -- Command Consume
        elsif cmd_ctrl_current_state = CMD_CTRL_SM_CONSUME then

          case cmd_code_r is

            -- Regardless of the state, the command is consumed
            when C_CMD_RESET =>

              cmd_rdy_r <= '0';

            -- Regardless of the state, the command is consumed
            when C_CMD_WATCHDOG_WAKE =>

              cmd_rdy_r <= '0';


              -- FLIP MEM is consumed while
              -- 1) Main FSM is in Idle
              -- 2) Between Frames, while Main FSM is Scanning
              --
            when C_CMD_FLIP =>

              -- when Flip is done !!
              if flip_current_state = FLIP_SM_WAIT then
                cmd_rdy_r <= '0';
              end if;


              -- The command is consumed when it enters the SCAN state
            when C_CMD_SCAN =>

              if master_current_state = MASTER_SM_SCAN then
                cmd_rdy_r <= '0';
              end if;


              -- If Main FSM is SCAN, CMD_STOP gets consumed in the
              -- Scan FSM state only at end of Frame.
              -- The command is ignored in rest of Main FSM states. not really in pause it should also stop stuff
              --
            when C_CMD_STOP_SCAN =>

              if master_current_state = MASTER_SM_SCAN then

                if
                  scan_current_state /= scan_previous_state and
                  scan_current_state = SCAN_SM_READY and
                  frame_session = '0'
                then

                  cmd_rdy_r <= '0';

                end if;

              else
                cmd_rdy_r <= '0';
              end if;

				 --- CMD_PAUSE gets consumed in Scan FSM state at end of frame, otherwise it is ignored
				 when C_CMD_PAUSE_SCAN =>

              if master_current_state = MASTER_SM_SCAN then

                if
                  scan_current_state /= scan_previous_state and
                  scan_current_state = SCAN_SM_READY and
                  frame_session = '0'
                then

                  cmd_rdy_r <= '0';

                end if;

              else
                cmd_rdy_r <= '0';
              end if;


              -- Any other command code will be consumed... and leaves no trace!!!
              --
            when others =>

              cmd_rdy_r <= '0';


          end case;

          -- When IDLE or Undefined !!!
        else
          cmd_rdy_r <= '0';
        end if;

      else

        cmd_ctrl_current_state <= CMD_CTRL_SM_IDLE;
        scan_previous_state    <= SCAN_SM_IDLE;

        cmd_code_r             <= (others => '0');
        cmd_data_r             <= (others => '0');
        cmd_rdy_r              <= '0';

      end if;

    end if;

  end process fsm_sync_proc;


  fsm_combo_proc : process (
    cmd_ctrl_current_state,
    cmd_queue_empty,
    cmd_rdy_r
    )
  begin

    cmd_ctrl_next_state <= cmd_ctrl_current_state;

    case cmd_ctrl_current_state is

      -- Get out of IDLE state if CMD QUEUE is not empty
      when CMD_CTRL_SM_IDLE =>

        if cmd_queue_empty = '0' then
          cmd_ctrl_next_state <= CMD_CTRL_SM_CMD_REQUEST;
        end if;

        -- Pop Command Queue
      when CMD_CTRL_SM_CMD_REQUEST =>

        cmd_ctrl_next_state <= CMD_CTRL_SM_NEW_CMD;

        -- Parse Command for Code & Data. Issue Command Ready
      when CMD_CTRL_SM_NEW_CMD =>

        cmd_ctrl_next_state <= CMD_CTRL_SM_CONSUME;

        -- Wait till we consume the Command
      when CMD_CTRL_SM_CONSUME =>

        if cmd_rdy_r = '0' then

          if cmd_queue_empty = '0' then
            cmd_ctrl_next_state <= CMD_CTRL_SM_CMD_REQUEST;
          else
            cmd_ctrl_next_state <= CMD_CTRL_SM_IDLE;
          end if;

        end if;

    end case;

  end process fsm_combo_proc;

end RTL;
