
library ieee;

use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

--------------------------------------------------------------------------------
-- Package Description
--------------------------------------------------------------------------------
package ezono_package is

  ------------------------------------------------------------------------------
  -- Device Dependencies
  ------------------------------------------------------------------------------
  type T_FPGA_VENDOR is (
    ALTERA,
    Other
    );

  type T_FPGA_FAMILY is (
    Stratix_GX,
    Stratix_II_GX,
    Arria_GX,
    Stratix_III,
    Other
    ); 

  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  -- Functions
  ------------------------------------------------------------------------------
  function max (
    a : std_logic_vector;
    b : std_logic_vector
    ) return std_logic_vector;

  function minimum (
    a : std_logic_vector;
    b : std_logic_vector
    ) return std_logic_vector;

  function abs_diff (
    a : std_logic_vector;
    b : std_logic_vector
    ) return std_logic_vector;

  function diff (
    a : std_logic_vector;
    b : std_logic_vector
    ) return std_logic_vector;

  function reverse (input : std_logic_vector) return std_logic_vector;
  
  function masking (
    data  : std_logic_vector;
    param : std_logic_vector(3 downto 0)
    ) return std_logic_vector;

  function truncate (
    data   : std_logic_vector;
    param1 : natural;
    param2 : natural := 0
    ) return std_logic_vector;

  function rsh (
    data  : std_logic_vector;
    param : natural := 0
    ) return std_logic_vector;

  function lsh (
    data  : std_logic_vector;
    param : natural := 0
    ) return std_logic_vector;

  function pad (
    data  : std_logic_vector;
    param : natural := 0
    ) return std_logic_vector;

  ------------------------------------------------------------------------------

end package ezono_package;
-------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Package Body Description
--------------------------------------------------------------------------------
package body ezono_package is

  ------------------------------------------------------------------------------
  -- Function : max
  ------------------------------------------------------------------------------
  function max (
    a : std_logic_vector;
    b : std_logic_vector
    ) return std_logic_vector is

  begin

    if a > b then
      return a;
    else
      return b;
    end if;

  end;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  -- Function : minimum
  ------------------------------------------------------------------------------
  function minimum (
    a : std_logic_vector;
    b : std_logic_vector
    ) return std_logic_vector is

  begin

    if a < b then
      return a;
    else
      return b;
    end if;

  end;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  -- Function : abs_diff
  ------------------------------------------------------------------------------
  function abs_diff (
    a : std_logic_vector;
    b : std_logic_vector
    ) return std_logic_vector is

  begin

    if a > b then
      return (a - b);
    else
      return (b - a);
    end if;

  end;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  -- Function : diff
  ------------------------------------------------------------------------------
  function diff (
    a : std_logic_vector;
    b : std_logic_vector
    ) return std_logic_vector is

    variable output_v : std_logic_vector(a'range);
    
  begin

    if a > b then
      output_v := (a - b);
    else
      output_v := (others => '0');
    end if;

    return output_v;

  end;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  -- Function : reverse
  ------------------------------------------------------------------------------
  function reverse (input : std_logic_vector)
    return std_logic_vector is

    variable output_v : std_logic_vector(input'range);

  begin

    for i in input'range loop
      output_v(input'high - (i - input'low)) := input(i);
    end loop;

    return output_v;

  end;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  -- Function : masking
  ------------------------------------------------------------------------------
  function masking (
    data  : std_logic_vector;
    param : std_logic_vector(3 downto 0)
    ) return std_logic_vector is

    variable data_v : std_logic_vector(data'length-1 downto 0);
    
  begin

    -- 0%
    if param = x"0" then
      
      data_v := (others => '0');

    -- 12.5%
    elsif param = x"1" then
      
      data_v := ("000" & data(data'length-1 downto 3));

    -- 25%
    elsif param = x"2" then
      
      data_v := ("00" & data(data'length-1 downto 2));

    -- 37.5%
    elsif param = x"3" then
      
      data_v := ("00" & data(data'length-1 downto 2)) +
                ("000" & data(data'length-1 downto 3));

    -- 50%
    elsif param = x"4" then
      
      data_v := ('0' & data(data'length-1 downto 1));

    -- 62.5%
    elsif param = x"5" then
      
      data_v := ('0' & data(data'length-1 downto 1)) +
                ("000" & data(data'length-1 downto 3));

    -- 75%
    elsif param = x"6" then
      
      data_v := ('0' & data(data'length-1 downto 1)) +
                ("00" & data(data'length-1 downto 2));

    -- 87.5%
    elsif param = x"7" then
      
      data_v := ('0' & data(data'length-1 downto 1)) +
                ("00" & data(data'length-1 downto 2)) +
                ("000" & data(data'length-1 downto 3));

    -- 100%
    else
      
      data_v := data;
      
    end if;

    return data_v;
    
  end;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  -- Function : truncate
  ------------------------------------------------------------------------------
  function truncate (
    data   : std_logic_vector;
    param1 : natural;
    param2 : natural := 0
    ) return std_logic_vector is

    variable data_v        : std_logic_vector(data'length-1 downto 0);
    variable upper_limit_v : std_logic_vector(data'length-1 downto 0);
    variable zeros_v       : std_logic_vector(data'length-1 downto 0);
    variable ones_v        : std_logic_vector(param1-1 downto 0);

  begin
    
    zeros_v := (others => '0');
    ones_v  := (others => '1');

    -- Ignoring LSB Bits
    data_v := zeros_v + data(data'length-1 downto param2);

    -- Evaluating Upper Limit
    upper_limit_v := zeros_v + ones_v;

    -- Truncate
    if data_v > upper_limit_v then
      return upper_limit_v(param1-1 downto 0);
    else
      return data_v(param1-1 downto 0);
    end if;

  end;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  -- Function : rsh
  ------------------------------------------------------------------------------
  function rsh (
    data  : std_logic_vector;
    param : natural := 0
    ) return std_logic_vector is

    variable data_v  : std_logic_vector(data'length-1 downto 0);
    variable zeros_v : std_logic_vector(data'length-1 downto 0);

  begin
    
    zeros_v := (others => '0');

    -- Right Shift
    data_v := zeros_v + data(data'length-1 downto param);

    return data_v;

  end;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  -- Function : lsh
  ------------------------------------------------------------------------------
  function lsh (
    data  : std_logic_vector;
    param : natural := 0
    ) return std_logic_vector is

    variable data_v  : std_logic_vector(param+data'length-1 downto 0);
    variable zeros_v : std_logic_vector(param+data'length-1 downto 0);

  begin
    
    zeros_v := (others => '0');

    -- Left Shift
    if param > 0 then
      data_v := zeros_v + (data & zeros_v(param-1 downto 0));
    else
      data_v := zeros_v + data;
    end if;

    return data_v;

  end;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  -- Function : pad
  ------------------------------------------------------------------------------
  function pad (
    data  : std_logic_vector;
    param : natural := 0
    ) return std_logic_vector is

    variable data_v  : std_logic_vector(param+data'length-1 downto 0);
    variable zeros_v : std_logic_vector(param+data'length-1 downto 0);

  begin
    
    zeros_v := (others => '0');

    -- Padding
    data_v := zeros_v + data;

    return data_v;

  end;
  ------------------------------------------------------------------------------

end package body ezono_package;
-------------------------------------------------------------------------------
