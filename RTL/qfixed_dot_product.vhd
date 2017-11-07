library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity qfixed_dot_product is
generic (
	LOG2_MAX_DIMENSION : integer := 8;
	LOG2_VECTOR_SIZE : integer := 6;
	QUANTIZATION_BITS : integer := 1);
port (
	clk : in std_logic;
	resetn : in std_logic;

	accumulation_count : in std_logic_vector(LOG2_MAX_DIMENSION-1 downto 0);
	normalized_to_minus1_1 : in std_logic;

	trigger : in std_logic;
	vector1 : in std_logic_vector(QUANTIZATION_BITS*(2**LOG2_VECTOR_SIZE)-1 downto 0);
	vector2 : in std_logic_vector(32*(2**LOG2_VECTOR_SIZE)-1 downto 0);

	result_valid_last : out std_logic;
	result_valid : out std_logic;
	result : out std_logic_vector(31 downto 0));
end qfixed_dot_product;

architecture behavioral of qfixed_dot_product is

constant VECTOR_SIZE : integer := 2**LOG2_VECTOR_SIZE;

signal accumulation_count_internal : unsigned(LOG2_MAX_DIMENSION-1 downto 0);

signal fp_mult_result_valid : std_logic;
signal fp_mult_result_valid_1d : std_logic;
signal temp_mult_result : std_logic_vector(40*(2**LOG2_VECTOR_SIZE)-1 downto 0);
signal fp_mult_result : std_logic_vector(32*(2**LOG2_VECTOR_SIZE)-1 downto 0);

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

component fixed_adder_tree
generic (LOG2_VECTOR_SIZE : integer := 4);
port (
	clk : in std_logic;

	trigger : in std_logic;
	vector : in std_logic_vector(32*2**LOG2_VECTOR_SIZE-1 downto 0);

	result_valid : out std_logic;
	result : out std_logic_vector(31 downto 0));
end component;

begin

adder_tree: fixed_adder_tree
generic map (
	LOG2_VECTOR_SIZE => LOG2_VECTOR_SIZE)
port map (
	clk => clk,

	trigger => fp_mult_result_valid_1d,
	vector => fp_mult_result,

	result_valid => adder_tree_result_valid,
	result => adder_tree_result);

GEN_adder_tree_Q1: if QUANTIZATION_BITS = 1 generate
	process(clk)
	begin
	if clk'event and clk = '1' then
		for k in 0 to VECTOR_SIZE-1 loop
			if vector1(k) = '0' then
				temp_mult_result(32*k+31 downto 32*k) <= (others => '0');
			else
				temp_mult_result(32*k+31 downto 32*k) <= std_logic_vector( signed(vector2(32*k+31 downto 32*k)) );
			end if;
			fp_mult_result(32*k+31 downto 32*k) <= temp_mult_result(32*k+31 downto 32*k);
		end loop;
	end if;
	end process;
end generate GEN_adder_tree_Q1;

GEN_adder_tree_Q2: if QUANTIZATION_BITS = 2 generate
	process(clk)
	begin
	if clk'event and clk = '1' then
		for k in 0 to VECTOR_SIZE-1 loop
			if normalized_to_minus1_1 = '0' then
				if vector1(2*k+1 downto 2*k) = B"00" then
					temp_mult_result(32*k+31 downto 32*k) <= (others => '0');
				elsif vector1(2*k+1 downto 2*k) = B"01" then
					temp_mult_result(32*k+31 downto 32*k) <= std_logic_vector( shift_right(signed(vector2(32*k+31 downto 32*k)), 1) );
				else
					temp_mult_result(32*k+31 downto 32*k) <= vector2(32*k+31 downto 32*k);
				end if;
			else
				if vector1(2*k+1 downto 2*k) = B"01" then
					temp_mult_result(32*k+31 downto 32*k) <= vector2(32*k+31 downto 32*k);
				elsif vector1(2*k+1 downto 2*k) = B"11" then
					temp_mult_result(32*k+31 downto 32*k) <= std_logic_vector( -signed(vector2(32*k+31 downto 32*k)) );
				else
					temp_mult_result(32*k+31 downto 32*k) <= (others => '0');
				end if;
			end if;
			fp_mult_result(32*k+31 downto 32*k) <= temp_mult_result(32*k+31 downto 32*k);
		end loop;
	end if;
	end process;
end generate GEN_adder_tree_Q2;

GEN_adder_tree_Q4: if QUANTIZATION_BITS = 4 generate
	process(clk)
	--variable temp_result : std_logic_vector(36*VECTOR_SIZE-1 downto 0);
	begin
	if clk'event and clk = '1' then
		for k in 0 to VECTOR_SIZE-1 loop
			if vector1(4*k+3 downto 4*k) = B"1000" then
				temp_mult_result(36*k+34 downto 36*k) <= vector2(32*k+31 downto 32*k) & B"000";
			else
				temp_mult_result(36*k+35 downto 36*k) <= std_logic_vector( signed(vector1(4*k+3 downto 4*k)) * signed(vector2(32*k+31 downto 32*k)) );
			end if;
			if normalized_to_minus1_1 = '0' then
				fp_mult_result(32*k+31 downto 32*k) <= temp_mult_result(36*k+34 downto 36*k+3);
			else
				fp_mult_result(32*k+31 downto 32*k) <= temp_mult_result(36*k+33 downto 36*k+2);
			end if;
		end loop;
	end if;
	end process;
end generate GEN_adder_tree_Q4;

GEN_adder_tree_Q8: if QUANTIZATION_BITS = 8 generate
	process(clk)
	--variable temp_result : std_logic_vector(40*VECTOR_SIZE-1 downto 0);
	begin
	if clk'event and clk = '1' then
		for k in 0 to VECTOR_SIZE-1 loop
			if vector1(8*k+7 downto 8*k) = B"10000000" then
				temp_mult_result(40*k+38 downto 40*k) <= vector2(32*k+31 downto 32*k) & B"0000000";
			else
				temp_mult_result(40*k+39 downto 40*k) <= std_logic_vector( signed(vector1(8*k+7 downto 8*k)) * signed(vector2(32*k+31 downto 32*k)) );
			end if;
			if normalized_to_minus1_1 = '0' then
				fp_mult_result(32*k+31 downto 32*k) <= temp_mult_result(40*k+38 downto 40*k+7);
			else
				fp_mult_result(32*k+31 downto 32*k) <= temp_mult_result(40*k+37 downto 40*k+6);
			end if;
		end loop;
	end if;
	end process;
end generate GEN_adder_tree_Q8;

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
	fp_mult_result_valid <= trigger;
	fp_mult_result_valid_1d <= fp_mult_result_valid;

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
				if accumulation_count_internal = 1 then
					internal_result_valid_last <= '1';
				end if;
			else
				internal_accumulation_count <= internal_accumulation_count + 1;
				accumulation <= accumulation + signed(adder_tree_result);
			end if;
		end if;

		if internal_result_valid = '1' or valid_pulse_counter > 0 then
			if valid_pulse_counter = accumulation_count_internal-1 then
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