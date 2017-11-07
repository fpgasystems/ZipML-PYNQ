library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity hybrid_dot_product is
generic (
	LOG2_MAX_DIMENSION : integer := 8;
	LOG2_VECTOR_SIZE : integer := 6);
port (
	clk : in std_logic;
	resetn : in std_logic;

	accumulation_count : in std_logic_vector(LOG2_MAX_DIMENSION-1 downto 0);

	trigger : in std_logic;
	vector1 : in std_logic_vector(32*(2**LOG2_VECTOR_SIZE)-1 downto 0);
	vector2 : in std_logic_vector(32*(2**LOG2_VECTOR_SIZE)-1 downto 0);

	result_valid_last : out std_logic;
	result_valid : out std_logic;
	result : out std_logic_vector(31 downto 0));
end hybrid_dot_product;

architecture behavioral of hybrid_dot_product is

constant VECTOR_SIZE : integer := 2**LOG2_VECTOR_SIZE;

signal accumulation_count_internal : unsigned(LOG2_MAX_DIMENSION-1 downto 0);

signal fp_mult_result_valid : std_logic;
signal fp_mult_result : std_logic_vector(32*VECTOR_SIZE-1 downto 0);

signal fixed_mult_result_valid : std_logic;
signal fixed_mult_result : std_logic_vector(32*VECTOR_SIZE-1 downto 0);

signal adder_tree_result_valid : std_logic;
signal adder_tree_result : std_logic_vector(31 downto 0);

signal internal_accumulation_count : integer;
signal accumulation : signed(31 downto 0);

signal valid_pulse_counter : integer;

signal internal_result_valid_last : std_logic;
signal internal_result_valid : std_logic;
signal internal_result : signed(31 downto 0);

component xlnx_dec23_to_float_conv
port (
	aclk : IN STD_LOGIC;
    s_axis_a_tvalid : IN STD_LOGIC;
    s_axis_a_tlast : IN STD_LOGIC;
    s_axis_a_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    m_axis_result_tvalid : OUT STD_LOGIC;
    m_axis_result_tlast : OUT STD_LOGIC;
    m_axis_result_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0));
end component;

component fp_vector_mult
generic (VECTOR_SIZE : integer := 16);
port (
	clk : in std_logic;

	trigger : in std_logic;
	vector1 : in std_logic_vector(32*VECTOR_SIZE-1 downto 0);
	vector2 : in std_logic_vector(32*VECTOR_SIZE-1 downto 0);

	result_valid : out std_logic;
	result : out std_logic_vector(32*VECTOR_SIZE-1 downto 0));
end component;

component fixed_adder_tree
generic (LOG2_VECTOR_SIZE : integer := 4);
port (
	clk : in std_logic;

	trigger : in std_logic;
	vector : in std_logic_vector(32*2**LOG2_VECTOR_SIZE-1 downto 0);

	result_valid : out std_logic;
	result : out std_logic_vector(31 downto 0));
end component;

function convert_float_to_int9_23(fp : std_logic_vector(31 downto 0)) return std_logic_vector is
variable exponent : unsigned(7 downto 0);
variable mantissa : unsigned(22 downto 0);
variable temp : unsigned(31 downto 0);
variable result : signed(31 downto 0);
begin
	exponent := unsigned(fp(30 downto 23));
	mantissa := unsigned(fp(22 downto 0));
	temp := X"00" & '1' & mantissa;
	if exponent >= 127 then
		temp := shift_left(temp, to_integer(exponent-127));
	else
		temp := shift_right(temp, to_integer(127-exponent));
	end if;
	result := signed(std_logic_vector(temp));
	if fp(31) = '1' then
		result := -result;
	end if;
	return std_logic_vector(result);
end function;

begin

vector_mult: fp_vector_mult
generic map (
	VECTOR_SIZE => VECTOR_SIZE)
port map (
	clk => clk,

	trigger => trigger,
	vector1 => vector1,
	vector2 => vector2,

	result_valid => fp_mult_result_valid,
	result => fp_mult_result);

adder_tree: fixed_adder_tree
generic map (
	LOG2_VECTOR_SIZE => LOG2_VECTOR_SIZE)
port map (
	clk => clk,

	trigger => fixed_mult_result_valid,
	vector => fixed_mult_result,

	result_valid => adder_tree_result_valid,
	result => adder_tree_result);

fp_converter: xlnx_dec23_to_float_conv
port map (
	aclk => clk,
	s_axis_a_tlast => internal_result_valid_last,
	s_axis_a_tvalid => internal_result_valid,
	s_axis_a_tdata => std_logic_vector(internal_result),
	m_axis_result_tlast => result_valid_last,
	m_axis_result_tvalid => result_valid,
	m_axis_result_tdata => result);


accumulation_count_internal <= unsigned(accumulation_count);
process(clk)
begin
if clk'event and clk = '1' then
	fixed_mult_result_valid <= fp_mult_result_valid;
	for k in 0 to VECTOR_SIZE-1 loop
		fixed_mult_result(32*k+31 downto 32*k) <= convert_float_to_int9_23(fp_mult_result(32*k+31 downto 32*k));
	end loop;

	if resetn = '0' then
		internal_accumulation_count <= 0;
		accumulation <= (others => '0');
		valid_pulse_counter <= 0;

		internal_result_valid_last <= '0';
		internal_result_valid <= '0';
		internal_result <= (others => '0');
	else

		internal_result_valid_last <= '0';
		internal_result_valid <= '0';
		if adder_tree_result_valid = '1' then
			if internal_accumulation_count = accumulation_count_internal-1 then
				internal_accumulation_count <= 0;
				internal_result_valid <= '1';
				internal_result <= accumulation + signed(adder_tree_result);
				accumulation <= (others => '0');
			else
				internal_accumulation_count <= internal_accumulation_count + 1;
				accumulation <= accumulation + signed(adder_tree_result);
			end if;
		end if;

		if internal_result_valid = '1' or valid_pulse_counter > 0 then
			if valid_pulse_counter = accumulation_count_internal-1 then
				internal_result_valid <= '0';
				valid_pulse_counter <= 0;
			else
				if valid_pulse_counter = accumulation_count_internal-2 then
					internal_result_valid_last <= '1';
				end if;
				internal_result_valid <= '1';
				valid_pulse_counter <= valid_pulse_counter + 1;
			end if;
		end if;

	end if;
end if;
end process;

end architecture;