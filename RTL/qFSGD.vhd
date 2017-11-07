library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity qFSGD is
generic(
	LOG2_S_AXIS_DATA_WIDTH : integer := 6;
	LOG2_QUANTIZATION_BITS : integer := 2;
	LOG2_MAX_DIMENSION : integer := 12);
port(
	clk: in std_logic;
	resetn : in std_logic;

	done : out std_logic;

	s_axis_tdata : in std_logic_vector((2**LOG2_S_AXIS_DATA_WIDTH)-1 downto 0);
	s_axis_tkeep : in std_logic_vector((2**(LOG2_S_AXIS_DATA_WIDTH-3))-1 downto 0);
	s_axis_tlast : in std_logic;
	s_axis_tready : out std_logic;
	s_axis_tvalid : in std_logic;

	m_axis_tdata : out std_logic_vector(31 downto 0);
	m_axis_tkeep : out std_logic_vector(3 downto 0);
	m_axis_tlast : out std_logic;
	m_axis_tready : in std_logic;
	m_axis_tvalid : out std_logic);
end qFSGD;

architecture behavioral of qFSGD is

signal s_axis_tready_internal : std_logic;

constant QUANTIZATION_BITS : integer := 2**LOG2_QUANTIZATION_BITS;
constant MAX_DIMENSION : integer := 2**LOG2_MAX_DIMENSION;
constant LOG2_VALUES_IN_ONE_INPUT_WORD : integer := LOG2_S_AXIS_DATA_WIDTH - LOG2_QUANTIZATION_BITS;
constant VECTOR_SIZE : integer := 2**LOG2_VALUES_IN_ONE_INPUT_WORD;
constant LOG2_MAX_NUM_LINES : integer := LOG2_MAX_DIMENSION - LOG2_VALUES_IN_ONE_INPUT_WORD;
constant LOG2_FIFO_DEPTH : integer := LOG2_MAX_NUM_LINES;
constant FIFO_DEPTH : integer := 2**LOG2_FIFO_DEPTH-10;
constant INDEX_ONES : unsigned(LOG2_MAX_NUM_LINES-1 downto 0) := (others => '1');

-------------------------------------------------------------------------------- Parameters START
constant MAGIC1 : std_logic_vector(63 downto 0) := X"39e9_0433_0f1a_0df2";
signal set_MAGIC1 : std_logic;
signal binarize_b_value : std_logic;
signal decrease_step_size : std_logic;
signal mini_batch_size : std_logic_vector(15 downto 0);
signal lambda_in_bitshift : std_logic_vector(31 downto 0);

constant MAGIC2 : std_logic_vector(63 downto 0) := X"b209_505f_9f56_0afe";
signal set_MAGIC2 : std_logic;
signal internal_stepsize_times_cost_positive : std_logic_vector(31 downto 0);
signal internal_stepsize_times_cost_negative : std_logic_vector(31 downto 0);

constant MAGIC3 : std_logic_vector(63 downto 0) := X"891e_bbfd_b9d5_f766";
signal set_MAGIC3 : std_logic;
signal dimension : std_logic_vector(LOG2_MAX_DIMENSION-1 downto 0);
signal b_value_to_binarize_to : std_logic_vector(31 downto 0);

constant MAGIC4 : std_logic_vector(63 downto 0) := X"c049_cea2_e9f6_957d";
signal set_MAGIC4 : std_logic;
signal number_of_epochs : unsigned(31 downto 0);
signal number_of_samples : unsigned(31 downto 0);

constant MAGIC5 : std_logic_vector(63 downto 0) := X"fe91_34a9_b660_b182";
signal set_MAGIC5 : std_logic;
signal normalized_to_minus1_1 : std_logic;
signal internal_stepsize : std_logic_vector(31 downto 0);

constant THE_END : std_logic_vector(63 downto 0) := X"abcd_abcd_abcd_abcd";
constant SEND_CONFIG : std_logic_vector(63 downto 0) := X"abca_abca_abca_abca";
constant LOOPBACK_MODE : std_logic_vector(63 downto 0) := X"abab_abab_abab_abab";
constant UNLOOPBACK_MODE : std_logic_vector(63 downto 0) := X"baba_baba_baba_baba";
signal set_LOOPBACK_MODE : std_logic;
-------------------------------------------------------------------------------- Parameters END
signal decreased_stepsize_times_cost_positive : std_logic_vector(31 downto 0);
signal decreased_stepsize_times_cost_negative : std_logic_vector(31 downto 0);

signal temp_remainder : integer range 0 to 1;
signal temp_accumulation_count : unsigned(LOG2_MAX_DIMENSION-1 downto 0);
signal accumulation_count : unsigned(LOG2_MAX_NUM_LINES-1 downto 0);
signal input_vector : std_logic_vector(QUANTIZATION_BITS*VECTOR_SIZE-1 downto 0);
signal input_vector_1d : std_logic_vector(QUANTIZATION_BITS*VECTOR_SIZE-1 downto 0);

signal dot_product_result_valid_last : std_logic;
signal dot_product_result_valid : std_logic;
signal dot_product_result : std_logic_vector(31 downto 0);

signal subtract_mult_result_valid : std_logic;
signal subtract_mult_result : std_logic_vector(31 downto 0);
signal subtract_mult_result_fixed : std_logic_vector(31 downto 0);

signal scalar_vector_mult_trigger : std_logic;
signal scalar_vector_mult_trigger_1d : std_logic;
signal scalar_vector_mult_result_valid : std_logic;
signal scalar_vector_mult_result : std_logic_vector(32*VECTOR_SIZE-1 downto 0);

signal x_re : std_logic;
signal x_re_1d : std_logic;
signal x_raddr : std_logic_vector(LOG2_MAX_NUM_LINES-1 downto 0);
signal x_waddr : std_logic_vector(LOG2_MAX_NUM_LINES-1 downto 0);
signal x_din : std_logic_vector(32*VECTOR_SIZE-1 downto 0);
signal x_we : std_logic;
signal x_dout : std_logic_vector(32*VECTOR_SIZE-1 downto 0);
--signal x_dout_float : std_logic_vector(32*VECTOR_SIZE-1 downto 0);
--signal x_dout_float_valid : std_logic_vector(VECTOR_SIZE-1 downto 0);

signal x_loading_re : std_logic;
signal x_loading_re_1d : std_logic;
signal x_loading_raddr : std_logic_vector(LOG2_MAX_NUM_LINES-1 downto 0);
signal x_loading_waddr : std_logic_vector(LOG2_MAX_NUM_LINES-1 downto 0);
signal x_loading_din : std_logic_vector(32*VECTOR_SIZE-1 downto 0);
signal x_loading_we : std_logic;
signal x_loading_waddr_direct : std_logic_vector(LOG2_MAX_NUM_LINES-1 downto 0);
signal x_loading_din_direct : std_logic_vector(32*VECTOR_SIZE-1 downto 0);
signal x_loading_we_direct : std_logic;
signal x_loading_dout : std_logic_vector(32*VECTOR_SIZE-1 downto 0);

signal reset_xs : std_logic;
signal x_reset_index : unsigned(LOG2_MAX_NUM_LINES-1 downto 0);
signal x_for_dot_product_index : unsigned(LOG2_MAX_NUM_LINES-1 downto 0);
signal x_for_update_index : unsigned(LOG2_MAX_NUM_LINES-1 downto 0);
signal x_update_index : unsigned(LOG2_MAX_NUM_LINES-1 downto 0);

signal x_update_trigger : std_logic;
signal x_update_trigger_1d : std_logic;

signal afifo_wenable : std_logic;
signal afifo_wdata : std_logic_vector(QUANTIZATION_BITS*VECTOR_SIZE-1 downto 0);
signal afifo_wlast : std_logic;
signal afifo_tvalid : std_logic;
signal afifo_tready : std_logic;
signal afifo_tdata : std_logic_vector(QUANTIZATION_BITS*VECTOR_SIZE-1 downto 0);
signal afifo_tlast : std_logic;
signal afifo_almostfull : std_logic;
signal afifo_count : std_logic_vector(LOG2_FIFO_DEPTH-1 downto 0);
signal afifo_tdata_1d : std_logic_vector(QUANTIZATION_BITS*VECTOR_SIZE-1 downto 0);

signal bfifo_wenable : std_logic;
signal bfifo_wdata : std_logic_vector(31 downto 0);
signal bfifo_wlast : std_logic;
signal bfifo_tvalid : std_logic;
signal bfifo_tready : std_logic;
signal bfifo_tdata : std_logic_vector(31 downto 0);
signal bfifo_tlast : std_logic;
signal bfifo_almostfull : std_logic;
signal bfifo_count : std_logic_vector(LOG2_FIFO_DEPTH-1 downto 0);

signal gradient : std_logic_vector(32*VECTOR_SIZE-1 downto 0);
signal gradient_fixed : std_logic_vector(32*VECTOR_SIZE-1 downto 0);

signal new_x_valid : std_logic;
signal new_x : std_logic_vector(32*VECTOR_SIZE-1 downto 0);

signal received_line_count : unsigned(31 downto 0);
signal received_sample_count : unsigned(31 downto 0);
signal sample_count : unsigned(31 downto 0);
signal epoch_count : unsigned(31 downto 0);

signal write_back_config : std_logic;
signal write_back_allowed : std_logic;
signal write_back_the_model : std_logic;
signal write_back_index : unsigned(LOG2_MAX_NUM_LINES-1 downto 0);
signal write_wait :  integer range 0 to VECTOR_SIZE-1;
signal write_wait2 : integer range 0 to VECTOR_SIZE-1;

signal ofifo_wenable_counter : unsigned(LOG2_MAX_NUM_LINES-1 downto 0);
signal ofifo_wenable : std_logic;
signal ofifo_wdata : std_logic_vector(31 downto 0);
signal ofifo_wlast : std_logic;
signal ofifo_tkeep : std_logic_vector(3 downto 0);
signal ofifo_tvalid : std_logic;
signal ofifo_tdata : std_logic_vector(31 downto 0);
signal ofifo_tlast : std_logic;
signal ofifo_almostfull : std_logic;
signal ofifo_count : std_logic_vector(LOG2_FIFO_DEPTH-1 downto 0);

component dual_port_ram
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
end component;

component normal2axis_fifo
generic (
	FIFO_WIDTH : integer;
	LOG2_FIFO_DEPTH : integer);
 port(
	clk : in std_logic;
	resetn : in std_logic;

	write_enable : in std_logic;
	write_data : in std_logic_vector(FIFO_WIDTH-1 downto 0);
	write_last : in std_logic;

	m_axis_tvalid : out std_logic;
	m_axis_tready : in std_logic;
	m_axis_tdata : out std_logic_vector(FIFO_WIDTH-1 downto 0);
	m_axis_tkeep : out std_logic_vector((FIFO_WIDTH/8)-1 downto 0);
	m_axis_tlast : out std_logic;

	almostfull : out std_logic;
	count : out std_logic_vector(LOG2_FIFO_DEPTH-1 downto 0) );
end component;

component qfixed_dot_product
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
end component;

component fp_subtract_mult
port (
	clk : in std_logic;

	trigger : in std_logic;
	dot_product : in std_logic_vector(31 downto 0);
	b_to_subtract : in std_logic_vector(31 downto 0);
	stepsize : in std_logic_vector(31 downto 0);
	stepsize_times_cost_positive : in std_logic_vector(31 downto 0);
	stepsize_times_cost_negative : in std_logic_vector(31 downto 0);

	result_valid : out std_logic;
	result : out std_logic_vector(31 downto 0));
end component;

component qfixed_scalar_vector_mult
generic (
	LOG2_VECTOR_SIZE : integer := 6;
	QUANTIZATION_BITS : integer := 2);
port (
	clk : in std_logic;

	normalized_to_minus1_1 : in std_logic;

	trigger : in std_logic;
	scalar : in std_logic_vector(31 downto 0);
	vector : in std_logic_vector(QUANTIZATION_BITS*(2**LOG2_VECTOR_SIZE)-1 downto 0);

	result_valid : out std_logic;
	result : out std_logic_vector(32*(2**LOG2_VECTOR_SIZE)-1 downto 0));
end component;

component fixed_vector_subtract
generic (VECTOR_SIZE : integer := 16);
port (
	clk : in std_logic;

	trigger : in std_logic;
	vector1 : in std_logic_vector(32*VECTOR_SIZE-1 downto 0);
	vector2 : in std_logic_vector(32*VECTOR_SIZE-1 downto 0);
	lambda_in_bitshift : std_logic_vector(31 downto 0);

	result_valid : out std_logic;
	result : out std_logic_vector(32*VECTOR_SIZE-1 downto 0));
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

x: dual_port_ram
generic map (
	DATA_WIDTH => 32*VECTOR_SIZE,
	ADDR_WIDTH => LOG2_MAX_NUM_LINES)
port map (
	clk => clk,
	raddr => x_raddr,
	waddr => x_waddr,
	data => x_din,
	we => x_we,
	q => x_dout);

x_loading_waddr_direct <= x_loading_waddr when new_x_valid = '0' else std_logic_vector(x_update_index);
x_loading_din_direct <= x_loading_din when new_x_valid = '0' else new_x;
x_loading_we_direct <= x_loading_we when new_x_valid = '0' else '1';
x_loading: dual_port_ram
generic map (
	DATA_WIDTH => 32*VECTOR_SIZE,
	ADDR_WIDTH => LOG2_MAX_NUM_LINES)
port map (
	clk => clk,
	raddr => x_loading_raddr,
	waddr => x_loading_waddr_direct,
	data => x_loading_din_direct,
	we => x_loading_we_direct,
	q => x_loading_dout);

afifo_tready <= subtract_mult_result_valid;
afifo: normal2axis_fifo
generic map (
	FIFO_WIDTH => QUANTIZATION_BITS*VECTOR_SIZE,
	LOG2_FIFO_DEPTH => LOG2_FIFO_DEPTH)
port map (
	clk => clk,
	resetn => resetn,

	write_enable => afifo_wenable,
	write_data => afifo_wdata,
	write_last => afifo_wlast,

	m_axis_tvalid => afifo_tvalid,
	m_axis_tready => afifo_tready,
	m_axis_tdata => afifo_tdata,
	m_axis_tlast => afifo_tlast,

	almostfull => afifo_almostfull,
	count => afifo_count);

bfifo_tready <= dot_product_result_valid_last;
bfifo: normal2axis_fifo
generic map (
	FIFO_WIDTH => 32,
	LOG2_FIFO_DEPTH => LOG2_FIFO_DEPTH)
port map (
	clk => clk,
	resetn => resetn,

	write_enable => bfifo_wenable,
	write_data => bfifo_wdata,
	write_last => bfifo_wlast,

	m_axis_tvalid => bfifo_tvalid,
	m_axis_tready => bfifo_tready,
	m_axis_tdata => bfifo_tdata,
	m_axis_tlast => bfifo_tlast,

	almostfull => bfifo_almostfull,
	count => bfifo_count);

dot_product: qfixed_dot_product
generic map (
	LOG2_MAX_DIMENSION => LOG2_MAX_DIMENSION,
	LOG2_VECTOR_SIZE => LOG2_VALUES_IN_ONE_INPUT_WORD,
	QUANTIZATION_BITS => QUANTIZATION_BITS)
port map (
	clk => clk,
	resetn => resetn,

	accumulation_count => std_logic_vector( temp_accumulation_count ),
	normalized_to_minus1_1 => normalized_to_minus1_1,

	trigger => x_re_1d,
	vector1 => input_vector_1d,
	vector2 => x_dout,

	result_valid_last => dot_product_result_valid_last,
	result_valid => dot_product_result_valid,
	result => dot_product_result);

subtract_mult: fp_subtract_mult
port map (
	clk => clk,

	trigger => dot_product_result_valid,
	dot_product => dot_product_result,
	b_to_subtract => bfifo_tdata,
	stepsize => internal_stepsize,
	stepsize_times_cost_positive => internal_stepsize_times_cost_positive,
	stepsize_times_cost_negative => internal_stepsize_times_cost_negative,

	result_valid => subtract_mult_result_valid,
	result => subtract_mult_result);

process(clk)
begin
if clk'event and clk = '1' then
	scalar_vector_mult_trigger_1d <= scalar_vector_mult_trigger;
	subtract_mult_result_fixed <= convert_float_to_int9_23(subtract_mult_result);
	afifo_tdata_1d <= afifo_tdata;
end if;
end process;

scalar_vector_mult_trigger <= afifo_tvalid and afifo_tready;
scalar_vector_mult: qfixed_scalar_vector_mult
generic map(
	LOG2_VECTOR_SIZE => LOG2_VALUES_IN_ONE_INPUT_WORD,
	QUANTIZATION_BITS => QUANTIZATION_BITS)
port map (
	clk => clk,

	normalized_to_minus1_1 => normalized_to_minus1_1,

	trigger => scalar_vector_mult_trigger_1d,
	scalar => subtract_mult_result_fixed,
	vector => afifo_tdata_1d,

	result_valid => scalar_vector_mult_result_valid,
	result => scalar_vector_mult_result);

vector_subtract: fixed_vector_subtract
generic map (
	VECTOR_SIZE => VECTOR_SIZE)
port map (
	clk => clk,

	trigger => x_update_trigger_1d,
	vector1 => x_loading_dout,
	vector2 => gradient_fixed,
	lambda_in_bitshift => lambda_in_bitshift,

	result_valid => new_x_valid,
	result => new_x);

m_axis_tkeep <= ofifo_tkeep;
m_axis_tvalid <= ofifo_tvalid;
m_axis_tdata <= ofifo_tdata;
m_axis_tlast <= ofifo_tlast;
ofifo: normal2axis_fifo
generic map (
	FIFO_WIDTH => 32,
	LOG2_FIFO_DEPTH => LOG2_FIFO_DEPTH)
port map (
	clk => clk,
	resetn => resetn,

	write_enable => ofifo_wenable,
	write_data => ofifo_wdata,
	write_last => ofifo_wlast,

	m_axis_tkeep => ofifo_tkeep,
	m_axis_tvalid => ofifo_tvalid,
	m_axis_tready => m_axis_tready,
	m_axis_tdata => ofifo_tdata,
	m_axis_tlast => ofifo_tlast,

	almostfull => ofifo_almostfull,
	count => ofifo_count);

-------------------------------------------------------------------------------- PROCESS START
temp_remainder <= 	0 when LOG2_VALUES_IN_ONE_INPUT_WORD = 1 and dimension(0) = '0' else
					1 when LOG2_VALUES_IN_ONE_INPUT_WORD = 1 and dimension(0) = '1' else
					1 when unsigned(dimension(LOG2_VALUES_IN_ONE_INPUT_WORD-1 downto 0)) > 0 else
					0;
temp_accumulation_count <= shift_right(unsigned(dimension), LOG2_VALUES_IN_ONE_INPUT_WORD) + to_unsigned(temp_remainder, 1);

accumulation_count <= temp_accumulation_count(LOG2_MAX_NUM_LINES-1 downto 0);
s_axis_tready <= s_axis_tready_internal;
process(clk)
begin
if clk'event and clk = '1' then
	input_vector_1d <= input_vector;
	x_re_1d <= x_re;
	x_loading_re_1d <= x_loading_re;
	x_update_trigger_1d <= x_update_trigger;
	--for k in 0 to VECTOR_SIZE-1 loop
	--	gradient_fixed(32*k+31 downto 32*k) <= convert_float_to_int9_23(gradient(32*k+31 downto 32*k));
	--end loop;
	gradient_fixed <= gradient;

	if resetn = '0' then
		s_axis_tready_internal <= '0';

		set_MAGIC1 <= '0';
		set_MAGIC2 <= '0';
		set_MAGIC3 <= '0';
		set_MAGIC4 <= '0';
		set_MAGIC5 <= '0';
		set_LOOPBACK_MODE <= '0';

		reset_xs <= '0';
		x_reset_index <= (others => '0');
		x_for_dot_product_index <= (others => '0');
		x_for_update_index <= (others => '0');
		x_update_index <= (others => '0');

		afifo_wenable <= '0';
		bfifo_wenable <= '0';

		gradient <= (others => '0');

		x_re <= '0';
		x_loading_re <= '0';

		x_update_trigger <= '0';

		write_back_config <= '0';
		write_back_allowed <= '0';
		write_back_the_model <= '0';
		write_back_index <= (others => '0');

		ofifo_wenable_counter <= (others => '0');

		write_wait <= 0;
		write_wait2 <= 0;

		done <= '0';
	else
		x_we <= '0';
		x_loading_we <= '0';
		------------------------------------------------------------------------ Reset x and x_loading
		if reset_xs = '1' then
			received_line_count <= (others => '0');
			received_sample_count <= (others => '0');
			sample_count <= (others => '0');
			epoch_count <= (others => '0');
			x_we <= '1';
			x_loading_we <= '1';
			x_din <= (others => '0');
			x_loading_din <= (others => '0');
			x_waddr <= std_logic_vector( x_reset_index );
			x_loading_waddr <= std_logic_vector( x_reset_index );
			if x_reset_index = INDEX_ONES then
				x_reset_index <= (others => '0');
				reset_xs <= '0';
			else
				x_reset_index <= x_reset_index + 1;
			end if;
		end if;

		s_axis_tready_internal <= '0';
		if s_axis_tvalid = '1' and reset_xs = '0' and write_back_the_model = '0' then -- and write_back_config = '0' then
			s_axis_tready_internal <= '1';
		end if;

		ofifo_wenable <= '0';
		ofifo_wlast <= '0';

		x_re <= '0';
		afifo_wenable <= '0';
		bfifo_wenable <= '0';
		if s_axis_tvalid = '1' and s_axis_tready_internal = '1' then
			-------------------------------------------------------------------- Is it paramater magic?
			if s_axis_tdata = MAGIC1 then
				set_MAGIC1 <= '1';
				reset_xs <= '1';
			elsif s_axis_tdata = MAGIC2 then
				set_MAGIC2 <= '1';
			elsif s_axis_tdata = MAGIC3 then
				set_MAGIC3 <= '1';
			elsif s_axis_tdata = MAGIC4 then
				set_MAGIC4 <= '1';
			elsif s_axis_tdata = MAGIC5 then
				set_MAGIC5 <= '1';
			elsif s_axis_tdata = LOOPBACK_MODE then
				set_LOOPBACK_MODE <= '1';
			elsif s_axis_tdata = UNLOOPBACK_MODE then
				set_LOOPBACK_MODE <= '0';
				done <= '1';
			elsif s_axis_tdata = THE_END then
				write_back_the_model <= '1';
				write_back_index <= (others => '0');
				ofifo_wenable_counter <= (others => '0');
			elsif s_axis_tdata = SEND_CONFIG then
				write_back_config <= '1';
				write_back_index <= (others => '0');
			-------------------------------------------------------------------- Is it configuration payload?
			elsif set_LOOPBACK_MODE = '1' then
				ofifo_wenable <= '1';
				ofifo_wdata <= s_axis_tdata(31 downto 0);
				ofifo_wlast <= s_axis_tlast;
			elsif set_MAGIC1 = '1' then
				set_MAGIC1 <= '0';
				binarize_b_value <= s_axis_tdata(49);
				decrease_step_size <= s_axis_tdata(48);
				mini_batch_size <= s_axis_tdata(47 downto 32);
				lambda_in_bitshift <= s_axis_tdata(31 downto 0);
			elsif set_MAGIC2 = '1' then
				set_MAGIC2 <= '0';
				internal_stepsize_times_cost_positive <= s_axis_tdata(63 downto 32);
				internal_stepsize_times_cost_negative <= s_axis_tdata(31 downto 0);
			elsif set_MAGIC3 = '1' then
				set_MAGIC3 <= '0';
				dimension <= s_axis_tdata(32+LOG2_MAX_DIMENSION-1 downto 32);
				b_value_to_binarize_to <= s_axis_tdata(31 downto 0);
			elsif set_MAGIC4 = '1' then
				set_MAGIC4 <= '0';
				number_of_epochs <= unsigned(s_axis_tdata(63 downto 32));
				number_of_samples <= unsigned(s_axis_tdata(31 downto 0));
			elsif set_MAGIC5 = '1' then
				set_MAGIC5 <= '0';
				normalized_to_minus1_1 <= s_axis_tdata(32);
				internal_stepsize <= s_axis_tdata(31 downto 0);
			else
				received_line_count <= received_line_count + 1;
				if x_for_dot_product_index = accumulation_count then ----------- Label
					x_for_dot_product_index <= (others => '0');
					bfifo_wenable <= '1';
					if binarize_b_value = '0' then
						bfifo_wdata <= s_axis_tdata(31 downto 0);
					else
						if s_axis_tdata(31 downto 0) = b_value_to_binarize_to then
							bfifo_wdata <= X"3f800000";
						else
							bfifo_wdata <= X"bf800000";
						end if;
					end if;

					received_sample_count <= received_sample_count + 1;
				else ----------------------------------------------------------- Part of Features
					input_vector <= s_axis_tdata;
					x_re <= '1';
					x_raddr <= std_logic_vector( x_for_dot_product_index );
					x_for_dot_product_index <= x_for_dot_product_index + 1;
					afifo_wenable <= '1';
					afifo_wdata <= s_axis_tdata;
				end if;
			end if;
		end if;

		x_update_trigger <= '0';
		if scalar_vector_mult_result_valid = '1' then
			x_update_trigger <= '1';
			x_loading_raddr <= std_logic_vector( x_for_update_index );
			if x_for_update_index = accumulation_count-1 then
				x_for_update_index <= (others => '0');
			else
				x_for_update_index <= x_for_update_index + 1;
			end if;
			gradient <= scalar_vector_mult_result;
		end if;

		if new_x_valid = '1' then
			if (std_logic_vector( sample_count(15 downto 0) ) and mini_batch_size) = mini_batch_size then
				x_we <= '1';
				x_waddr <= std_logic_vector(x_update_index);
				x_din <= new_x;
			end if;

			--x_loading_we <= '1';
			--x_loading_waddr <= std_logic_vector(x_update_index);
			--x_loading_din <= new_x;

			if x_update_index = accumulation_count-1 then
				x_update_index <= (others => '0');
				if sample_count = number_of_samples-1 then
					sample_count <= (others => '0');
					if epoch_count < number_of_epochs then
						write_back_allowed <='1';
						epoch_count <= epoch_count + 1;
					end if;
				else
					sample_count <= sample_count + 1;
				end if;
			else
				x_update_index <= x_update_index + 1;
			end if;
		end if;

		x_loading_re <= '0';
		if write_back_the_model = '1' and write_back_allowed = '1' and ofifo_almostfull = '0' then
			x_loading_re <= '1';
			x_loading_raddr <= std_logic_vector(write_back_index);

			if write_wait = VECTOR_SIZE-1 then
				if write_back_index = accumulation_count-1 then
					write_back_the_model <= '0';
					write_back_allowed <= '0';
					write_back_index <= (others => '0');
				else
					write_back_index <= write_back_index + 1;
				end if;
				write_wait <= 0;
			else
				write_wait <= write_wait + 1;
			end if;
		end if;

		if x_loading_re_1d = '1' then
			ofifo_wenable <= '1';
			ofifo_wdata <= x_loading_dout(32*write_wait2+31 downto 32*write_wait2);

			if write_wait2 = VECTOR_SIZE-1 then				
				write_wait2 <= 0;
				if ofifo_wenable_counter = accumulation_count-1 then
					ofifo_wlast <= '1';
					ofifo_wenable_counter <= (others => '0');
				else
					ofifo_wenable_counter <= ofifo_wenable_counter + 1;
				end if;
			else
				write_wait2 <= write_wait2 + 1;
			end if;
		end if;
		if write_back_config = '1' then
			write_back_index <= write_back_index + 1;
			ofifo_wenable <= '1';
			if write_back_index = 0 then
				ofifo_wdata <= lambda_in_bitshift;
			elsif write_back_index = 1 then
				ofifo_wdata <= X"000" & B"00" & binarize_b_value & decrease_step_size & mini_batch_size;
			elsif write_back_index = 2 then
				ofifo_wdata <= internal_stepsize_times_cost_negative;
			elsif write_back_index = 3 then
				ofifo_wdata <= internal_stepsize_times_cost_positive;
			elsif write_back_index = 4 then
				ofifo_wdata <= b_value_to_binarize_to;
			elsif write_back_index = 5 then
				ofifo_wdata(31 downto LOG2_MAX_DIMENSION) <= (others => '0');
				ofifo_wdata(LOG2_MAX_DIMENSION-1 downto 0) <= dimension;
			elsif write_back_index = 6 then
				ofifo_wdata <= std_logic_vector( number_of_samples );
			elsif write_back_index = 7 then
				ofifo_wdata <= std_logic_vector( number_of_epochs );
			elsif write_back_index = 8 then
				ofifo_wlast <= '1';
				ofifo_wdata <= internal_stepsize;
				write_back_config <= '0';
				write_back_index <= (others => '0');
			end if;
		end if;

		if ofifo_tlast = '1' and epoch_count = number_of_epochs then
			done <= '1';
		end if;
	end if;
end if;
end process;
-------------------------------------------------------------------------------- PROCESS END

end architecture;