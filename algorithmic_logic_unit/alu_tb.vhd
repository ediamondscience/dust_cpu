library ieee;
use ieee.std_logic_1164.all;
use work.algorithmic_logic_unit.all;
use work.alu_types.all;
use work.register_transfer.all;

entity alu_tb is 
end entity alu_tb;

architecture behave of alu_tb is
    constant clk_pd : time := 1 ns;
    signal r_clk : std_logic := '0';
    signal in_cmd : t_alu_cmd := ALU_NOP;
    signal in_arg1 : t_reg_reader;
    signal in_arg2 : t_reg_reader;
    signal out_err : t_reg_writer;
    signal out_res : t_reg_writer;
    signal out_carry : t_reg_writer;

begin
    r_clk <= not r_clk after clk_pd/2;

    alu: component work.algorithmic_logic_unit
     port map(
        i_clk => i_clk,
        i_cmd => in_cmd,
        i_arg1 => in_arg1,
        i_arg2 => in_arg2,
        o_error => out_err,
        o_carry => out_carry,
        o_result => out_res
    );

    process is
    begin
        for arg1 in 0 to 65535 loop
            for arg2 in 0 to 65535 loop
                in_arg1.rd_active <= '1';
                in_arg2.rd_active <= '1';
                in_arg1.data <= std_logic_vector(to_unsigned(arg1, in_arg1.data'length));
                in_arg2.data <= std_logic_vector(to_unsigned(arg2, in_arg2.data'length)); 

                wait for 1 ns;
                assert to_unsigned(arg1) + to_unsigned(arg2) = unsigned(out_res.data) + unsigned(out_carry.data) report "Values do not match: " & arg1'image & " + " & arg2'image & " /= " & unsigned'image(unsigned(out_res.data)) severity error;
            end loop;
        end loop;
    end process;

end architecture;