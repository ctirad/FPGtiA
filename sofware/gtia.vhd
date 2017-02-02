----------------------------------------------------------------------------------
-- Create Date:    22:25:33 11/24/2015 
-- Design Name: 
-- Module Name:    gtia - Behavioral 
--
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
library UNISIM;
use UNISIM.vcomponents.all;

package myarray_384x8 is
	type 	array_384x8	is array (383 downto 0) of std_logic_vector(7 downto 0);
end package myarray_384x8;

-------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
library UNISIM;
use UNISIM.vcomponents.all;
use work.myarray_384x8.all;

entity gtia is
PORT(   
	--CLK50	: in std_logic;
	CLK32 : in std_logic;
	--OSC_14M : in std_logic;
	
--GTIA iface:
	ADDR 	: in std_logic_vector(4 downto 0); -- address BUS
	DATA 	: in std_logic_vector(7 downto 0); --data BUS
	AN	  	: in std_logic_vector(2 downto 0); --AN2-AN0 from ANTIC
	RW_n	: in std_logic;
	CS_n	: in std_logic;
	HALT_n: in std_logic;
		
	O2		: in std_logic;	--PHI2 clock 1,79MHz
	OSC	: in std_logic;	--3,58MHz atari color clock
		
--OUTPUTS:		
	OUT_14M : out std_logic; --14,neco MHz to ATARI
				
--VGA out:		
	--VGA Sync Signals (Outputs)
	VGA_HSYNC,
	VGA_VSYNC 	: OUT STD_LOGIC;
		
	--VGA Color Signals (Outputs)
	VGA_RED, 
	VGA_GREEN,
	VGA_BLUE 	: OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
		
--DVI/HDMI OUT
	TMDS_out_P : out  STD_LOGIC_VECTOR(3 downto 0);
	TMDS_out_N : out  STD_LOGIC_VECTOR(3 downto 0);	-- 3 are clocks	 
		
-- SWITCH
	SW	: in std_logic_vector(3 downto 0);		
		
-- AUX outputs		
	AUX0	: out std_logic;
	AUX1	: out std_logic;
	AUX2	: out std_logic;
	AUX3	: out std_logic;
	LEDS	: out std_logic_vector(7 downto 0)
);
end gtia;

architecture Behavioral of gtia is

type  array_4x8   is array (0 to 3) of std_logic_vector (7 downto 0);

-- GTIA:
signal hposp : array_4x8; --horizontal position of the players
signal hposm : array_4x8; --horizontal postion of the missiles
signal sizep : array_4x8; --size of the players
signal grafp : array_4x8; --graphic of the players

signal colpm : array_4x8; --color missiles
signal colpf : array_4x8; --color playfields
signal colbk :	std_logic_vector(7 downto 0);

signal sizem : std_logic_vector(7 downto 0); 
signal grafm : std_logic_vector(7 downto 0);

signal prior : std_logic_vector(7 downto 0);
signal vdelay : std_logic_vector(7 downto 0);
signal gractl : std_logic_vector(7 downto 0);

signal line_even : array_384x8 := (others => (others => '0'));
signal line_odd : array_384x8 := (others => (others => '0'));

-- collisions:
signal hitclr : std_logic_vector(7 downto 0); --clear collision registers below 
--signal mnpf : array_4x8; --missile to playfield collisions
--signal pnpf : array_4x8; --player to playfield collisions
--signal mnpl : array_4x8; --missile to player collisions
--signal pnpl : array_4x8; --player to player collisions

--signal pal : std_logic_vector(7 downto 0);

-- pomocne registry:
signal	OSC_29M	: std_logic; --master VGA/HDMI pixel clock
signal 	CLK_14M	: std_logic;

signal 	CLK_14M_counter : std_logic_vector(4 downto 0) := "00000";

signal 	color_clock: std_logic;
signal 	color_counter : std_logic_vector(7 downto 0) := "00000000";
signal	O2_buffered : std_logic;
--signal 	color_reset : std_logic := '0';

signal	gtia_vsync : std_logic;
signal 	gtia_hblank : std_logic;
signal 	gtia_hblank_last : std_logic;
signal	hsync_trigger: std_logic;

signal	mode_40char : std_logic;
signal 	vsync_last: std_logic;
signal 	video_en : std_logic;
signal	odd_scanline : std_logic;

--signal temp,temp2 : std_logic_vector(7 downto 0);  
signal gtia_pix : std_logic_vector(1 downto 0);
signal pix_previous, pix_next : std_logic_vector(7 downto 0);
signal gtia_clock: std_logic := '0';
signal neco: std_logic := '0';

--Counter/VGA Timing
	--Sync Signals
signal hsync, vsync	:	STD_LOGIC;
			--Color Signals
signal red_signal, red_p,
		 green_signal, green_p,
		 blue_signal, blue_p	: STD_LOGIC_VECTOR(7 DOWNTO 0);
			--Sync Counters
signal h_cnt : STD_LOGIC_VECTOR(9 DOWNTO 0);
signal dma_enable: std_logic := '0';
signal dma_counter: std_logic_vector(2 downto 0) := "000";

signal player_active: std_logic_vector(3 downto 0) := "0000";
signal missile_active: std_logic_vector(3 downto 0) := "0000";

signal PixelClk		: std_logic;
signal PixelClk2     : std_logic;
signal PixelClk10  	: std_logic;
signal SerDesStrobe  : std_logic;

---- COMPONENTS -----

--component pmg is
--PORT( 
--	CLK : IN STD_LOGIC;
--	RESET_N : in std_logic;
--		
--	COLOUR_ENABLE : IN STD_LOGIC;
--	LIVE_POSITION : in std_logic_vector(7 downto 0);   -- counter ticks as display is drawn
--	PLAYER_POSITION : in std_logic_vector(7 downto 0); -- requested position
--	SIZE : in std_logic_vector(1 downto 0);
--	bitmap : in std_logic_vector(7 downto 0);
--		
--	output : out std_logic
--);
--END component;

--PLL_BASE_inst : PLL_BASE
--generic map (
--	BANDWIDTH => "OPTIMIZED", -- "HIGH", "LOW" or "OPTIMIZED" 
--	CLKFBOUT_MULT => 1, -- Multiply value for all CLKOUT clock outputs (1-64)
--	CLKFBOUT_PHASE => 90.0, -- Phase offset in degrees of the clock feedback output
--	-- (0.0-360.0).
--	CLKIN_PERIOD => 0.0, -- Input clock period in ns to ps resolution (i.e. 33.333 is 30
---- MHz).
---- CLKOUT0_DIVIDE - CLKOUT5_DIVIDE: Divide amount for CLKOUT# clock output (1-128)
--CLKOUT0_DIVIDE => 1,
--CLKOUT1_DIVIDE => 1,
--CLKOUT2_DIVIDE => 1,
--CLKOUT3_DIVIDE => 1,
--CLKOUT4_DIVIDE => 1,
--CLKOUT5_DIVIDE => 1,
---- CLKOUT0_DUTY_CYCLE - CLKOUT5_DUTY_CYCLE: Duty cycle for CLKOUT# clock output (0.01-0.99).
--CLKOUT0_DUTY_CYCLE => 0.5,
--CLKOUT1_DUTY_CYCLE => 0.5,
--CLKOUT2_DUTY_CYCLE => 0.5,
--CLKOUT3_DUTY_CYCLE => 0.5,
--CLKOUT4_DUTY_CYCLE => 0.5,
--CLKOUT5_DUTY_CYCLE => 0.5,
---- CLKOUT0_PHASE - CLKOUT5_PHASE: Output phase relationship for CLKOUT# clock output (-360.0-360.0).
--CLKOUT0_PHASE => 0.0,
--CLKOUT1_PHASE => 0.0,
--CLKOUT2_PHASE => 0.0,
--CLKOUT3_PHASE => 0.0,
--CLKOUT4_PHASE => 0.0,
--CLKOUT5_PHASE => 0.0,
--CLK_FEEDBACK => "CLKFBOUT", -- Clock source to drive CLKFBIN ("CLKFBOUT" or "CLKOUT0")
--COMPENSATION => "SYSTEM_SYNCHRONOUS", -- "SYSTEM_SYNCHRONOUS", "SOURCE_SYNCHRONOUS", "EXTERNAL" 
--DIVCLK_DIVIDE => 1, -- Division value for all output clocks (1-52)
--REF_JITTER => 0.1, -- Reference Clock Jitter in UI (0.000-0.999).
--RESET_ON_LOSS_OF_LOCK => FALSE -- Must be set to FALSE
--)
--port map (
--CLKFBOUT => CLKFBOUT, -- 1-bit output: PLL_BASE feedback output
---- CLKOUT0 - CLKOUT5: 1-bit (each) output: Clock outputs
--CLKOUT0 => CLKOUT0,
--CLKOUT1 => CLKOUT1,
--CLKOUT2 => CLKOUT2,
--CLKOUT3 => CLKOUT3,
--CLKOUT4 => CLKOUT4,
--CLKOUT5 => CLKOUT5,
--LOCKED => LOCKED, -- 1-bit output: PLL_BASE lock status output
--CLKFBIN => CLKFBIN, -- 1-bit input: Feedback clock input
--CLKIN => CLKIN, -- 1-bit input: Clock input
--RST => RST -- 1-bit input: Reset input
--);
---- End of PLL_BASE_inst instantiation



--- VGA out ---
component vga_out is
Port ( 
	pixel_clock		: in std_logic;
	test_pattern	: in std_logic;
	scanline_mode	: in std_logic_vector(1 downto 0);
	odd_scanline 	: in std_logic;
	
	line_even 	: in array_384x8;
	line_odd		: in array_384x8;
	
	gtia_vsync 	: in std_logic;
	hsync_trigger : in std_logic;

   red_p  	: out STD_LOGIC_VECTOR (7 downto 0); 
   green_P 	: out STD_LOGIC_VECTOR (7 downto 0); 
   blue_P  	: out STD_LOGIC_VECTOR (7 downto 0); 
   
	video_en	: out STD_LOGIC;
   hsync		: out STD_LOGIC; 
   vsync   	: out STD_LOGIC 
);
end component;

---- DVI/HDMI out ---

component dvi_out is
Port (
	PixelClk: in std_logic;
	PixelClk2: in std_logic;
   PixelClk10: in std_logic;
	SerDesStrobe: in std_logic;
	Red: in std_logic_vector(7 downto 0);
   Green: in std_logic_vector(7 downto 0);
   Blue: in std_logic_vector(7 downto 0);
	HSync: in std_logic;
	VSync: in std_logic;
	VideoEnable: in std_logic;
	TMDS_out_P:	out std_logic_vector(3 downto 0);
	TMDS_out_N: out std_logic_vector(3 downto 0)
);
end component;

component clock is
Port (
  CLK32: in std_logic;
  --CLK_14M: out std_logic;
  PixelClk: out std_logic;
  PixelClk2: out std_logic;
  PixelClk10: out std_logic;
  SerDesStrobe: out std_logic
);
end component;

-------------------- BEGIN -----------------------
begin

BUFG_o2 : BUFG port map ( I => O2, O => O2_buffered );
BUFG_OSC : BUFG port map ( I => OSC, O => color_clock );

--process ( PixelClk10 )
----- 14M out generation ---
--begin
--	if rising_edge(PixelClk10) then
--		if (CLK_14M_counter = "01001") then
--			CLK_14M <= '1';
--		elsif ( CLK_14M_counter = "10100" ) then 
--			CLK_14M <= '0';
--			CLK_14M_counter <= "00000";
--		else 
--			CLK_14M_counter <= CLK_14M_counter + 1;
--		end if;
--	end if;
--end process;

process (PixelClk)
begin
	if rising_edge(PixelClk) then
		CLK_14M <= not CLK_14M;
	end if;
end process;

--- GTIA DMA kick on ---
dma_start: process( HALT_n, gtia_hblank )
begin
	if (falling_edge(HALT_n)) then
		if (gtia_hblank = '1') then
			dma_enable <= '1';
		else 
			dma_enable <= '0';
		end if;
	end if;	
end process;

--- GTIA BUS iface ---
bus_access: process ( O2_buffered, CS_n, RW_n )

variable dma_enable_last: std_logic:= '0';

begin
	if (falling_edge(O2_buffered)) then
		if (dma_enable = '1') and (dma_enable_last = '0') then
			dma_counter <= "000"; 
			dma_enable_last := dma_enable;
		elsif (dma_enable = '1') and (dma_counter < "111") then 
			dma_counter <= dma_counter + 1;
			dma_enable_last := dma_enable;		
		else 
			dma_enable_last := dma_enable;
		end if;
		--DMA nepotebuje nastaveny /CS ani /RW?
		if (dma_counter = "011") then 
			grafp(0) <= DATA; 		
		elsif ( dma_counter = "100") then
			grafp(1) <= DATA; 	
		elsif ( dma_counter = "101") then
			grafp(2) <= DATA; 	
		elsif ( dma_counter = "110") then
			grafp(3) <= DATA; 	
		elsif ( dma_counter = "001") then
			grafm <= DATA; 	
	
		elsif (RW_n = '0') and (CS_n = '0') then
			case ADDR is
				when "00000" => hposp(0) <= DATA;
				when "00001" => hposp(1) <= DATA; 
				when "00010" => hposp(2) <= DATA; 
				when "00011" => hposp(3) <= DATA; 
				
				when "00100" => hposm(0) <= DATA;
				when "00101" => hposm(1) <= DATA; 
				when "00110" => hposm(2) <= DATA; 
				when "00111" => hposm(3) <= DATA; 
				
				when "01000" => sizep(0) <= DATA;
				when "01001" => sizep(1) <= DATA; 
				when "01010" => sizep(2) <= DATA; 
				when "01011" => sizep(3) <= DATA; 
				
				when "01100" => sizem <= DATA;
		
				when "01101" => grafp(0) <= DATA;
				when "01110" => grafp(1) <= DATA; 
				when "01111" => grafp(2) <= DATA; 
				when "10000" => grafp(3) <= DATA;
				
				when "10001" => grafm <= DATA;
				
				when "10010" => colpm(0) <= DATA; 
				when "10011" => colpm(1) <= DATA; 
				when "10100" => colpm(2) <= DATA;
				when "10101" => colpm(3) <= DATA;
		
				when "10110" => colpf(0) <= DATA; 
				when "10111" => colpf(1) <= DATA; 
				when "11000" => colpf(2) <= DATA;
				when "11001" => colpf(3) <= DATA;
			
				when "11010" => colbk <= DATA;
				
				when "11011" => prior <= DATA; 
				when "11100" => vdelay <= DATA; 
				when "11101" => gractl <= DATA;
				when "11110" => hitclr <= DATA;
				when others =>			
			end case;
			
		end if;
	end if;
end process;

--- ANx BUS ---
AN_decoding: process (color_clock, AN) 

variable temp,temp2 : std_logic_vector(7 downto 0);
--variable ccount : integer range 0 to 227 := 0;
 
begin 
	if falling_edge(color_clock) then
	case AN is 
		when "000" =>
			gtia_vsync <= '1'; 
			gtia_hblank <= '0';	
			temp := colbk;
			temp2 := colbk;
		when "001" => -- set vsync
			gtia_vsync <= '0';
			gtia_hblank <= '0';	-- hblank i behem vsync?
			temp := "00000000";
			temp2 := "00000000";
		when "010" =>  --set hblank and clear 40char mode  
			gtia_vsync <= '1';
			gtia_hblank <= '1'; 
			mode_40char <= '0';
			temp := "00000000";
			temp2 := "00000000";
		when "011" => -- set hblank and set 40char mode 
			gtia_vsync <= '1';
			gtia_hblank <= '1';			
			mode_40char <= '1'; 
			temp := "00000000";
			temp2 := "00000000";
		when "100" | "101" | "110" | "111" =>
			gtia_vsync <= '1'; 
			gtia_hblank <= '0';	
			if ( prior(7 downto 6) = "01" ) then -- graphics 9
				if (color_counter(0) = '1' ) then  
					temp := colbk(7 downto 4) & gtia_pix & AN(1 downto 0); --fixme
					pix_previous <= colbk(7 downto 4) & gtia_pix & AN(1 downto 0); 
				else 	
					gtia_pix <= AN(1 downto 0);
					temp := pix_previous;
				end if;	
			elsif (prior(7 downto 6) = "10" ) then --graphics 10
				if (color_counter(0) = '0' ) then  				
					gtia_pix <= AN(1 downto 0);
					pix_previous <= pix_next;
					temp := pix_next;
				else 	
					case (gtia_pix & AN(1 downto 0)) is
						when "0000" => pix_next <= colpm(0);
						when "0001"	=> pix_next <= colpm(1);
						when "0010" => pix_next <= colpm(2);
						when "0011" => pix_next <= colpm(3);
					
						when "0100" | x"C" => pix_next <= colpf(0);
						when "0101" | x"D" => pix_next <= colpf(1);
						when "0110" | x"E" => pix_next <= colpf(2);
						when "0111" | x"F" => pix_next <= colpf(3);
						
						when others => pix_next <= colbk;
					end case;
					temp := pix_previous;
				end if;	
			elsif (prior(7 downto 6) = "11" ) then --graphics 11
				if (color_counter(0) = '1' ) then
					if (gtia_pix & AN(1 downto 0) = "0000") then
						temp := COLBK(7 downto 4) & "0000";
						pix_previous <= COLBK(7 downto 4) & "0000";
					else 
						temp := (COLBK(7 downto 4) or (gtia_pix & AN(1 downto 0))) & COLBK(3 downto 0);
						pix_previous <= (COLBK(7 downto 4) or (gtia_pix & AN(1 downto 0))) & COLBK(3 downto 0);
					end if;	
				else 
					gtia_pix <= AN(1 downto 0);
					temp := pix_previous;
				end if;	
			elsif ( mode_40char = '1' and prior(7) = '0' and prior(6)='0' ) then -- standard 40pix modes
				if (AN(1) = '0' ) then
					temp := colpf(2)(7 downto 4) & colpf(2)(3 downto 0);
				else 
					temp := colpf(2)(7 downto 4) & colpf(1)(3 downto 0);	
				end if;
				
				if (AN(0) = '0') then
					temp2 := colpf(2)(7 downto 4) & colpf(2)(3 downto 0);
				else 
					temp2 := colpf(2)(7 downto 4) & colpf(1)(3 downto 0);	
				end if;
			else	-- standard modes
				case AN(1 downto 0) is
					when "00" => temp := colpf(0);
					when "01" => temp := colpf(1);
					when "10" => temp := colpf(2);
					when "11" => temp := colpf(3);
					when others => temp := colbk;
				end case;
			end if;
			when others =>
		end case;
		
--		if ( player_active(0) = '1' ) then
--			temp <= colpm(0);
--		elsif ( player_active(1) = '1' ) then
--			temp <= colpm(1);
--		elsif ( player_active(2) = '1' ) then
--			temp <= colpm(2);
--		elsif ( player_active(3) = '1' ) then
--			temp <= colpm(3);
--		elsif ( missile_active(0) = '1' or missile_active(1) = '1' or missile_active(2) = '1' or missile_active(3) = '1' ) then
--			temp <= colpm(3);
--		end if;	
		if ( color_counter = 0 or color_counter = 127 or color_counter = 255 ) then
			temp := x"FF";
			temp2 := x"FF";
		end if;
		
		if ( odd_scanline = '1') then --licha linka 
			if  (mode_40char = '1' and prior(7) = '0' and prior(6)='0') then
				line_odd(conv_integer(color_counter)*2-68) <= temp;
				line_odd(conv_integer(color_counter)*2-67) <= temp2;
			else 
				line_odd(conv_integer(color_counter)*2-68) <= temp;
				line_odd(conv_integer(color_counter)*2-67) <= temp;	
			end if;
		else 
			if ( mode_40char = '1' and prior(7) = '0' and prior(6)='0')	then
				line_even(conv_integer(color_counter)*2-68) <= temp;
				line_even(conv_integer(color_counter)*2-67) <= temp2;
			else
				line_even(conv_integer(color_counter)*2-68) <= temp;
				line_even(conv_integer(color_counter)*2-67) <= temp;
			end if;	
		end if;
		
		if (gtia_hblank = '0' and gtia_hblank_last = '1') then
			color_counter <= "00100000";
			gtia_hblank_last <= gtia_hblank;
			hsync_trigger <= '1';
			gtia_pix <= "00";
			pix_previous <= "00000000";
			pix_next <= "00000000";
			odd_scanline <= not odd_scanline;
		else 
			hsync_trigger <= '0';
			color_counter <= color_counter + 1;
			gtia_hblank_last <= gtia_hblank;
		end if;		
end if;	
end process;

-- PMG mapping --
--player0 : pmg
--	port map(
--		clk=>O2_buffered,reset_n=>'1',colour_enable=>color_clock,
--		live_position=>color_counter,player_position=>hposp(0),
--		size=>sizep(0)(1 downto 0),bitmap=>grafp(0), output=>player_active(0)
--	);	
--	
--player1 : pmg
--	port map(
--		clk=>O2_buffered,reset_n=>'1',colour_enable=>color_clock,
--		live_position=>color_counter,player_position=>hposp(1),
--		size=>sizep(1)(1 downto 0),bitmap=>grafp(1), output=>player_active(1)
--	);	
--	
--player2 : pmg
--	port map(
--		clk=>O2_buffered,reset_n=>'1',colour_enable=>color_clock,
--		live_position=>color_counter,player_position=>hposp(2),
--		size=>sizep(2)(1 downto 0),bitmap=>grafp(2), output=>player_active(2)
--	);	
--	
--player3 : pmg
--	port map(
--		clk=>O2_buffered,reset_n=>'1',colour_enable=>color_clock,
--		live_position=>color_counter,player_position=>hposp(3),
--		size=>sizep(3)(1 downto 0),bitmap=>grafp(3), output=>player_active(3)
--	);	

---	grafm_reg10_extended <= grafm_reg(1 downto 0)&"000000";
----	grafm_reg32_extended <= grafm_reg(3 downto 2)&"000000";
----	grafm_reg54_extended <= grafm_reg(5 downto 4)&"000000";
----	grafm_reg76_extended <= grafm_reg(7 downto 6)&"000000";
--
--missile0 :  pmg
--	port map(
--	clk=>O2_buffered,reset_n=>'1',colour_enable=>'1',
--	live_position=>color_counter,player_position=>hposm(0),
--	size=>sizem(1 downto 0),bitmap=>grafm(1 downto 0)&"000000", output=>missile_active(0)
--	);
--
--missile1 :  pmg
--	port map(
--	clk=>O2_buffered,reset_n=>'1',colour_enable=>'1',
--	live_position=>color_counter,player_position=>hposm(1),
--	size=>sizem(3 downto 2),bitmap=>grafm(3 downto 2)&"000000", output=>missile_active(1)
--	);
--	
--missile2 :  pmg
--	port map(
--	clk=>O2_buffered,reset_n=>'1',colour_enable=>'1',
--	live_position=>color_counter,player_position=>hposm(2),
--	size=>sizem(5 downto 4),bitmap=>grafm(5 downto 4)&"000000", output=>missile_active(2)
--	);
--
--missile3 :  pmg
--	port map(
--	clk=>O2_buffered,reset_n=>'1',colour_enable=>'1',
--	live_position=>color_counter,player_position=>hposm(3),
--	size=>sizem(7 downto 6),bitmap=>grafm(7 downto 6)&"000000", output=>missile_active(3)
--	);

--- VGA ----
Vga_gen: vga_out 
PORT MAP(
		pixel_clock	=> PixelClk, 
		line_even	=> line_even,
		line_odd		=> line_odd,		
		
		red_p       => red_p,
		green_p     => green_p,
		blue_p      => blue_p,
		video_en    => video_en,
		
		hsync       => hsync,
		vsync       => vsync,
		
		hsync_trigger	=> hsync_trigger,
		gtia_vsync	=> gtia_vsync,
		
		test_pattern => SW(0),
		scanline_mode => SW(2 downto 1),
		
		odd_scanline => odd_scanline
	);

VGA_RED	<= red_p(7 downto 5) and (video_en & video_en & video_en);
VGA_GREEN <= green_p(7 downto 5) and (video_en & video_en & video_en);
VGA_BLUE	<= blue_p(7 downto 5) and (video_en & video_en & video_en);

VGA_VSYNC <= vsync;
VGA_HSYNC <= hsync;

--- DVI/HDMI related ---
dvid_clock: clock 
port map(
	CLK32 => CLK32,
	--CLK_14M => CLK_14M,
	PixelClk	=> PixelClk, 
	PixelClk2 => PixelClk2,
	PixelClk10 => PixelClk10,		
	SerDesStrobe => SerDesStrobe
);

DVI_D: dvi_out 
port map(
	PixelClk => PixelClk,
	PixelClk2 => PixelClk2,
   PixelClk10 => PixelClk10,
	SerDesStrobe => SerDesStrobe,
	Red => red_p,
   Green => green_p,
   Blue =>  blue_p,
	HSync => hsync,
	VSync => vsync,
	VideoEnable => video_en,
	TMDS_out_P => TMDS_Out_P,
	TMDS_out_N => TMDS_Out_N
);

--- AUX outputs ---
AUX0 <= gtia_hblank;
AUX1 <= hsync;
AUX2 <= odd_scanline;
AUX3 <= gtia_vsync;
--    ODDR2: Output Double Data Rate Output Register with Set, Reset
--           and Clock Enable. 
--           Spartan-6
--    Xilinx HDL Language Template, version 14.7
 
ODDR2_inst : ODDR2
   generic map(
      DDR_ALIGNMENT => "NONE", -- Sets output alignment to "NONE", "C0", "C1" 
      INIT => '0', -- Sets initial state of the Q output to '0' or '1'
      SRTYPE => "SYNC") -- Specifies "SYNC" or "ASYNC" set/reset
   port map (
      Q => OUT_14M, 			-- 1-bit output data
      C0 => CLK_14M, 		-- 1-bit clock input
      C1 => not(CLK_14M), 	-- 1-bit clock input
      CE => '1',  -- 1-bit clock enable input
      D0 => '1',   -- 1-bit data input (associated with C0)
      D1 => '0',   -- 1-bit data input (associated with C1)
      R => '0',    -- 1-bit reset input
      S => '0'     -- 1-bit set input
   );
 
	   -- End of ODDR2_inst instantiation

LEDS(0) <= mode_40char;
LEDS(1) <= prior(6);
LEDS(2) <= prior(7);
LEDS(3) <= '0';

LEDS(7) <= '0'; 
LEDS(6 downto 4) <= ( others => '0'); 

end Behavioral;