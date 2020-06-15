library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2c_tb is
	constant period : time := 10 ns;
end entity;

architecture arch of i2c_tb is
	
	component i2c is
		port(
			CLK, reset_n, enable, rw : in std_logic;
			address : in std_logic_vector(6 downto 0);
			data_write : in std_logic_vector(7 downto 0);
			data_read : out std_logic_vector(7 downto 0);
			error_acknowledge : buffer std_logic;
			sda, scl : inout std_logic
		);
	end component;
	
	signal CLK, reset_n, enable, rw, error_acknowledge, sda, scl : std_logic;
	signal address : std_logic_vector(6 downto 0);
	signal data_write, data_read : std_logic_vector(7 downto 0);
	
	begin
	
	UUT : i2c port map(CLK, reset_n, enable, rw, address, data_write, data_read, error_acknowledge, sda, scl);
	
	CLK_process : process
	begin
		clk <= '0';
		wait for period/2;
		clk <= '1';
		wait for period/2;
	end process;
	
	operation : process
	begin
		reset_n <= '0';
		enable <= '1';
		address <= "0011010";
		rw <= '0';
		data_write <= "01101000";
		
		wait for period*2;
		
		reset_n <= '1';
		
		wait for 20 us;
		
		rw <= '1';
		
		wait for period*1000000;
	end process;
	
end architecture;