library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library UNISIM;
use UNISIM.VComponents.all; 
use work.myarray_384x8.all;

entity vga_out is
Port ( 
	pixel_clock : in std_logic;
	test_pattern : in std_logic;
	scanline_mode : in std_logic_vector(1 downto 0);
	odd_scanline : in std_logic;
			  
-- input linebuffer 
	line_even : in array_384x8;
	line_odd	: in array_384x8;
			  
	gtia_vsync : in std_logic;
	hsync_trigger : in std_logic;

	red_p   : out STD_LOGIC_VECTOR (7 downto 0) := (others => '0');
   green_p : out STD_LOGIC_VECTOR (7 downto 0) := (others => '0');
   blue_p  : out STD_LOGIC_VECTOR (7 downto 0) := (others => '0');
	
	
	video_en : out STD_LOGIC := '1';
   hsync   	: out STD_LOGIC := '0';
   vsync   	: out STD_LOGIC := '0'
);
end vga_out;

architecture Behavioral of vga_out is
 
-- standardni 576p: 
--"768x576@50" 29.5 768 789 858 944 576 581 586 625 -hsync -vsync

--   constant h_rez        : natural := 768;
--   constant h_sync_start : natural := 789;
--   constant h_sync_end   : natural := 858;
--   constant h_max        : natural := 944;
--   signal   h_count      : unsigned(11 downto 0) := (others => '0');
--
--   constant v_rez        : natural := 576;
--   constant v_sync_start : natural := 581;
--   constant v_sync_end   : natural := 586;
--   constant v_max        : natural := 625;
  
  
--  ATARI: 50Hz/15.625kHz	
  
 -- 4xATARI timing: 
						
 
   constant h_rez        : natural := 752;
   constant h_sync_start : natural := 776; 
   constant h_sync_end   : natural := 840;
   constant h_max        : natural := 912;
   
   constant v_rez        : natural := 576;
   constant v_sync_start : natural := 581;
   constant v_sync_end   : natural := 586;
   constant v_max        : natural := 625;
  
	signal   h_count      : unsigned(9 downto 0) := (others => '0');
   signal   v_count      : unsigned(9 downto 0) := (others => '0');
	
  	signal atari_color 	: std_logic_vector(7 downto 0) := (others => '0');
	signal gtia_vsync_last : std_logic;
	signal hsync_trigger_last : std_logic;

COMPONENT gtia_palette
PORT(
ATARI_COLOUR : IN STD_LOGIC_VECTOR(7 downto 0);
	PAL : IN STD_LOGIC;
	
	R_next : OUT STD_LOGIC_VECTOR(7 downto 0);
	G_next : OUT STD_LOGIC_VECTOR(7 downto 0);
	B_next : OUT STD_LOGIC_VECTOR(7 downto 0)
);
END COMPONENT;

begin

process(pixel_clock)
begin
	if rising_edge(pixel_clock) then
		if h_count < h_rez and v_count < v_rez then
			if ( test_pattern = '1' ) then
				atari_color(7 downto 4) <= std_logic_vector(h_count(7 downto 4));
				atari_color(3 downto 0) <= std_logic_vector(v_count(7 downto 4));
			else	
				case scanline_mode is
					when "00" => -- standard line doubling
						if (odd_scanline = '1') then
							atari_color <= line_even(to_integer(h_count)/2);
						else 
							atari_color <= line_odd(to_integer(h_count)/2);
						end if;
					when "01" => --black lines
						if v_count(0) = '0' then --normal line
							if (odd_scanline = '1') then
								atari_color <= line_even(to_integer(h_count)/2);
							else 
								atari_color <= line_odd(to_integer(h_count)/2);
							end if;
						else	
							atari_color <= "00000000"; -- black line
						end if;
					when "10" => --half bright scanlines
						if v_count(0) = '0' then --normal line
							if (odd_scanline = '1') then
								atari_color <= line_even(to_integer(h_count)/2);
							else 
								atari_color <= line_odd(to_integer(h_count)/2);
							end if;
						else 
							if (odd_scanline = '1') then
								atari_color <= line_even(to_integer(h_count)/2)(7 downto 4) & '0' & line_even(to_integer(h_count)/2)(2 downto 0);
							else 
								atari_color <= line_odd(to_integer(h_count)/2)(7 downto 4) & '0' & line_odd(to_integer(h_count)/2)(2 downto 0);
							end if;
						end if;
					when others =>
				end case;			
				video_en <= '1';	
			end if;	
		else
			atari_color <= (others => '0');
			video_en <= '0';
      end if;

      if h_count >= h_sync_start and h_count < h_sync_end then
			hsync <= '0';
      else
         hsync <= '1';
      end if;
         
      if (v_count >= v_sync_start and v_count < v_sync_end) then
         vsync <= '0';
		else
         vsync <= '1';
      end if;
         
      if h_count = h_max or (hsync_trigger = '1' and hsync_trigger_last = '0' ) then
			h_count <= (others => '0');
			--h_count <= 128;
			hsync_trigger_last <= hsync_trigger;
         if (v_count = v_max) then 
				v_count <= (others => '0');
				gtia_vsync_last <= gtia_vsync;
			elsif ( gtia_vsync = '1' and gtia_vsync_last = '0')  then
            --v_count <= "1001000101"; --581 vsync_start
				v_count <= "0000000000";
				gtia_vsync_last <= gtia_vsync;
         else
				v_count <= v_count+1;
				gtia_vsync_last <= gtia_vsync;
         end if;
		else
			hsync_trigger_last <= hsync_trigger;
         h_count <= h_count+1;
      end if;
	end if;
end process;
	
palette: gtia_palette 
port map (
	PAL=>'1', 
	ATARI_COLOUR=>atari_color, 
	R_next=>red_p, 
	G_next=>green_p, 
	B_next=>blue_p	
);

end Behavioral;
