library ieee;

use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.proj_package.all;
use work.main_ctrl_block_package.all;

------------------------------------------------------------------------------
-- Entity Description
------------------------------------------------------------------------------
entity line_id_fsm is

  port (
    rst                  : in  std_logic;
    clk                  : in  std_logic;

    master_current_state : in  T_MASTER_SM_STATE_TYPE;
    scan_current_state   : in  T_SCAN_SM_STATE_TYPE;
    flip_current_state   : in  T_FLIP_SM_STATE_TYPE;
    config_current_state : in  T_CONFIG_SM_STATE_TYPE;

    line_id_in           : in  std_logic_vector(C_LINE_ID_WIDTH-1 downto 0);
    line_id_rdy_in       : in  std_logic;
    mux_switch_done      : in  std_logic;

    line_id_rd           : out std_logic;
    new_line             : out std_logic;
    load_focus_params    : out std_logic;

    do_mux_switch        : out std_logic;
    line_id_out          : out std_logic_vector(C_LINE_ID_WIDTH-1 downto 0);

    current_state        : out T_LINE_ID_SM_STATE_TYPE;
    status               : out T_STATUS_CODE
    );

end line_id_fsm;

------------------------------------------------------------------------------
-- Architecture Description
------------------------------------------------------------------------------
architecture RTL of line_id_fsm is

  component cnt_preload_countdown
    generic (
      g_preload_word_width : natural
      );
    port (
      clk          : in  std_logic;
      rst          : in  std_logic;
      start_count  : in  std_logic;
      load         : in  std_logic;
      preload_word : in  std_logic_vector(g_preload_word_width-1 downto 0);
      count_ended  : out std_logic
      );
  end component;

  signal line_id_current_state : T_LINE_ID_SM_STATE_TYPE;
  signal line_id_next_state    : T_LINE_ID_SM_STATE_TYPE;
  signal scan_previous_state   : T_SCAN_SM_STATE_TYPE;
  signal status_r              : T_STATUS_CODE;

  signal start_count_r         : std_logic;
  signal count_ended           : std_logic;
  signal line_id_rd_r          : std_logic;
  signal line_id_rdy_in_r      : std_logic;
  signal new_line_r            : std_logic;
  signal do_mux_switch_r       : std_logic;
  signal mux_switch_done_r     : std_logic;

  signal load_focus_params_r   : std_logic;

  signal line_id_out_r         : std_logic_vector(C_LINE_ID_WIDTH-1 downto 0);

  signal cnt_load_value_r      : std_logic_vector(
    C_FILLER_DELAY_WIDTH +C_FILLER_DELAY_PADDING_ZEROS-1 downto 0);

begin

  line_id_rd        <= line_id_rd_r;
  line_id_out       <= line_id_out_r;

  new_line          <= new_line_r;
  do_mux_switch     <= do_mux_switch_r;
  load_focus_params <= load_focus_params_r;

  current_state     <= line_id_current_state;
  status            <= status_r;

  -- Wait on Filler
  cnt_preload_countdown_inst1 : cnt_preload_countdown
    generic map (
      g_preload_word_width => C_FILLER_DELAY_WIDTH + C_FILLER_DELAY_PADDING_ZEROS
      )
    port map (
      clk          => clk,
      rst          => rst,
      start_count  => start_count_r,
      load         => start_count_r,
      preload_word => cnt_load_value_r,
      count_ended  => count_ended
      );


  -- Line Id FSM --

  fsm_sync_proc : process (rst, clk)
  begin

    if rst = '1' then

      line_id_current_state <= LINE_ID_SM_IDLE;
      scan_previous_state   <= SCAN_SM_IDLE;

      line_id_rd_r          <= '0';
      line_id_rdy_in_r      <= '0';
      new_line_r            <= '0';
      do_mux_switch_r       <= '0';
      mux_switch_done_r     <= '1';
      start_count_r         <= '0';

      cnt_load_value_r      <= (others => '0');
      line_id_out_r         <= (others => '0');

      load_focus_params_r   <= '0';

    elsif clk'event and clk = '1' then

      line_id_current_state <= line_id_next_state;
      scan_previous_state   <= scan_current_state;
      line_id_rdy_in_r      <= line_id_rdy_in;
      mux_switch_done_r     <= mux_switch_done;

      -- Request Line ID when FSM is in Fetch Line ID state
      if
        line_id_current_state /= line_id_next_state and
        line_id_next_state = LINE_ID_SM_FETCH_LINE_ID
      then

        line_id_rd_r <= '1';

      else
        line_id_rd_r <= '0';
      end if;

      -- Line ID
      if
        line_id_current_state /= line_id_next_state and
        line_id_next_state = LINE_ID_SM_LINE_ID_READY
      then

        line_id_out_r <= line_id_in;

      end if;

      -- Request MUX Programming when FSM is in MUX PROGRAMMING state
      if
        line_id_current_state /= line_id_next_state and
        line_id_next_state = LINE_ID_SM_MUX_PROGRAMMING
      then

        do_mux_switch_r <= '1';

      else
        do_mux_switch_r <= '0';
      end if;

      -- load_focus_params_r is active after Line ID is fetched
      if line_id_next_state = LINE_ID_SM_IDLE then

        load_focus_params_r <= '0';

      elsif
        line_id_current_state /= line_id_next_state and
        line_id_next_state = LINE_ID_SM_MUX_PROGRAMMING
      then

        load_focus_params_r <= '1';

      end if;


      -- new_line is active when FSM is in READY state
      if line_id_current_state = LINE_ID_SM_READY then
        new_line_r <= '1';
      else
        new_line_r <= '0';
      end if;

      -- start_count_r & cnt_load_value_r
      if
        line_id_current_state /= line_id_next_state and
        line_id_next_state = LINE_ID_SM_WAIT_ON_FILLER
      then

        start_count_r <= '1';
        cnt_load_value_r <= line_id_in(
          C_FILLER_DELAY_WIDTH_UL downto
          C_FILLER_DELAY_WIDTH_LL
          ) & C_ZEROS_64BIT(
            C_FILLER_DELAY_PADDING_ZEROS-1 downto 0
            );

      else
        start_count_r <= '0';
      end if;

    end if;

  end process fsm_sync_proc;


  fsm_combo_proc : process (
    line_id_current_state,
    master_current_state,
    scan_current_state,
    scan_previous_state,
    flip_current_state,
    config_current_state,
    line_id_in,
    line_id_rdy_in,
    line_id_rdy_in_r,
    mux_switch_done,
    mux_switch_done_r,
    count_ended
    )
  begin

    line_id_next_state <= line_id_current_state;

    -- Here we ignore configuration FSM because
    -- it is liable to change during SCAN !!!
    --
    if master_current_state /= MASTER_SM_SCAN or
      ( flip_current_state /= FLIP_SM_IDLE and
        flip_current_state /= FLIP_SM_WAIT_BEFORE_FLIP )
    then

      line_id_next_state <= LINE_ID_SM_IDLE;

    else

      case line_id_current_state is

        -- When Main FSM is Scanning
        -- We have to be sure that no confguration is being done
        -- atleast before starting new scan line !!
        --
        when LINE_ID_SM_IDLE =>

          if
            flip_current_state = FLIP_SM_IDLE and
            config_current_state = CONFIG_SM_IDLE
          then

            line_id_next_state <= LINE_ID_SM_FETCH_LINE_ID;

          end if;


        -- Wait till we get Line ID
        when LINE_ID_SM_FETCH_LINE_ID =>

          if line_id_rdy_in_r = '0' and line_id_rdy_in = '1' then

            -- Line ID is a Filler
            if line_id_in(C_LINE_ID_FILLER_POSITION) = C_LINE_ID_FILLER then

              line_id_next_state <= LINE_ID_SM_WAIT_ON_FILLER;

            -- Line ID is Valid
            else

              line_id_next_state <= LINE_ID_SM_LINE_ID_READY;

            end if;

          end if;


        -- Line ID Ready (Valid Line ID only ..)
        when LINE_ID_SM_LINE_ID_READY =>

          line_id_next_state <= LINE_ID_SM_MUX_PROGRAMMING;


        -- Do Mux Switch
        when LINE_ID_SM_MUX_PROGRAMMING =>

          if mux_switch_done_r = '0' and mux_switch_done = '1' then
            line_id_next_state <= LINE_ID_SM_READY;
          end if;


        -- "Ready to Use" state
        when LINE_ID_SM_READY =>

          if
            scan_current_state /= scan_previous_state and
            scan_current_state = SCAN_SM_READY
          then

            line_id_next_state <= LINE_ID_SM_IDLE;

          end if;


        -- "Wait on Filler" state
        when LINE_ID_SM_WAIT_ON_FILLER =>

          if count_ended = '1' then
            line_id_next_state <= LINE_ID_SM_FILLER_READY;
          end if;


        -- "Filler Ready" state
        when LINE_ID_SM_FILLER_READY =>

          if
            scan_current_state /= scan_previous_state and
            scan_current_state = SCAN_SM_READY
          then

            line_id_next_state <= LINE_ID_SM_IDLE;

          end if;


        -- Others
        when others =>

          line_id_next_state <= LINE_ID_SM_IDLE;


      end case;

    end if;

  end process fsm_combo_proc;


  -- This process encodes current state into a status register
  --
  status_proc : process (rst, clk)
  begin

    if rst = '1' then

      status_r <= C_SCAN_STATUS_IDLE;

    elsif clk'event and clk = '1' then

      case line_id_current_state is

        when LINE_ID_SM_IDLE =>
          status_r <= C_LINE_ID_STATUS_IDLE;

        when LINE_ID_SM_FETCH_LINE_ID =>
          status_r <= C_LINE_ID_STATUS_FETCH_LINE_ID;

        when LINE_ID_SM_LINE_ID_READY =>
          status_r <= C_LINE_ID_STATUS_LINE_ID_READY;

        when LINE_ID_SM_MUX_PROGRAMMING =>
          status_r <= C_LINE_ID_STATUS_MUX_PROGRAMMING;

        when LINE_ID_SM_READY =>
          status_r <= C_LINE_ID_STATUS_READY;

        when LINE_ID_SM_WAIT_ON_FILLER =>
          status_r <= C_LINE_ID_STATUS_WAIT_ON_FILLER;

        when LINE_ID_SM_FILLER_READY =>
          status_r <= C_LINE_ID_STATUS_FILLER_READY;

        when others =>
          status_r <= C_LINE_ID_STATUS_IDLE;

      end case;

    end if;

  end process status_proc;

end RTL;
------------------------------------------------------------------------------
