library ieee;

use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.proj_package.all;
use work.main_ctrl_block_package.all;

------------------------------------------------------------------------------
-- Entity Description
------------------------------------------------------------------------------
entity scan_fsm is

  port (
    rst                        : in std_logic;
    clk                        : in std_logic;

    cnt_load_value             : in std_logic_vector(C_WAIT_CNT_WIDTH-1 downto 0);

    master_current_state       : in T_MASTER_SM_STATE_TYPE;
    line_id_current_state      : in T_LINE_ID_SM_STATE_TYPE;

    transmission_end           : in std_logic;
    reception_strb             : in std_logic;
    framer_strb_out            : in std_logic;
    wait_until_processing_ends : in std_logic;

    start_tx                   : out std_logic;
    start_rx                   : out std_logic;

    current_state              : out T_SCAN_SM_STATE_TYPE;
    status                     : out T_STATUS_CODE
    );

end scan_fsm;

------------------------------------------------------------------------------
-- Architecture Description
------------------------------------------------------------------------------
architecture RTL of scan_fsm is

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

  signal scan_current_state                     : T_SCAN_SM_STATE_TYPE;
  signal scan_next_state                        : T_SCAN_SM_STATE_TYPE;
  signal line_id_previous_state                 : T_LINE_ID_SM_STATE_TYPE;

  signal transmission_end_r                     : std_logic;
  signal reception_strb_r                       : std_logic;
  signal framer_strb_out_r                      : std_logic;
  signal start_tx_r                             : std_logic;
  signal start_rx_r                             : std_logic;

  signal wait_before_transmission_start_count_r : std_logic;
  signal wait_before_transmission_count_ended   : std_logic;
  signal wait_before_reception_start_count_r    : std_logic;
  signal wait_before_reception_count_ended      : std_logic;

  signal status_r                               : T_STATUS_CODE;

begin

  current_state <= scan_current_state;
  status        <= status_r;

  start_tx      <= start_tx_r;
  start_rx      <= start_rx_r;

  -- Delay between Mux Switch & Transmission
  cnt_preload_countdown_inst1 : cnt_preload_countdown
    generic map (
      g_preload_word_width => C_WAIT_BEFORE_TX_CNT_WIDTH
      )
    port map (
      clk          => clk,
      rst          => rst,
      start_count  => wait_before_transmission_start_count_r,
      load         => wait_before_transmission_start_count_r,
      preload_word => cnt_load_value(
        C_CNT_LOAD_VALUE_WAIT_BEFORE_TX_UL
        downto C_CNT_LOAD_VALUE_WAIT_BEFORE_TX_LL
        ),
      count_ended  => wait_before_transmission_count_ended
      );

  -- Delay between Transmission & Reception
  cnt_preload_countdown_inst2 : cnt_preload_countdown
    generic map (
      g_preload_word_width => C_WAIT_BEFORE_RX_CNT_WIDTH
      )
    port map (
      clk          => clk,
      rst          => rst,
      start_count  => wait_before_reception_start_count_r,
      load         => wait_before_reception_start_count_r,
      preload_word => cnt_load_value(
        C_CNT_LOAD_VALUE_WAIT_BEFORE_RX_UL
        downto C_CNT_LOAD_VALUE_WAIT_BEFORE_RX_LL
        ),
      count_ended  => wait_before_reception_count_ended
      );

  -- Scan FSM --

  fsm_sync_proc : process (rst, clk)
  begin

    if rst = '1' then

      scan_current_state     <= SCAN_SM_IDLE;
      line_id_previous_state <= LINE_ID_SM_IDLE;

      transmission_end_r   <= '1';
      reception_strb_r     <= '0';
      framer_strb_out_r    <= '0';
      start_tx_r           <= '0';
      start_rx_r           <= '0';

      wait_before_transmission_start_count_r <= '0';
      wait_before_reception_start_count_r    <= '0';

    elsif clk'event and clk = '1' then

      scan_current_state     <= scan_next_state;
      line_id_previous_state <= line_id_current_state;
      transmission_end_r     <= transmission_end;
      reception_strb_r       <= reception_strb;
      framer_strb_out_r      <= framer_strb_out;

      -- Tx & Rx control --
      --
      if scan_next_state = SCAN_SM_TRANSMISSION then
        start_tx_r <= '1';
      else
        start_tx_r <= '0';
      end if;

      if scan_next_state = SCAN_SM_RECEPTION then
        start_rx_r <= '1';
      else
        start_rx_r <= '0';
      end if;

      -- Wait States Control --
      --
      if
        scan_current_state /= scan_next_state and
        scan_next_state = SCAN_SM_WAIT_BEFORE_TRANSMISSION
      then

        wait_before_transmission_start_count_r <= '1';

      else
        wait_before_transmission_start_count_r <= '0';
      end if;

      if
        transmission_end_r = '0' and
        transmission_end = '1'
      then

        wait_before_reception_start_count_r <= '1';

      else
        wait_before_reception_start_count_r <= '0';
      end if;

    end if;

  end process fsm_sync_proc;


  fsm_combo_proc : process (
    scan_current_state,
    master_current_state,
    line_id_current_state,
    line_id_previous_state,
    wait_until_processing_ends,
    framer_strb_out,
    framer_strb_out_r,
    reception_strb,
    reception_strb_r,
    wait_before_transmission_count_ended,
    wait_before_reception_count_ended
    )
  begin

    scan_next_state <= scan_current_state;

    -- If not Scanning !!
    --
    if master_current_state /= MASTER_SM_SCAN then
      scan_next_state <= SCAN_SM_IDLE;
    else

      case scan_current_state is

        -- Idle or Ready
        -- When Line ID is set & Mux Switch is Done
        -- At the start of scan session, scan FSM starts from IDLE state
        -- and goes back to it only at end of scan session.
        -- During scan session, it goes to READY state.
        --
        when SCAN_SM_IDLE | SCAN_SM_READY =>

          if line_id_current_state /= line_id_previous_state then

            if line_id_current_state = LINE_ID_SM_READY then
              scan_next_state <= SCAN_SM_WAIT_BEFORE_TRANSMISSION;
            elsif line_id_current_state = LINE_ID_SM_WAIT_ON_FILLER then
              scan_next_state <= SCAN_SM_WAIT_ON_FILLER;
            end if;

          end if;


        -- Wait Before Transmission
        when SCAN_SM_WAIT_BEFORE_TRANSMISSION =>

          if wait_before_transmission_count_ended = '1' then
            scan_next_state <= SCAN_SM_TRANSMISSION;
          end if;


        -- Transmission
        when SCAN_SM_TRANSMISSION =>

          scan_next_state <= SCAN_SM_WAIT_BEFORE_RECEPTION;


        -- Wait Before Reception
        when SCAN_SM_WAIT_BEFORE_RECEPTION =>

          if wait_before_reception_count_ended = '1' then
            scan_next_state <= SCAN_SM_RECEPTION;
          end if;


        -- Reception
        when SCAN_SM_RECEPTION =>

          -- In case FLIP or STOP_SCAN command are waiting for the End of Frame and
          -- this Line ID is the last one in the Frame,
          -- then wait until all the blocks are processed.
          --
          if wait_until_processing_ends = '1' then

            if
              framer_strb_out_r = '1' and
              framer_strb_out   = '0'
            then

              scan_next_state <= SCAN_SM_READY;

            end if;

          else

            if
              reception_strb_r = '1' and
              reception_strb   = '0'
            then

              scan_next_state <= SCAN_SM_READY;

            end if;

          end if;


        -- Wait on Filler
        when SCAN_SM_WAIT_ON_FILLER =>

          if line_id_current_state = LINE_ID_SM_FILLER_READY then

            -- In case, (N-1)th Line ID is not a Filler and
            -- (N)th Line ID is a Filler then,
            -- as this being Last Line of the Frame, must wait until
            -- previous Line ID is fully processed !!
            --
            if wait_until_processing_ends = '1' then

              if framer_strb_out = '0' then
                scan_next_state <= SCAN_SM_READY;
              end if;

            else
              scan_next_state <= SCAN_SM_READY;
            end if;

          end if;


        -- Others
        when others =>

          scan_next_state <= SCAN_SM_IDLE;


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

      case scan_current_state is

        when SCAN_SM_IDLE =>
          status_r <= C_SCAN_STATUS_IDLE;

        when SCAN_SM_WAIT_BEFORE_TRANSMISSION =>
          status_r <= C_SCAN_STATUS_WAIT_BEFORE_TRANSMISSION;

        when SCAN_SM_TRANSMISSION =>
          status_r <= C_SCAN_STATUS_TRANSMISSION;

        when SCAN_SM_WAIT_BEFORE_RECEPTION =>
          status_r <= C_SCAN_STATUS_WAIT_BEFORE_RECEPTION;

        when SCAN_SM_RECEPTION =>
          status_r <= C_SCAN_STATUS_RECEPTION;

        when SCAN_SM_READY =>
          status_r <= C_SCAN_STATUS_READY;

        when SCAN_SM_WAIT_ON_FILLER =>
          status_r <= C_SCAN_STATUS_WAIT_ON_FILLER;

        when others =>
          status_r <= C_SCAN_STATUS_IDLE;

      end case;

    end if;

  end process status_proc;

end RTL;
