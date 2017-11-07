library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dual_port_ram is
generic (
	DATA_WIDTH : natural := 8;
	ADDR_WIDTH : natural := 6);
port  (
	clk		: in std_logic;
	raddr	: in std_logic_vector(ADDR_WIDTH-1 downto 0);
	waddr	: in std_logic_vector(ADDR_WIDTH-1 downto 0);
	data	: in std_logic_vector((DATA_WIDTH-1) downto 0);
	we		: in std_logic := '1';
	q		: out std_logic_vector((DATA_WIDTH -1) downto 0));
end dual_port_ram;

architecture rtl of dual_port_ram is

-- Build a 2-D array type for the RAM
subtype word_t is std_logic_vector((DATA_WIDTH-1) downto 0);
type memory_t is array(2**ADDR_WIDTH-1 downto 0) of word_t;

-- Declare the RAM signal.	
signal ram : memory_t;

signal integer_raddr : integer range 0 to 2**ADDR_WIDTH-1;
signal integer_waddr : integer range 0 to 2**ADDR_WIDTH-1;

begin

integer_raddr <= to_integer(unsigned(raddr));
integer_waddr <= to_integer(unsigned(waddr));

process(clk)
begin
if(rising_edge(clk)) then 
	if(we = '1') then
		ram(integer_waddr) <= data;
	end if;

	-- On a read during a write to the same address, the read will
	-- return the OLD data at the address
	q <= ram(integer_raddr);
end if;
end process;

end rtl;
