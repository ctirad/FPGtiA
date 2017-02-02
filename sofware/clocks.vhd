----------------------------------------------------------------------------------
-- Engineer: Mike Field <hamster@snap.net.nz<
-- 
-- Description: Generate clocking for sending TMDS data use the OSERDES2
-- 
-- WHEN SENDING SOMETHING OTHER THAN 5 BITS AT a timeCHANGE 'DIVIDE' 
--
-- REMEMBER TO CHECK CLKIN_PERIOD ON PLL_BASE
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VComponents.all;

entity clocks is
    Port ( OSC_14M	: in  STD_LOGIC;
           OSC_29M   : out STD_LOGIC);
end clocks;

architecture Behavioral of clocks is
	signal OSC_buffered,OSC_29M_unbuffered : std_logic;
   signal clock_x1             : std_logic;
   signal clock_x1_unbuffered  : std_logic;
   signal clk_feedback         : std_logic;
   signal pll_locked           : std_logic;
begin


 DCM_SP_inst : DCM_SP
   generic map ( 
      CLKDV_DIVIDE => 2.0,    --  Divide by: 1.5,2.0,2.5,3.0,3.5,4.0,4.5,5.0,5.5,6.0,6.5
                              --     7.0,7.5,8.0,9.0,10.0,11.0,12.0,13.0,14.0,15.0 or 16.0      
      CLKFX_DIVIDE => 10,  		 --  Can be any interger from 1 to 32      
      CLKFX_MULTIPLY => 21, 		--  Can be any integer from 1 to 32      
      CLKIN_DIVIDE_BY_2 => FALSE, --  TRUE/FALSE to enable CLKIN divide by two feature       
      CLKIN_PERIOD => 70.484, 		--  Specify period of input clock      
      CLKOUT_PHASE_SHIFT => "NONE", --  Specify phase shift of "NONE", "FIXED" or "VARIABLE"      
      CLK_FEEDBACK => "2X",         --  Specify clock feedback of "NONE", "1X" or "2X"       
      DESKEW_ADJUST => "SOURCE_SYNCHRONOUS", -- "SOURCE_SYNCHRONOUS", "SYSTEM_SYNCHRONOUS" or
                                             --     an integer from 0 to 15      
      DLL_FREQUENCY_MODE => "LOW",     -- "HIGH" or "LOW" frequency mode for DLL       
      DUTY_CYCLE_CORRECTION => TRUE, --  Duty cycle correction, TRUE or FALSE       
      PHASE_SHIFT => 0,        	--  Amount of fixed phase shift from -255 to 255       
      STARTUP_WAIT => FALSE --  Delay configuration DONE until DCM_SP LOCK, TRUE/FALSE
   )
      port map (      
      CLK0 =>  open,   		-- 0 degree DCM CLK ouptput      
      CLK2X =>  clk_feedback,  -- 2X DCM CLK output      
      CLKFB => clk_feedback,  	 -- DCM clock feedback      
      CLKIN => OSC_14M, -- Clock input (from IBUFG, BUFG or DCM)
		CLKFX => OSC_29M_unbuffered,
      RST => '0'       -- DCM asynchronous reset input    
   );

SOC29M_buf: BUFG port map ( I => OSC_29M_unbuffered, O => OSC_29M);

end Behavioral;