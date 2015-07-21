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
entity main_ctrl_block is

  generic (
    g_vendor : T_FPGA_VENDOR := ALTERA;
    g_family : T_FPGA_FAMILY := Stratix_II_GX
    );

  port (
    rst                                : in  std_logic;
    clk                                : in  std_logic;
                               
    cnt_load_value                     : in  std_logic_vector(C_WAIT_CNT_WIDTH-1 downto 0);
                               
    cmd_valid                          : in  std_logic;
    cmd_in                             : in  T_CMD_REG;
                               
    security_ok                        : in  std_logic;
    probe_detect_n                     : in  std_logic;
    probe_rdy                          : in  std_logic;
    thermal_rdy                        : in  std_logic;
    power_rdy                          : in  std_logic;
    rx_afem_rdy                        : in  std_logic;
                               
    thermal_error                      : in  std_logic_vector(1 downto 0);
    security_error                     : in  std_logic;
    power_error                        : in  std_logic_vector(1 downto 0);
    rx_afem_cdc_lock_err               : in  std_logic_vector(1 downto 0);
    rx_afem_cdc_config_err             : in  std_logic;
    rx_afem_ads_config_err             : in  std_logic;
    rx_afem_vca_config_err             : in  std_logic_vector(C_NB_VCAs-1 downto 0);
    rx_afem_hvm_err                    : in  std_logic_vector(C_NB_HVMs-1 downto 0);
    ta_first_stage_full                : in  std_logic;
    ta_second_stage_full               : in  std_logic;
    ta_third_stage_full                : in  std_logic;
    ta_fourth_stage_full               : in  std_logic;
    ta_fifth_stage_full                : in  std_logic;
    ta_last_stage_full                 : in  std_logic;
    ta_fifos_not_empty_flag            : in  std_logic;
    ta_overflow_flag                   : in  std_logic;
    pri_pll_locked                     : in  std_logic;
    system_ram_offset_error            : in  std_logic;
    line_id_table_empty                : in  std_logic;
    config_update_failure              : in  std_logic := '0';
    pcie_param_fifo_overflow           : in  std_logic := '0';
    pcie_param_fifo_c_mode_overflow    : in  std_logic := '0';
    pcie_param_fifo_m_mode_overflow    : in  std_logic := '0';
    pcie_param_fifo_ndl_overflow       : in  std_logic := '0';    
    img_pipeline_overflow_error        : in  std_logic := '0';
    framer_overlap_error               : in  std_logic := '0';
    cmpd_not_enough_smpls_err          : in  std_logic := '0';
    ram_b_mode_overflow_err            : in  std_logic := '0';
    ram_c_mode_overflow_err            : in  std_logic := '0';
    ram_m_mode_overflow_err            : in  std_logic := '0';
                                       
    frame_session                      : in  std_logic;
    line_id_in                         : in  std_logic_vector(C_LINE_ID_WIDTH-1 downto 0);
    line_id_rdy_in                     : in  std_logic;
                                 
    mux_switch_done                    : in  std_logic;
    analog_conf_done                   : in  std_logic_vector(C_NB_ANALOG_CONFS-1 downto 0);
                                       
    transmission_end                   : in  std_logic;
    reception_strb                     : in  std_logic;
    framer_strb_out                    : in  std_logic;
    
    pmndt_config_wr                    : in  std_logic;
                                 
    cmd_valid_ndt                      : out std_logic;
    cmd_ndt                            : out T_CMD_REG;
                                       
    thermal_enable                     : out std_logic;
    probe_enable                       : out std_logic;
    secure_enable                      : out std_logic;
    power_enable                       : out std_logic;
    rx_afem_enable                     : out std_logic;
    tx_afem_enable                     : out std_logic;
                                       
    line_id_rd                         : out std_logic;
    new_line                           : out std_logic;
                                       
    load_focus_params                  : out std_logic;
                                       
    do_mux_switch                      : out std_logic;
    analog_conf                        : out std_logic_vector(C_NB_ANALOG_CONFS-1 downto 0);
                                       
    start_tx                           : out std_logic;
    start_rx                           : out std_logic;
                                       
    line_id_out                  : out std_logic_vector(C_LINE_ID_WIDTH-1 downto 0);
    config_id                    : out std_logic_vector(C_CONFIG_ID_WIDTH-1 downto 0);

    flip                         : out std_logic;
    scan_session                 : out std_logic;
    rst_out                      : out std_logic;
    test_mode                    : out std_logic;
  
    status                       : out T_STATUS_REG;

    last_processed_cmd           : out T_CMD_REG;
    
    pmndt_config_done            : out std_logic
    );

end main_ctrl_block;

------------------------------------------------------------------------------
-- Architecture Description
------------------------------------------------------------------------------
architecture RTL of main_ctrl_block is

  component cmd_ctrl_fsm
    generic(
      g_vendor : T_FPGA_VENDOR;
      g_family : T_FPGA_FAMILY
      );
    port (
      rst                        : in  std_logic;
      clk                        : in  std_logic;
      cmd_valid                  : in  std_logic;
      cmd_in                     : in  T_CMD_REG;
      master_current_state       : in  T_MASTER_SM_STATE_TYPE;
      scan_current_state         : in  T_SCAN_SM_STATE_TYPE;
      flip_current_state         : in  T_FLIP_SM_STATE_TYPE;
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
  end component;
  
  signal cmd_valid_ndt_r : std_logic;

  component flip_fsm
    generic (
      g_config_id_width : natural := 12
      );
    port (
      rst                   : in  std_logic;
      clk                   : in  std_logic;
      master_current_state  : in  T_MASTER_SM_STATE_TYPE;
      scan_current_state    : in  T_SCAN_SM_STATE_TYPE;
      config_current_state  : in  T_CONFIG_SM_STATE_TYPE;
      cmd_rdy               : in  std_logic;
      cmd_code              : in  T_CMD_CODE;
      cmd_data              : in  T_CMD_DATA;
      frame_session         : in  std_logic;
      flip                  : out std_logic;
      config_id             : out std_logic_vector(g_config_id_width-1 downto 0);
      current_state         : out T_FLIP_SM_STATE_TYPE;
      status                : out T_STATUS_CODE
      );
  end component;

  component config_fsm
    port (
      rst                   : in  std_logic;
      clk                   : in  std_logic;
      master_current_state  : in  T_MASTER_SM_STATE_TYPE;
      scan_current_state    : in  T_SCAN_SM_STATE_TYPE;
      line_id_current_state : in  T_LINE_ID_SM_STATE_TYPE;
      analog_conf_done      : in  std_logic_vector(C_NB_ANALOG_CONFS-1 downto 0);
      analog_conf           : out std_logic_vector(C_NB_ANALOG_CONFS-1 downto 0);
      current_state         : out T_CONFIG_SM_STATE_TYPE;
      status                : out T_STATUS_CODE
      );
  end component;

  component line_id_fsm
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
      do_mux_switch        : out std_logic;
      load_focus_params    : out std_logic;
      line_id_out          : out std_logic_vector(C_LINE_ID_WIDTH-1 downto 0);
      current_state        : out T_LINE_ID_SM_STATE_TYPE;
      status               : out T_STATUS_CODE
      );
  end component;

  component scan_fsm
    port (
      rst                        : in  std_logic;
      clk                        : in  std_logic;
      cnt_load_value             : in  std_logic_vector(C_WAIT_CNT_WIDTH-1 downto 0);
      master_current_state       : in  T_MASTER_SM_STATE_TYPE;
      line_id_current_state      : in  T_LINE_ID_SM_STATE_TYPE;
      transmission_end           : in  std_logic;
      reception_strb             : in  std_logic;
      framer_strb_out            : in  std_logic;
      wait_until_processing_ends : in  std_logic;
      start_tx                   : out std_logic;
      start_rx                   : out std_logic;
      current_state              : out T_SCAN_SM_STATE_TYPE;
      status                     : out T_STATUS_CODE
      );
  end component;

  component master_fsm
    generic (
      g_watchdog_cnt_load_value_width : natural;
      g_watchdog_cnt_load_value       : natural
      );
    port (
      rst                               : in  std_logic;
      clk                               : in  std_logic;
      watchdog_wake                     : in  std_logic;
      security_ok                       : in  std_logic;
      probe_detect_n                    : in  std_logic;
      probe_rdy                         : in  std_logic;
      thermal_rdy                       : in  std_logic;
      power_rdy                         : in  std_logic;
      rx_afem_rdy                       : in  std_logic;
      thermal_error                     : in  std_logic_vector(1 downto 0);
      security_error                    : in  std_logic;
      power_error                       : in  std_logic_vector(1 downto 0);
      rx_afem_cdc_lock_err              : in  std_logic_vector(1 downto 0);
      rx_afem_cdc_config_err            : in  std_logic;
      rx_afem_ads_config_err            : in  std_logic;
      rx_afem_vca_config_err            : in  std_logic_vector(C_NB_VCAs-1 downto 0);
      rx_afem_hvm_err                   : in  std_logic_vector(C_NB_HVMs-1 downto 0);
      ta_first_stage_full               : in  std_logic;
      ta_second_stage_full              : in  std_logic;
      ta_third_stage_full               : in  std_logic;
      ta_fourth_stage_full              : in  std_logic;
      ta_fifth_stage_full               : in  std_logic;
      ta_last_stage_full                : in  std_logic;
      ta_fifos_not_empty_flag           : in  std_logic;
      ta_overflow_flag                  : in  std_logic;
      pri_pll_locked                    : in  std_logic;
      system_ram_offset_error           : in  std_logic;
      line_id_table_empty               : in  std_logic;
      config_update_failure             : in std_logic;
      pcie_param_fifo_overflow          : in std_logic;
      pcie_param_fifo_c_mode_overflow   : in std_logic;
      pcie_param_fifo_m_mode_overflow   : in std_logic;
      pcie_param_fifo_ndl_overflow      : in std_logic;
      img_pipeline_overflow_error       : in std_logic;
      framer_overlap_error              : in std_logic;
      cmpd_not_enough_smpls_err         : in std_logic;
      ram_b_mode_overflow_err           : in  std_logic;
      ram_c_mode_overflow_err           : in  std_logic;
      ram_m_mode_overflow_err           : in  std_logic;
      scan_current_state                : in  T_SCAN_SM_STATE_TYPE;
      flip_current_state                : in  T_FLIP_SM_STATE_TYPE;
      config_current_state              : in  T_CONFIG_SM_STATE_TYPE;
      line_id_current_state             : in  T_LINE_ID_SM_STATE_TYPE;
      cmd_rdy                           : in  std_logic;
      cmd_code                          : in  T_CMD_CODE;
      frame_session                     : in  std_logic;
      thermal_enable                    : out std_logic;
      probe_enable                      : out std_logic;
      secure_enable                     : out std_logic;
      power_enable                      : out std_logic;
      rx_afem_enable                    : out std_logic;
      tx_afem_enable                    : out std_logic;
      scan_session                      : out std_logic;
      first_scan_line                   : out std_logic;
      current_state                     : out T_MASTER_SM_STATE_TYPE;
      error                             : out T_ERROR_CODE
      );
  end component;

  signal flip_current_state         : T_FLIP_SM_STATE_TYPE;
  signal config_current_state       : T_CONFIG_SM_STATE_TYPE;
  signal line_id_current_state      : T_LINE_ID_SM_STATE_TYPE;
  signal scan_current_state         : T_SCAN_SM_STATE_TYPE;
  signal master_current_state       : T_MASTER_SM_STATE_TYPE;

  signal master_error               : T_ERROR_CODE;

  signal cmd_rdy                    : std_logic;
  signal cmd_code                   : T_CMD_CODE;
  signal cmd_data                   : T_CMD_DATA;

  signal wait_until_processing_ends : std_logic;
  signal first_scan_line            : std_logic;

  signal watchdog_wake              : std_logic;
  
  signal pmndt_config_wr_r          : std_logic;
  signal pmndt_config_wr_r1         : std_logic;
  signal pmndt_config_wr_r2         : std_logic;  
  signal pmndt_config_done_r        : std_logic;

begin


  test_mode <= first_scan_line;
  
  cmd_valid_ndt <= cmd_valid_ndt_r;
  
  pmndt_config_done <= pmndt_config_done_r;
  
  pmndt_config_done_flag_proc: process (rst, clk)
  begin
    if rst = '1' then
      pmndt_config_done_r <= '0';
      pmndt_config_wr_r   <= '0';
      pmndt_config_wr_r1  <= '0';
      pmndt_config_wr_r2  <= '0';      
    elsif rising_edge(clk) then
      pmndt_config_wr_r  <= pmndt_config_wr;
      pmndt_config_wr_r1 <= pmndt_config_wr_r;
      pmndt_config_wr_r2 <= pmndt_config_wr_r1;     
      
      if ((not pmndt_config_wr_r1) and pmndt_config_wr_r2) = '1' then
        pmndt_config_done_r <= '1';
      elsif cmd_valid_ndt_r = '1' or power_rdy = '0' then
        pmndt_config_done_r <= '0';
      end if;
    end if;
  end process pmndt_config_done_flag_proc;

  cmd_ctrl_fsm_inst1 : cmd_ctrl_fsm
    generic map (
      g_vendor => g_vendor,
      g_family => g_family
      )
    port map (
      rst                        => rst,
      clk                        => clk,
      cmd_valid                  => cmd_valid,
      cmd_in                     => cmd_in,
      master_current_state       => master_current_state,
      scan_current_state         => scan_current_state,
      flip_current_state         => flip_current_state,
      frame_session              => frame_session,
      wait_until_processing_ends => wait_until_processing_ends,
      rst_out                    => rst_out,
      watchdog_wake              => watchdog_wake,
      cmd_valid_ndt              => cmd_valid_ndt_r,
      cmd_ndt                    => cmd_ndt,
      cmd_rdy                    => cmd_rdy,
      cmd_code                   => cmd_code,
      cmd_data                   => cmd_data,
      last_processed_cmd         => last_processed_cmd
      );


  flip_fsm_inst1 : flip_fsm
    generic map (
      g_config_id_width => C_CONFIG_ID_WIDTH
      )
    port map (
      rst                   => rst,
      clk                   => clk,
      master_current_state  => master_current_state,
      scan_current_state    => scan_current_state,
      config_current_state  => config_current_state,
      cmd_rdy               => cmd_rdy,
      cmd_code              => cmd_code,
      cmd_data              => cmd_data,
      frame_session         => frame_session,
      flip                  => flip,
      config_id             => config_id,
      current_state         => flip_current_state,
      status                => flip_status
      );


  config_fsm_inst1 : config_fsm
    port map (
      rst                   => rst,
      clk                   => clk,
      master_current_state  => master_current_state,
      scan_current_state    => scan_current_state,
      line_id_current_state => line_id_current_state,
      analog_conf_done      => analog_conf_done,
      analog_conf           => analog_conf,
      current_state         => config_current_state,
      status                => config_status
      );


  line_id_fsm_inst1 : line_id_fsm
    port map (
      rst                  => rst,
      clk                  => clk,
      master_current_state => master_current_state,
      scan_current_state   => scan_current_state,
      flip_current_state   => flip_current_state,
      config_current_state => config_current_state,
      line_id_in           => line_id_in,
      line_id_rdy_in       => line_id_rdy_in,
      mux_switch_done      => mux_switch_done,
      line_id_rd           => line_id_rd,
      new_line             => new_line,
      do_mux_switch        => do_mux_switch,
      load_focus_params    => load_focus_params,
      line_id_out          => line_id_out,
      current_state        => line_id_current_state,
      status               => line_id_status
      );


  scan_fsm_inst1 : scan_fsm
    port map (
      rst                        => rst,
      clk                        => clk,
      cnt_load_value             => cnt_load_value,
      master_current_state       => master_current_state,
      line_id_current_state      => line_id_current_state,
      transmission_end           => transmission_end,
      reception_strb             => reception_strb,
      framer_strb_out            => framer_strb_out,
      wait_until_processing_ends => wait_until_processing_ends,
      start_tx                   => start_tx,
      start_rx                   => start_rx,
      current_state              => scan_current_state,
      status                     => scan_status
      );


  master_fsm_inst1 : master_fsm
    generic map (
      g_watchdog_cnt_load_value_width     => C_WATCHDOG_CNT_LOAD_VALUE_WIDTH,
      g_watchdog_cnt_load_value            => C_WATCHDOG_CNT_LOAD_VALUE
      )
    port map (
      rst                                  => rst,
      clk                                  => clk,
      watchdog_wake                        => watchdog_wake,
      security_ok                          => security_ok,
      probe_detect_n                       => probe_detect_n,
      probe_rdy                            => probe_rdy,
      thermal_rdy                          => thermal_rdy,
      power_rdy                            => power_rdy,
      rx_afem_rdy                          => rx_afem_rdy,
      thermal_error                        => thermal_error,
      security_error                       => security_error,
      power_error                          => power_error,
      rx_afem_cdc_lock_err                 => rx_afem_cdc_lock_err,
      rx_afem_cdc_config_err               => rx_afem_cdc_config_err,
      rx_afem_ads_config_err               => rx_afem_ads_config_err,
      rx_afem_vca_config_err               => rx_afem_vca_config_err,
      rx_afem_hvm_err                      => rx_afem_hvm_err,
      ta_first_stage_full                  => ta_first_stage_full,
      ta_second_stage_full                 => ta_second_stage_full,
      ta_third_stage_full                  => ta_third_stage_full,
      ta_fourth_stage_full                 => ta_fourth_stage_full,
      ta_fifth_stage_full                  => ta_fifth_stage_full,
      ta_last_stage_full                   => ta_last_stage_full,
      ta_fifos_not_empty_flag              => ta_fifos_not_empty_flag,
      ta_overflow_flag                     => ta_overflow_flag,
      pri_pll_locked                       => pri_pll_locked,
      system_ram_offset_error              => system_ram_offset_error,
      line_id_table_empty                  => line_id_table_empty,
      config_update_failure                => config_update_failure,
      pcie_param_fifo_overflow             => pcie_param_fifo_overflow,
      pcie_param_fifo_c_mode_overflow      => pcie_param_fifo_c_mode_overflow,
      pcie_param_fifo_m_mode_overflow      => pcie_param_fifo_m_mode_overflow,
      pcie_param_fifo_ndl_overflow         => pcie_param_fifo_ndl_overflow,
      img_pipeline_overflow_error          => img_pipeline_overflow_error,
      framer_overlap_error                 => framer_overlap_error,
      cmpd_not_enough_smpls_err            => cmpd_not_enough_smpls_err,
      ram_b_mode_overflow_err              => ram_b_mode_overflow_err,
      ram_c_mode_overflow_err              => ram_c_mode_overflow_err,
      ram_m_mode_overflow_err              => ram_m_mode_overflow_err,
      scan_current_state                   => scan_current_state,
      flip_current_state                   => flip_current_state,
      config_current_state                 => config_current_state,
      line_id_current_state                => line_id_current_state,
      cmd_rdy                              => cmd_rdy,
      cmd_code                             => cmd_code,
      frame_session                        => frame_session,
      thermal_enable                       => thermal_enable,
      probe_enable                         => probe_enable,
      secure_enable                        => secure_enable,
      power_enable                         => power_enable,
      rx_afem_enable                       => rx_afem_enable,
      tx_afem_enable                       => tx_afem_enable,
      scan_session                         => scan_session,
      first_scan_line                      => first_scan_line,
      current_state                        => master_current_state,
      status                               => master_status,
      error                                => master_error
      );


end RTL;
