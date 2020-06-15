library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2c is
	port(
			CLK, reset_n, enable, rw : in std_logic;
			address : in std_logic_vector(6 downto 0);
			data_write : in std_logic_vector(7 downto 0);
			data_read : out std_logic_vector(7 downto 0);
			error_acknowledge : buffer std_logic;
			sda, scl : inout std_logic
		);
end entity;

architecture arch of i2c is

	constant input_clk : integer := 50_000_000;
	constant bus_clk : integer := 400_000;
	constant divider : integer := (input_clk/bus_clk)/4;
	type saved_data is array(0 to 127) of std_logic_vector(7 downto 0);
	signal memory : saved_data;
	type proceso is (idle, start, initialize_i2c, acknowledge, write, read, address_slave_s, address_master, stop);
	signal estado : proceso;
	signal sda_clk : std_logic;
	signal sda_clk_prev : std_logic;
	signal scl_clk : std_logic;
	signal scl_enable : std_logic := '0';
	signal sda_i : std_logic := '1';
	signal sda_enable_n : std_logic;
	signal address_rw : std_logic_vector(7 downto 0);
	signal data_towrite : std_logic_vector(7 downto 0);
	signal data_toread : std_logic_vector(7 downto 0);
	signal bit_count : integer range 0 to 7 := 7;
	signal stretch : std_logic := '0';
	
	begin
	
		process(CLK, reset_n)
			variable counter : integer range 0 to divider*4;
		begin
			if reset_n = '0' then
				stretch <= '0';
				counter := 0;
			elsif (CLK'event and CLK = '1') then
				sda_clk_prev <= sda_clk;
				if (counter = divider*4-1) then
					counter := 0;
				elsif stretch = '0' then
					counter := counter + 1;
				end if;
				
				case counter is
					when 0 to divider-1 =>
						scl_clk <= '0';
						sda_clk <= '0';
					when divider to divider*2-1 =>
						scl_clk <= '0';
						sda_clk <= '1';
					when divider*2 to divider*3-1 =>
						scl_clk <= '1';
						if scl = '0' then
							stretch <= '1';
						else
							stretch <= '0';
						end if;
						sda_clk <= '1';
					when others =>
						scl_clk <= '1';
						sda_clk <= '0';
				end case;
			end if;
		end process;
		
		
		process(CLK, reset_n)
		begin
			if reset_n = '0' then
				estado <= idle;
				scl_enable <= '0';
				sda_i <= '1';
				error_acknowledge <= '0';
				bit_count <= 7;
				data_read <= "00000000";
			elsif (CLK'event and CLK = '1') then
				if (sda_clk = '1' and sda_clk_prev = '0') then
					case estado is
						when idle =>
							if enable = '1' then
								address_rw <= address & rw;
								data_towrite <= data_write;
								estado <= start;
							else
								estado <= idle;
							end if;
							
						when start =>
							sda_i <= address_rw(bit_count);
							estado <= initialize_i2c;
							
						when initialize_i2c =>
							if (bit_count = 0) then
								sda_i <= '1';
								bit_count <= 7;
								estado <= acknowledge;
							else
								bit_count <= bit_count - 1;
								sda_i <= address_rw(bit_count-1);
								estado <= initialize_i2c;
							end if;
							
						when acknowledge =>
							if (address_rw(0) = '0') then
								sda_i <= data_towrite(bit_count);
								memory(to_integer(unsigned(address)))(bit_count) <= data_towrite(bit_count);
								estado <= write;
							else
								sda_i <= '1';
								estado <= read;
							end if;
							
						when write =>
							if (bit_count = 0) then
								sda_i <= '1';
								bit_count <= 7;
								estado <= address_slave_s;
							else
								bit_count <= bit_count - 1;
								sda_i <= data_towrite(bit_count-1);
								memory(to_integer(unsigned(address)))(bit_count-1) <= data_towrite(bit_count-1);
								estado <= write;
							end if;
							
						when read =>
							if (bit_count = 0) then
								if (enable = '1' and address_rw = address & rw) then
									sda_i <= '0';
								else
									sda_i <= '1';
								end if;
								bit_count <= 7;
								data_read <= memory(to_integer(unsigned(address)));
								estado <= address_master;
							else
								bit_count <= bit_count - 1;
								estado <= read;
							end if;
						
						when address_slave_s =>
							if enable = '1' then
								address_rw <= address & rw;
								data_towrite <= data_write;
								if (address_rw = address & rw) then
									sda_i <= data_write(bit_count);
									estado <= write;
								else
									estado <= idle;
								end if;
							else
								estado <= stop;
							end if;
							
						when address_master =>
							if enable = '1' then
								address_rw <= address & rw;
								data_towrite <= data_write;
								if (address_rw = address & rw) then
									sda_i <= '1';
									estado <= read;
								else
									estado <= idle;
								end if;
							else
								estado <= stop;
							end if;
							
						when stop =>
							estado <= idle;
							
					end case;
					
				elsif (sda_clk = '0' and sda_clk_prev = '1') then
					case estado is
					
						when idle =>
							if scl_enable = '0' then
								scl_enable <= '1';
								error_acknowledge <= '0';
							end if;
							
						when acknowledge =>
							if (sda /= '0' or error_acknowledge = '1') then
								error_acknowledge <= '1';
							end if;
							
						when read =>
							data_toread(bit_count) <= sda;
							
						when address_slave_s =>
							if (sda /= '0' or error_acknowledge = '1') then
								error_acknowledge <= '1';
							end if;
						
						when stop =>
							scl_enable <= '0';
							
						when others => null;
						
					end case;
				end if;
			end if;
		end process;
		
		with estado select
			sda_enable_n <= sda_clk_prev when start,
							not sda_clk_prev when stop,
							sda_i when others;
							
		scl <= '0' when (scl_enable = '1' and scl_clk = '0') else 'Z';
		sda <= '0' when sda_enable_n = '0' else 'Z';
		
	end arch;