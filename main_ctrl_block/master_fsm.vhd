library ieee;

use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.proj_package.all;
use work.main_ctrl_block_package.all;

------------------------------------------------------------------------------
-- Entity Description
------------------------------------------------------------------------------
entity master_fsm is
  generic(
    g_watchdog_cnt_load_value_width : natural := 32;
    g_watchdog_cnt_load_value       : natural := 250000000 -- 5 sec with 50 MHz clock
  );
  port (
    rst                                 : in std_logic;
    clk                                 : in std_logic;
                            
    watchdog_wake                       : in std_logic;
                            
    security_ok                         : in std_logic;
    probe_detect_n                      : in  std_logic;
    probe_rdy                           : in std_logic;
    thermal_rdy                         : in std_logic;
    power_rdy                           : in std_logic;
    rx_afem_rdy                         : in std_logic;
                            
    thermal_error                       : in std_logic_vector(1 downto 0);
    security_error                      : in std_logic;
    power_error                         : in std_logic_vector(1 downto 0);
                            
    rx_afem_cdc_lock_err                : in std_logic_vector(1 downto 0);
    rx_afem_cdc_config_err              : in std_logic;
    rx_afem_ads_config_err              : in std_logic;
    rx_afem_vca_config_err              : in std_logic_vector(C_NB_VCAs-1 downto 0);
    rx_afem_hvm_err                     : in std_logic_vector(C_NB_HVMs-1 downto 0);
    ta_first_stage_full                 : in std_logic;
    ta_second_stage_full                : in std_logic;
    ta_third_stage_full                 : in std_logic;
    ta_fourth_stage_full                : in std_logic;
    ta_fifth_stage_full                 : in std_logic;
    ta_last_stage_full                  : in std_logic;
    ta_fifos_not_empty_flag             : in std_logic;
    ta_overflow_flag                    : in std_logic;
    pri_pll_locked                      : in std_logic;
    system_ram_offset_error             : in std_logic;
    line_id_table_empty                 : in std_logic;
    config_update_failure               : in std_logic := '0';
    pcie_param_fifo_overflow            : in std_logic := '0';
    pcie_param_fifo_c_mode_overflow     : in std_logic := '0';
    pcie_param_fifo_m_mode_overflow     : in std_logic := '0';
    pcie_param_fifo_ndl_overflow        : in std_logic := '0';
    img_pipeline_overflow_error         : in std_logic := '0';
    framer_overlap_error                : in std_logic := '0';
    cmpd_not_enough_smpls_err           : in std_logic := '0';
    ram_b_mode_overflow_err             : in std_logic := '0';
    ram_c_mode_overflow_err             : in std_logic := '0';
    ram_m_mode_overflow_err             : in std_logic := '0';
                               
    scan_current_state                  : in T_SCAN_SM_STATE_TYPE;
    flip_current_state                  : in T_FLIP_SM_STATE_TYPE;
    config_current_state                : in T_CONFIG_SM_STATE_TYPE;
    line_id_current_state               : in T_LINE_ID_SM_STATE_TYPE;
                               
    cmd_rdy                             : in std_logic;
    cmd_code                            : in T_CMD_CODE;

    -- To allow Flip only between Frames
    frame_session                       : in std_logic;
                                        
    thermal_enable                      : out std_logic;
    probe_enable                        : out std_logic;
    secure_enable                       : out std_logic;
    power_enable                        : out std_logic;
    rx_afem_enable                      : out std_logic;
    tx_afem_enable                      : out std_logic;
    scan_session                        : out std_logic;
    first_scan_line                     : out std_logic;
                                      
    current_state                       : out T_MASTER_SM_STATE_TYPE;
    status                              : out T_STATUS_CODE;
    error                               : out T_ERROR_CODE
    );

end master_fsm;

------------------------------------------------------------------------------
-- Architecture Description
------------------------------------------------------------------------------
architecture RTL of master_fsm is

  component cnt_preload_countdown
    generic (
      g_preload_word_width : natural
      );
    port (
      rst          : in  std_logic;
      clk          : in  std_logic;
      enable       : in  std_logic;
      start_count  : in  std_logic;
      load         : in  std_logic;
      preload_word : in  std_logic_vector(g_preload_word_width-1 downto 0);
      count_ended  : out std_logic
      );
  end component;

  signal master_current_state      : T_MASTER_SM_STATE_TYPE;
  signal master_next_state         : T_MASTER_SM_STATE_TYPE;
  signal scan_previous_state       : T_SCAN_SM_STATE_TYPE;
  signal status_r                  : T_STATUS_CODE;
  signal error_r                   : T_ERROR_CODE;

  signal thermal_enable_r          : std_logic;
  signal probe_enable_r            : std_logic;
  signal secure_enable_r           : std_logic;
  signal power_enable_r            : std_logic;
  signal tx_afem_enable_r          : std_logic;
  signal rx_afem_enable_r          : std_logic;
  signal scan_session_r            : std_logic;
  signal first_scan_line_r         : std_logic;

  signal watchdog_wake_r           : std_logic;
  signal watchdog_enable_r         : std_logic;
  signal watchdog_start_count_r    : std_logic;
  signal watchdog_cnt_load_value_r : std_logic_vector(C_WATCHDOG_CNT_LOAD_VALUE_WIDTH-1 downto 0);
  signal watchdog_count_ended      : std_logic;

  signal probe_detect_n_r1         : std_logic;
  signal probe_det_rst             : std_logic;  

begin

  current_state   <= master_current_state;
  status          <= status_r;
  error           <= error_r;
  first_scan_line <= first_scan_line_r;
  thermal_enable  <= thermal_enable_r;
  probe_enable    <= probe_enable_r;
  secure_enable   <= secure_enable_r;
  power_enable    <= power_enable_r;
  tx_afem_enable  <= tx_afem_enable_r;
  rx_afem_enable  <= rx_afem_enable_r;
  scan_session    <= scan_session_r;


  -- counter WATCHDOG
  cnt_preload_countdown_inst1 : cnt_preload_countdown
    generic map (
      g_preload_word_width => g_watchdog_cnt_load_value_width
      )
    port map (
      clk          => clk,
      rst          => rst,
      enable       => watchdog_enable_r,
      start_count  => watchdog_start_count_r,
      load         => watchdog_start_count_r,
      preload_word => watchdog_cnt_load_value_r,
      count_ended  => watchdog_count_ended
      );

  -- WAKE FEM WATCHDOG --
  watchdog_wake_proc : process (rst, clk)
  begin

    if rst = '1' then

      watchdog_enable_r         <= '0';
      watchdog_start_count_r    <= '0';
      watchdog_cnt_load_value_r <= (others => '0');
      watchdog_wake_r           <= '0';

    elsif clk'event and clk = '1' then

      watchdog_wake_r <= watchdog_wake;

      watchdog_cnt_load_value_r <= CONV_STD_LOGIC_VECTOR(
              g_watchdog_cnt_load_value,
              g_watchdog_cnt_load_value_width
              );

      -- WATCHDOG enabled only when FEM is scanning or in PAUSE mode.
      if
        master_current_state /= master_next_state and
        (
		  (master_next_state = MASTER_SM_SCAN) 
		  --or
		   --(master_next_state = MASTER_SM_PAUSE)
			)
      then

        watchdog_enable_r <= '1';

      elsif not ((master_current_state = MASTER_SM_SCAN) 
		--or(master_current_state = MASTER_SM_PAUSE)
		)
		then

        watchdog_enable_r <= '0';

      end if;

      -- when the FEM starts scanning start watchdog counter.
      if
        master_current_state /= master_next_state and
        master_next_state = MASTER_SM_SCAN
      then

        watchdog_start_count_r <= '1';

      -- each time we receive the command wake watchdog
      -- the counter is started.
      elsif
        master_current_state = MASTER_SM_SCAN and
        watchdog_wake_r = '0' and watchdog_wake = '1'
      then

        watchdog_start_count_r <= '1';

      else

        watchdog_start_count_r <= '0';

      end if;

    end if;

  end process watchdog_wake_proc;
  
  -- Reset of Master FSM in the moment of a probe connection
  
  reset_on_probe_det_proc: process (rst, clk)
  begin  
    if rst = '1' then
      probe_detect_n_r1 <= '0';
      probe_det_rst     <= '0';
    elsif clk'event and clk = '1' then 
      probe_detect_n_r1 <= probe_detect_n;
      probe_det_rst     <= probe_detect_n_r1 and (not probe_detect_n);
    end if;
  end process reset_on_probe_det_proc;


  -- Master FSM --

  fsm_sync_proc : process (rst, probe_det_rst, clk)
  begin

    if rst = '1' or probe_det_rst = '1' then

      master_current_state <= MASTER_SM_POWER_OFF;
      scan_previous_state  <= SCAN_SM_IDLE;

      thermal_enable_r     <= '0';
      probe_enable_r       <= '0';
      secure_enable_r      <= '0';
      power_enable_r       <= '0';
      tx_afem_enable_r     <= '0';
      rx_afem_enable_r     <= '0';
      scan_session_r       <= '0';
      first_scan_line_r    <= '0';

    elsif clk'event and clk = '1' then

      master_current_state <= master_next_state;
      scan_previous_state  <= scan_current_state;

      -- thermal_enable_r
      if master_current_state = MASTER_SM_POWER_OFF then
        thermal_enable_r <= '0';
      elsif master_current_state = MASTER_SM_ERROR then
        -- Retain its previous value !!
      else
        thermal_enable_r <= '1';
      end if;

      -- secure_enable_r
      if master_current_state = MASTER_SM_POWER_OFF then
        secure_enable_r  <= '0';
      elsif master_current_state = MASTER_SM_ERROR then
        -- Retain its previous value !!
      else
        secure_enable_r  <= '1';
      end if;

      -- probe_enable_r
      if
        master_current_state = MASTER_SM_POWER_OFF or
        master_current_state = MASTER_SM_STANDBY or
        ( master_current_state = MASTER_SM_SECURITY_CHECK and
          probe_rdy = '0' and
          power_rdy = '0' )
      then

        probe_enable_r <= '0';

      elsif master_current_state = MASTER_SM_ERROR then
        -- Retain its previous value !!
      else
        probe_enable_r <= '1';
      end if;

      -- power_enable_r
      --
      -- In case of Power Error, Power Module must be enabled
      -- in order to read the Rails Status
      --
      if master_current_state = MASTER_SM_ERROR then

        power_enable_r <= power_error(0) or power_error(1);

      -- Power On UCD during Probe ID Read Operation
      --
      elsif
        master_current_state = MASTER_SM_SECURITY_CHECK and
        probe_detect_n = '0' and
        probe_rdy = '0'
      then

        power_enable_r <= '1';

      -- SCAN Command will Switch ON the Power Module.
      --
      elsif
        master_current_state = MASTER_SM_IDLE and
        cmd_rdy = '1' and
        cmd_code = C_CMD_SCAN
      then

        power_enable_r <= '1';

--      -- Disable Power while not scanning or in pause
--      --
      elsif not ((master_current_state = MASTER_SM_SCAN) or
						(master_current_state = MASTER_SM_PAUSE)) then
        power_enable_r <= '0';
      end if;

      -- tx_afem_enable_r
      if
        ( master_current_state = MASTER_SM_IDLE or
		  master_current_state = MASTER_SM_PAUSE or
          master_current_state = MASTER_SM_SCAN ) and
        power_enable_r = '1' and
        power_rdy = '1'
      then

        tx_afem_enable_r <= '1';

      else
        tx_afem_enable_r <= '0';
      end if;

      -- rx_afem_enable_r
      if
        ( master_current_state = MASTER_SM_IDLE or
		  master_current_state = MASTER_SM_PAUSE or
          master_current_state = MASTER_SM_SCAN ) and
        power_enable_r = '1' and
        power_rdy = '1'
      then

        rx_afem_enable_r <= '1';

      else
        rx_afem_enable_r <= '0';
      end if;

      -- scan_session signal is a strobe that helps framer to distinguish
      -- between scanned data obtained as a consequence of a particular
      -- command. This is mainly introduced to reset the PCIe memory offset
      -- on every new SCAN command.
      --
      if master_current_state = MASTER_SM_SCAN then
        scan_session_r <= '1';
      else
        scan_session_r <= '0';
      end if;

      -- Test Mode is ON for Very First Scan Line only ...
      --
      if
        master_current_state /= master_next_state and
        master_next_state = MASTER_SM_SCAN
      then

        first_scan_line_r <= '1';

      elsif
        master_current_state /= MASTER_SM_SCAN or
        scan_current_state = SCAN_SM_READY
      then

        first_scan_line_r <= '0';

      end if;

    end if;

  end process fsm_sync_proc;


  fsm_combo_proc : process (
    master_current_state,
    scan_current_state,
    scan_previous_state,
    flip_current_state,
    config_current_state,
    line_id_current_state,
    cmd_rdy,
    cmd_code,
    security_ok,
    probe_rdy,
    thermal_rdy,
    power_enable_r,
    power_rdy,
    rx_afem_enable_r,
    rx_afem_rdy,
    thermal_error,
    security_error,
    power_error,
    rx_afem_cdc_lock_err,
    rx_afem_cdc_config_err,
    rx_afem_ads_config_err,
    rx_afem_vca_config_err,
    rx_afem_hvm_err,
    ta_first_stage_full,
    ta_second_stage_full,
    ta_third_stage_full,
    ta_fourth_stage_full,
    ta_fifth_stage_full,
    ta_last_stage_full,
    ta_fifos_not_empty_flag,
    ta_overflow_flag,
    pri_pll_locked,
    system_ram_offset_error,
    line_id_table_empty,
    config_update_failure,
    pcie_param_fifo_overflow,
    pcie_param_fifo_c_mode_overflow,
    pcie_param_fifo_m_mode_overflow,
    pcie_param_fifo_ndl_overflow,
    img_pipeline_overflow_error,
    framer_overlap_error,
    cmpd_not_enough_smpls_err,
    ram_b_mode_overflow_err,
    ram_c_mode_overflow_err,
    ram_m_mode_overflow_err,
    frame_session,
    watchdog_count_ended
    )
  begin

    master_next_state <= master_current_state;

    -- Prioritizing RESET command
    if
      cmd_code = C_CMD_RESET and
      cmd_rdy = '1'
    then

      master_next_state <= MASTER_SM_POWER_OFF;

      -- On Errors
    elsif
      master_current_state /= MASTER_SM_ERROR and
      ( thermal_error /= "00" or
        security_error = '1' or
        power_error /= "00" or
        rx_afem_cdc_lock_err /= "00" or
        rx_afem_cdc_config_err = '1' or
        rx_afem_ads_config_err = '1' or
        rx_afem_vca_config_err /= C_ZEROS_64BIT(C_NB_VCAs-1 downto 0) or
        rx_afem_hvm_err /= C_ZEROS_64BIT(C_NB_HVMs-1 downto 0) or
        ( master_current_state = MASTER_SM_SCAN and
          rx_afem_rdy = '0' ) or
        ta_first_stage_full = '1' or
        ta_second_stage_full = '1' or
        ta_third_stage_full = '1' or
        ta_fourth_stage_full = '1' or
        ta_fifth_stage_full = '1' or
        ta_last_stage_full = '1' or
        ta_fifos_not_empty_flag = '1' or
        ta_overflow_flag = '1' or
        pri_pll_locked = '0' or
        system_ram_offset_error = '1' or
        line_id_table_empty = '1' or
        config_update_failure = '1' or
        pcie_param_fifo_overflow = '1' or
        pcie_param_fifo_c_mode_overflow = '1' or
        pcie_param_fifo_m_mode_overflow = '1' or
        pcie_param_fifo_ndl_overflow = '1' or
        img_pipeline_overflow_error = '1' or
        framer_overlap_error = '1' or
        cmpd_not_enough_smpls_err = '1' or
        ram_b_mode_overflow_err = '1' or  
        ram_c_mode_overflow_err = '1' or
        ram_m_mode_overflow_err = '1' or
        watchdog_count_ended = '1' )
    then

      master_next_state <= MASTER_SM_ERROR;

    -- If Probe is disconnected abruptly
    --
    elsif
      master_current_state /= MASTER_SM_POWER_OFF and
      master_current_state /= MASTER_SM_SECURITY_CHECK and
      master_current_state /= MASTER_SM_ERROR and
      probe_rdy = '0'
    then

      master_next_state <= MASTER_SM_STANDBY;

    -- Failing Security Check or
    -- If Probe is not connected or
    -- If Thermal Limits are not set
    --
    elsif
      master_current_state /= MASTER_SM_POWER_OFF and
      master_current_state /= MASTER_SM_ERROR and
      ( security_ok = '0' or
        probe_rdy = '0' or
        thermal_rdy = '0' )
    then

      master_next_state <= MASTER_SM_SECURITY_CHECK;

    else

      case master_current_state is

        -- On Enable
        when MASTER_SM_POWER_OFF =>

          master_next_state <= MASTER_SM_SECURITY_CHECK;


        -- On Security Check and Probe Detect
        when MASTER_SM_SECURITY_CHECK =>

          master_next_state <= MASTER_SM_IDLE;


        when MASTER_SM_IDLE =>

          -- On Scan Command
          if
            cmd_rdy = '1' and
            cmd_code = C_CMD_SCAN and
            power_enable_r = '1' and
            power_rdy = '1' and
            rx_afem_enable_r = '1' and
            rx_afem_rdy = '1' and
            scan_current_state = SCAN_SM_IDLE and
            config_current_state = CONFIG_SM_IDLE and
            line_id_current_state = LINE_ID_SM_IDLE and
            flip_current_state = FLIP_SM_IDLE
          then

            master_next_state <= MASTER_SM_SCAN;

          end if;


        when MASTER_SM_SCAN =>

          -- Stop Scan only on end of frame
          if
            cmd_rdy = '1' and
            cmd_code = C_CMD_STOP_SCAN and
            scan_current_state /= scan_previous_state and
            scan_current_state = SCAN_SM_READY and
            frame_session = '0'
          then

            master_next_state <= MASTER_SM_IDLE;
				
			  elsif
			    cmd_rdy = '1' and
            cmd_code = C_CMD_PAUSE_SCAN and
            scan_current_state /= scan_previous_state and
            scan_current_state = SCAN_SM_READY and
            frame_session = '0'
			  then
					master_next_state <= MASTER_SM_PAUSE;

          end if;
		  when MASTER_SM_PAUSE =>
		    -- from PAUSE either go to STOP or SCAN state
			 if
            cmd_rdy = '1' and
            cmd_code = C_CMD_STOP_SCAN and	
				scan_current_state = SCAN_SM_IDLE
          then

            master_next_state <= MASTER_SM_IDLE;
				
			  elsif
            cmd_rdy = '1' and
            cmd_code = C_CMD_SCAN and
            power_enable_r = '1' and
            power_rdy = '1' and
            rx_afem_enable_r = '1' and
            rx_afem_rdy = '1' and
            scan_current_state = SCAN_SM_IDLE and
            config_current_state = CONFIG_SM_IDLE and
            line_id_current_state = LINE_ID_SM_IDLE and
            flip_current_state = FLIP_SM_IDLE
          then

            master_next_state <= MASTER_SM_SCAN;

          end if;
			

        -- On Error
        when MASTER_SM_ERROR =>


        -- On Abrupt Probe Disconnect
        when MASTER_SM_STANDBY =>


        -- Others
        when others =>

          master_next_state <= MASTER_SM_POWER_OFF;


      end case;

    end if;

  end process fsm_combo_proc;


  -- This process encodes current state into a status register
  --
  status_proc : process (rst, clk)
  begin

    if rst = '1' then

      status_r <= C_MASTER_STATUS_POWER_OFF;

    elsif clk'event and clk = '1' then

      case master_current_state is

        when MASTER_SM_POWER_OFF =>
          status_r <= C_MASTER_STATUS_POWER_OFF;

        when MASTER_SM_SECURITY_CHECK =>
          status_r <= C_MASTER_STATUS_SECURITY_CHECK;

        when MASTER_SM_IDLE =>
          status_r <= C_MASTER_STATUS_IDLE;

        when MASTER_SM_SCAN =>
          status_r <= C_MASTER_STATUS_SCAN;
		  when MASTER_SM_PAUSE =>
          status_r <= C_MASTER_STATUS_PAUSE;

        when MASTER_SM_ERROR =>
          status_r <= C_MASTER_STATUS_ERROR;

        when MASTER_SM_STANDBY =>
          status_r <= C_MASTER_STATUS_STANDBY;

        when others =>
          status_r <= C_MASTER_STATUS_POWER_OFF;

      end case;

    end if;

  end process status_proc;


  -- This process encodes error into an error register
  --
  error_proc : process (rst, clk)
  begin

    if rst = '1' then

      error_r <= C_MASTER_NO_ERROR;

    elsif clk'event and clk = '1' then

      if
        master_current_state /= master_next_state and
        master_next_state = MASTER_SM_ERROR
      then

        if thermal_error(0) = '1' then

          error_r <= C_MASTER_THERMAL_ERROR;

        elsif security_error = '1' then

          error_r <= C_MASTER_SECURITY_ERROR;

        elsif power_error(0) = '1' then

          error_r <= C_MASTER_POWER_GOOD_NEVER_OCCURED;

        elsif rx_afem_cdc_lock_err(0) = '1' then

          error_r <= C_MASTER_CDC_LOCK_NEVER_OCCURED;

        elsif rx_afem_cdc_config_err = '1' then

          error_r <= C_MASTER_CDC_CONFIG_ERROR;

        elsif rx_afem_ads_config_err = '1' then

          error_r <= C_MASTER_ADS_ERROR;

        elsif rx_afem_vca_config_err /= C_ZEROS_64BIT(C_NB_VCAs-1 downto 0) then

          error_r <= C_MASTER_VCA_ERROR;

        elsif rx_afem_hvm_err /= C_ZEROS_64BIT(C_NB_HVMs-1 downto 0) then

          error_r <= C_MASTER_HVM_ERROR;

        elsif
          master_current_state = MASTER_SM_SCAN and
          rx_afem_rdy = '0'
        then

          error_r <= C_MASTER_RX_AFEM_ERROR;

        elsif ta_first_stage_full = '1' then

          error_r <= C_MASTER_TA_FIRST_STAGE_FULL;

        elsif ta_second_stage_full = '1' then

          error_r <= C_MASTER_TA_SECOND_STAGE_FULL;

        elsif ta_third_stage_full = '1' then

          error_r <= C_MASTER_TA_THIRD_STAGE_FULL;

        elsif ta_fourth_stage_full = '1' then

          error_r <= C_MASTER_TA_FOURTH_STAGE_FULL;

        elsif ta_fifth_stage_full = '1' then

          error_r <= C_MASTER_TA_FIFTH_STAGE_FULL;

        elsif ta_last_stage_full = '1' then

          error_r <= C_MASTER_TA_LAST_STAGE_FULL;

        elsif ta_fifos_not_empty_flag = '1' then

          error_r <= C_MASTER_TA_FIFOS_NOT_EMPTY;

        elsif ta_overflow_flag = '1' then

          error_r <= C_MASTER_TA_OVERFLOW;

        elsif pri_pll_locked = '0' then

          error_r <= C_MASTER_PRI_PLL_LOCK_ERROR;

        elsif system_ram_offset_error = '1' then

          error_r <= C_MASTER_SYSTEM_RAM_OFFSET_ERROR;

        elsif line_id_table_empty = '1' then

          error_r <= C_MASTER_LINE_ID_TABLE_EMPTY;

        elsif watchdog_count_ended = '1' then

          error_r <= C_MASTER_OVERFLOW_WATCHDOG_ERROR;

        elsif thermal_error(1) = '1' then

          error_r <= C_MASTER_PULSERS_OTP_ERROR;

        elsif power_error(1) = '1' then

          error_r <= C_MASTER_POWER_GOOD_GONE_DOWN;

        elsif rx_afem_cdc_lock_err(1) = '1' then

          error_r <= C_MASTER_CDC_LOCK_GONE_DOWN;

        elsif config_update_failure = '1' then

          error_r <= C_MASTER_CONFIG_UPDATE_FAILURE;

        elsif pcie_param_fifo_overflow = '1' then

          error_r <= C_MASTER_PCIE_LINK_IS_BUSY;
          
        elsif pcie_param_fifo_c_mode_overflow = '1' then

          error_r <= C_MASTER_C_MODE_PCIE_LINK_IS_BUSY;
          
        elsif pcie_param_fifo_m_mode_overflow = '1' then

          error_r <= C_MASTER_M_MODE_PCIE_LINK_IS_BUSY;          
          
        elsif pcie_param_fifo_ndl_overflow ='1' then
          
          error_r <= C_MASTER_NDL_PCIE_LINK_IS_BUSY;

        elsif img_pipeline_overflow_error = '1' then

          error_r <= C_MASTER_IMG_PROC_MODULE_IS_BUSY;

        elsif framer_overlap_error = '1' then

          error_r <= C_MASTER_FRAMER_OVERLAP_ERROR;
         
        elsif cmpd_not_enough_smpls_err = '1' then
          
          error_r <= C_MASTER_CMPD_NOT_ENOUGH_SMPLS_ERR;

        elsif ram_b_mode_overflow_err = '1' then
            
          error_r <= C_MASTER_PCIE_RAM_B_MODE_OVERFLOW_ERR;
          
        elsif ram_c_mode_overflow_err = '1' then
        
          error_r <= C_MASTER_PCIE_RAM_C_MODE_OVERFLOW_ERR;
          
        elsif ram_m_mode_overflow_err = '1' then
        
          error_r <= C_MASTER_PCIE_RAM_M_MODE_OVERFLOW_ERR;
          
        else

          error_r <= C_MASTER_UNKNOWN_ERROR;

        end if;

        -- Soft Reset Command replaces this code
--      elsif master_current_state /= MASTER_SM_ERROR then
--
--        error_r <= C_MASTER_NO_ERROR;

      end if;

    end if;

  end process error_proc;

end RTL;
